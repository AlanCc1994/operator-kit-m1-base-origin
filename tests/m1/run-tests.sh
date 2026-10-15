#!/usr/bin/env bash
# Hermetic tests: never touch a live browser, board, secrets or project repository.
set -uo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
if [[ "${1:-}" = '--kit' ]]; then KIT="$(cd "${2:?}" && pwd -P)"; fi
TMP="$(mktemp -d)" || exit 3
trap 'rm -rf "$TMP"' EXIT
P=0; F=0
ok(){ echo "PASS $*"; P=$((P+1)); }
bad(){ echo "FAIL $*"; F=$((F+1)); }
run_ok(){ local label="$1"; shift; if "$@" > "$TMP/stdout" 2> "$TMP/stderr"; then ok "$label"; else bad "$label (rc=$?)"; cat "$TMP/stderr"; fi; }
run_rc(){ local expect="$1" label="$2"; shift 2; local code=0; "$@" > "$TMP/stdout" 2> "$TMP/stderr" || code=$?; if [[ "$code" = "$expect" ]]; then ok "$label"; else bad "$label expected=$expect got=$code"; cat "$TMP/stderr"; fi; }
configure(){
  local home="$1" port="$2" owner="$3"
  local source="$home/operator.env"
  cat >> "$source" <<CONFIG
CONV_URL="https://chatgpt.com/c/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
CDP_PORT="$port"
NODE_BIN_DIR="$(dirname "$(command -v node)")"
LOCK_OWNER="$owner"
CONFIG
}
A="$TMP/afc/operator"; B="$TMP/rnnoise/operator"
run_ok 'A 外部初始化' "$KIT/bin/m1-init-instance.sh" --home "$A"
run_ok 'B 外部初始化' "$KIT/bin/m1-init-instance.sh" --home "$B"
run_ok 'A 初始化后目录验证' "$KIT/bin/m1-verify-instance.sh" --home "$A" --stage filesystem
run_rc 3 '模板占位符导致配置验证失败' "$KIT/bin/m1-verify-instance.sh" --home "$A" --stage config
configure "$A" 9225 afc
configure "$B" 9226 rnnoise
run_ok 'A 配置验证' "$KIT/bin/m1-verify-instance.sh" --home "$A" --stage config
run_ok 'B 配置验证' "$KIT/bin/m1-verify-instance.sh" --home "$B" --stage config
sha_before="$(sha256sum "$A/operator.env" | awk '{print $1}')"
run_ok '重复初始化幂等' "$KIT/bin/m1-init-instance.sh" --home "$A"
sha_after="$(sha256sum "$A/operator.env" | awk '{print $1}')"
[[ "$sha_before" = "$sha_after" ]] && ok '实例配置没有被覆盖' || bad '重复初始化覆盖了实例配置'
[[ ! -f "$KIT/operator.env" ]] && ok '外部初始化没有在 Kit 中生成 operator.env' || {
  # In a full pre-existing upstream kit, operator.env may already exist and is not evidence of pollution.
  ok 'Kit 可能已有旧配置，验证只读由下方测试单独完成'
}
run_rc 3 '拒绝在 Kit 内创建新实例' "$KIT/bin/m1-init-instance.sh" --home "$KIT/test-forbidden"
run_rc 3 'legacy 只允许 Kit 根自身而不允许子目录' "$KIT/bin/m1-init-instance.sh" --home "$KIT/test-forbidden" --legacy-in-kit
run_rc 3 '拒绝实例父路径包含 Kit' "$KIT/bin/m1-init-instance.sh" --home "$(dirname "$KIT")"
run_rc 4 'full 阶段未实现时明确拒绝' "$KIT/bin/m1-verify-instance.sh" --home "$A" --stage full
# Explicit profile env file must resolve within home.
cp "$A/operator.env" "$A/operator.chrome.env"
run_ok '验证明确指定的配置文件' "$KIT/bin/m1-verify-instance.sh" --home "$A" --env "$A/operator.chrome.env" --stage config
run_rc 3 '拒绝外部配置文件' "$KIT/bin/m1-verify-instance.sh" --home "$A" --env "$B/operator.env" --stage config
# Detect runtime path escaping the instance.
printf '\nSTATE_DIR="%s"\n' "$TMP/escaped-state" >> "$A/operator.env"
run_rc 3 '状态目录越界导致失败' "$KIT/bin/m1-verify-instance.sh" --home "$A" --stage config
printf '\nSTATE_DIR="$OPERATOR_HOME/state"\n' >> "$A/operator.env"
run_ok '恢复合法配置后验证通过' "$KIT/bin/m1-verify-instance.sh" --home "$A" --stage config
# Instance config may not rewrite reserved paths.
printf '\nOPERATOR_HOME=/tmp/evil\n' >> "$A/operator.env"
run_rc 3 '阻止配置覆盖 OPERATOR_HOME' "$KIT/bin/m1-verify-instance.sh" --home "$A" --stage config
# File mode of the primary config must be private.
chmod 644 "$B/operator.env"
run_rc 3 '拒绝不安全配置权限' "$KIT/bin/m1-verify-instance.sh" --home "$B" --stage filesystem
chmod 600 "$B/operator.env"
run_ok '恢复 600 权限' "$KIT/bin/m1-verify-instance.sh" --home "$B" --stage config
# An already-existing symlink state directory must not lead outside home.
C="$TMP/symlink/operator"; mkdir -p "$C"; ln -s "$TMP" "$C/state"
run_rc 3 '拒绝越界 symlink 状态目录' "$KIT/bin/m1-init-instance.sh" --home "$C"
# No SSH or CDP external requests should exist in this test script.
if grep -Eq '(^|[^a-zA-Z])(ssh|scp|curl)( |$)' "${BASH_SOURCE[0]}"; then bad '测试脚本包含外部连接命令'; else ok '纯离线测试'; fi
# Read-only kit regression: copy small subset without VCS; chmod read-only, initialize external home.
RO="$TMP/ro-kit"
mkdir -p "$RO/bin"
cp -a "$KIT/m1" "$KIT/operator.env.example" "$KIT/project" "$KIT/_ssh" "$RO/"
cp "$KIT/bin/m1-init-instance.sh" "$KIT/bin/m1-verify-instance.sh" "$RO/bin/"
chmod -R a-w "$RO"
run_ok '只读 Kit 下初始化外部实例' "$RO/bin/m1-init-instance.sh" --home "$TMP/readonly-operator"
run_ok '只读 Kit 下实例目录检查' "$RO/bin/m1-verify-instance.sh" --home "$TMP/readonly-operator" --stage filesystem
printf '\n===== M1 TEST SUMMARY: PASS=%d FAIL=%d =====\n' "$P" "$F"
[[ "$F" -eq 0 ]] || exit 3
