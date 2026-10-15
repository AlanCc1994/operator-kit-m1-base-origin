#!/usr/bin/env bash
# Safe, idempotent, offline initialization of an instance OUTSIDE Kit.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/paths.sh"
usage() {
  cat <<'HELP'
用法：bin/m1-init-instance.sh --home /absolute/path [--legacy-in-kit]
      --home PATH       独立实例目录；允许使用环境变量 OPERATOR_HOME
      --legacy-in-kit   兼容旧模式，允许实例目录与 KIT_ROOT 相同（默认禁止）
      --help            显示帮助
初始化只创建模板和目录，不尝试登录浏览器或连接真机。
HELP
}
HOME_ARG=''; LEGACY=0
while (($#)); do
  case "$1" in
    --home) HOME_ARG="${2:?--home requires path}"; shift 2;;
    --legacy-in-kit) LEGACY=1; shift;;
    --help|-h) usage; exit 0;;
    *) echo "M1_ERR: 未知参数 $1" >&2; usage >&2; exit 2;;
  esac
done
m1_resolve "$HOME_ARG" "$LEGACY"
# Fail early on missing source templates and unexpected targets.
for f in operator.env.example project/project.env.example; do
  [[ -f "$M1_KIT_ROOT/$f" ]] || { echo "M1_ERR: 缺少模板：$f" >&2; exit 4; }
done
umask 077
if [[ -e "$M1_HOME" && ! -d "$M1_HOME" ]]; then echo 'M1_ERR: home is not a directory' >&2; exit 4; fi
mkdir -p -- "$M1_HOME"
# Existing symlinks may not point outside instance, and secrets must not be symlinks.
for sub in _ssh project project/hooks project/identity state incoming chrome-cdp-profile; do
  m1_verify_child "$sub" "$M1_HOME/$sub"
  mkdir -p -- "$M1_HOME/$sub"
done
for f in operator.env project/project.env _ssh/askpass.sh; do
  if [[ -L "$M1_HOME/$f" ]]; then
    echo "M1_ERR: 拒绝实例配置/凭据符号链接: $f" >&2; exit 3
  fi
done
if [[ -e "$M1_HOME/operator.env" ]]; then
  echo 'KEEP operator.env'
else
  cp -- "$M1_KIT_ROOT/operator.env.example" "$M1_HOME/operator.env"
  chmod 600 "$M1_HOME/operator.env"
  echo 'CREATE operator.env'
fi
if [[ -e "$M1_HOME/project/project.env" ]]; then
  echo 'KEEP project/project.env'
else
  cp -- "$M1_KIT_ROOT/project/project.env.example" "$M1_HOME/project/project.env"
  chmod 600 "$M1_HOME/project/project.env"
  echo 'CREATE project/project.env'
fi
# Copy example hooks only, never activate executable hooks or create a fake password.
for f in "$M1_KIT_ROOT"/project/hooks/*.example; do
  [[ -f "$f" ]] || continue
  dest="$M1_HOME/project/hooks/$(basename "$f")"
  [[ -e "$dest" ]] || cp -- "$f" "$dest"
done
if [[ -f "$M1_KIT_ROOT/_ssh/askpass.sh.example" ]]; then
  [[ -e "$M1_HOME/_ssh/askpass.sh.example" ]] || cp -- "$M1_KIT_ROOT/_ssh/askpass.sh.example" "$M1_HOME/_ssh/askpass.sh.example"
fi
if [[ ! -e "$M1_HOME/.m1-schema" ]]; then
  printf 'm1.external-instance.schema=1\n' > "$M1_HOME/.m1-schema"
  chmod 600 "$M1_HOME/.m1-schema"
fi
printf 'M1_INIT=PASS\nKIT_ROOT=%s\nOPERATOR_HOME=%s\nENV_FILE=%s\n' "$M1_KIT_ROOT" "$M1_HOME" "$M1_ENV"
echo 'NEXT: 编辑 operator.env / project/project.env，然后运行 bin/m1-verify-instance.sh --stage config'
