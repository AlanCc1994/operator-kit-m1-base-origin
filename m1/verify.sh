#!/usr/bin/env bash
# Offline M1 verification. Distinguishes 'instance is initialized' from 'runtime is ready'.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/paths.sh"
usage() {
  cat <<'HELP'
用法：bin/m1-verify-instance.sh --home PATH --stage filesystem|config|full [--env FILE]
  filesystem 仅验证实例目录、模板存在、路径安全；无外部连接
  config     再验证配置值及跨文件一致性；无外部连接
  full       保留给后续 M2-M9，当前明确返回 4（未实现）
HELP
}
HOME_ARG=''; LEGACY=0; STAGE='config'; ENV_ARG=''
while (($#)); do
  case "$1" in
    --home) HOME_ARG="${2:?--home requires path}"; shift 2;;
    --env) ENV_ARG="${2:?--env requires path}"; shift 2;;
    --stage) STAGE="${2:?--stage requires name}"; shift 2;;
    --legacy-in-kit) LEGACY=1; shift;;
    --help|-h) usage; exit 0;;
    *) echo "M1_ERR: unknown argument: $1" >&2; exit 2;;
  esac
done
case "$STAGE" in filesystem|config|full) :;; *) echo "M1_ERR: unsupported stage $STAGE" >&2; exit 2;; esac
m1_resolve "$HOME_ARG" "$LEGACY" "$ENV_ARG" || exit $?
PASS=0; FAIL=0
ok() { echo "PASS $*"; PASS=$((PASS+1)); }
bad() { echo "FAIL $*"; FAIL=$((FAIL+1)); }
check_file() { if [[ -f "$1" && ! -L "$1" ]]; then ok "存在 $2"; else bad "缺失或链接 $2"; fi; }
check_dir() {
  local candidate="$M1_HOME/$1"
  if [[ -d "$candidate" ]] && m1_verify_child "$1" "$candidate"; then ok "目录 $1"; else bad "目录缺失或越界 $1"; fi
}
[[ -d "$M1_HOME" ]] && ok '实例根存在' || bad '实例根不存在'
check_file "$M1_ENV" 'operator.env'
if [[ -f "$M1_ENV" ]]; then
  perm="$(stat -c %a "$M1_ENV" 2>/dev/null || echo 777)"
  if [[ "$perm" =~ ^[0-7]{3,4}$ ]] && (( (8#$perm & 8#77) == 0 )); then
    ok "operator.env 文件权限"
  else
    bad "operator.env 必须禁止组用户和其他用户读取（建议 chmod 600）"
  fi
fi
check_file "$M1_HOME/project/project.env" 'project/project.env'
check_file "$M1_HOME/.m1-schema" '.m1-schema'
for sub in _ssh project project/hooks project/identity state incoming chrome-cdp-profile; do check_dir "$sub"; done
if ((FAIL)); then echo "M1_VERIFY=FAIL stage=$STAGE pass=$PASS fail=$FAIL"; exit 3; fi
if [[ "$STAGE" = filesystem ]]; then echo "M1_VERIFY=PASS stage=$STAGE pass=$PASS fail=0"; exit 0; fi
# Config files are trusted shell code. Load them in this process only; no user program executed.
orig_root="$M1_KIT_ROOT"; orig_home="$M1_HOME"; orig_env="$M1_ENV"
export KIT_ROOT="$M1_KIT_ROOT" OPERATOR_HOME="$M1_HOME" OPERATOR_ENV="$M1_ENV"
set -a
# shellcheck disable=SC1090
. "$M1_ENV" || { echo 'M1_VERIFY=FAIL 无法加载 operator.env'; exit 3; }
set +a
if [[ "${KIT_ROOT:-}" != "$orig_root" || "${OPERATOR_HOME:-}" != "$orig_home" ]]; then
  bad '配置不得改写 KIT_ROOT / OPERATOR_HOME'
fi
bad_if_placeholder() {
  local k="$1" val="${!1:-}"
  if [[ -z "$val" || "$val" == *REPLACE-WITH* ]]; then bad "$k 缺失或未填写"; else ok "$k"; fi
}
for k in CONV_URL CDP_PORT NODE_BIN_DIR STATE_DIR INCOMING_DIR CHROME_PROFILE_DIR LOCK_OWNER; do bad_if_placeholder "$k"; done
if [[ "${CONV_URL:-}" =~ ^https://chatgpt\.com/c/[a-zA-Z0-9-]{8,}([/?#].*)?$ ]] && [[ "$CONV_URL" != *REPLACE-WITH* ]]; then
  ok 'CONV_URL 格式'; else bad 'CONV_URL 必须是完整的 chatgpt.com/c/ 会话 URL'; fi
if [[ "${CDP_PORT:-}" =~ ^[0-9]+$ ]] && ((10#$CDP_PORT >= 1 && 10#$CDP_PORT <= 65535)); then
  ok 'CDP_PORT 范围'; else bad 'CDP_PORT 应为 1..65535'; fi
for k in STATE_DIR INCOMING_DIR CHROME_PROFILE_DIR ASKPASS; do
  if [[ -n "${!k:-}" ]] && m1_verify_child "$k" "${!k}"; then ok "$k 路径隔离"; else bad "$k 路径隔离失败"; fi
done
if [[ -n "${PROJECT_ENV:-}" ]] && ! m1_verify_child PROJECT_ENV "$PROJECT_ENV"; then bad 'PROJECT_ENV 路径越界'; fi
if [[ -n "${PROJECT_ENV:-}" ]] && [[ "$(m1_abs "$PROJECT_ENV")" != "$(m1_abs "$M1_HOME/project/project.env")" ]]; then
  bad 'M1 R0 要求 PROJECT_ENV 使用实例默认项目配置，避免多入口不一致'
fi
if [[ "${STATE_DIR:-}" == "${INCOMING_DIR:-}" ]]; then bad 'STATE_DIR 与 INCOMING_DIR 不得相同'; fi
if [[ "${BROWSER_KIND:-chrome}" != chrome && "${BROWSER_KIND:-chrome}" != firefox && "${BROWSER_KIND:-chrome}" != adspower ]]; then
  bad 'BROWSER_KIND 无效'; else ok 'BROWSER_KIND'; fi
# Project manifest is defined in the second layer and must stay inside home.
if [[ -f "$M1_HOME/project/project.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$M1_HOME/project/project.env" || bad '项目配置加载失败'
  set +a
  if [[ "${KIT_ROOT:-}" != "$orig_root" || "${OPERATOR_HOME:-}" != "$orig_home" ]]; then
    bad '项目配置不得改写 KIT_ROOT / OPERATOR_HOME'
  fi
  if [[ -n "${IDENTITY_MANIFEST:-}" ]] && m1_verify_child IDENTITY_MANIFEST "$IDENTITY_MANIFEST"; then
    ok 'IDENTITY_MANIFEST 路径隔离'; else bad 'IDENTITY_MANIFEST 路径隔离失败'; fi
fi
if ((FAIL)); then echo "M1_VERIFY=FAIL stage=$STAGE pass=$PASS fail=$FAIL"; exit 3; fi
if [[ "$STAGE" = full ]]; then
  echo 'M1_VERIFY=UNSUPPORTED stage=full（浏览器、板卡、项目执行检查属于后续模块）'
  exit 4
fi
echo "M1_VERIFY=PASS stage=$STAGE pass=$PASS fail=0"
