#!/usr/bin/env bash
# Builds the COMPLETE upstream operator-kit 2.0.0 + additive M1 foundation locally.
# Requires access to the private repo using the user's own Git credentials.
set -euo pipefail
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
UPSTREAM_SHA='78187984af240cec1a1c9568f5a14429701cc860'
SRC="https://github.com/AlanCc1994/operator-kit.git"; OUT=''
while (($#)); do
  case "$1" in
    --source) SRC="${2:?missing --source}"; shift 2;;
    --out) OUT="${2:?missing --out}"; shift 2;;
    --help|-h) echo "用法：$0 --source /path/to/local/operator-kit --out /path/to/new/operator-kit-m1"; exit 0;;
    *) echo "未知参数 $1" >&2; exit 2;;
  esac
done
[[ -n "$OUT" ]] || { echo '必须提供 --out 目录' >&2; exit 2; }
[[ ! -e "$OUT" ]] || { echo "拒绝覆盖已存在目录：$OUT" >&2; exit 3; }
[[ "$OUT" != "$BASE" ]] || { echo '输出目录不能是基础包目录' >&2; exit 3; }
command -v git >/dev/null || { echo '缺少 Git' >&2; exit 4; }
git clone --quiet --no-hardlinks "$SRC" "$OUT"
# Branch can advance; checkout exact reviewed commit (never silently take latest).
git -C "$OUT" checkout --detach --quiet "$UPSTREAM_SHA" || {
  echo "M1_ERR: 无法取得指定 upstream commit $UPSTREAM_SHA" >&2; exit 4;
}
[[ "$(git -C "$OUT" rev-parse HEAD)" == "$UPSTREAM_SHA" ]] || exit 4
for dir in m1 tests/m1; do
  [[ ! -e "$OUT/$dir" ]] || { echo "目标已有 $dir，拒绝覆盖" >&2; exit 3; }
  mkdir -p "$(dirname "$OUT/$dir")"
  cp -a "$BASE/$dir" "$OUT/$dir"
done
for file in bin/m1-init-instance.sh bin/m1-verify-instance.sh docs/M1_ARCHITECTURE.md docs/PATCH_PROTOCOL.md; do
  [[ ! -e "$OUT/$file" ]] || { echo "目标已有 $file，拒绝覆盖" >&2; exit 3; }
  mkdir -p "$(dirname "$OUT/$file")"
  cp -a "$BASE/$file" "$OUT/$file"
done
# One targeted default-template correction, preserving the entire original upstream file.
python3 - "$OUT/project/project.env.example" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); old='$KIT_ROOT/project/identity/accepted.sha256'; new='$OPERATOR_HOME/project/identity/accepted.sha256'
s=p.read_text()
if s.count(old)!=1: raise SystemExit('M1_ERR: upstream project template preimage mismatch')
p.write_text(s.replace(old,new))
PY
# Also keep the public M1 docs in the generated tree. The original runtime scripts are untouched.
chmod +x "$OUT/bin/m1-init-instance.sh" "$OUT/bin/m1-verify-instance.sh"
git -C "$OUT" switch -c m1/base-r0 >/dev/null
git -C "$OUT" add m1/ tests/m1/ bin/m1-init-instance.sh bin/m1-verify-instance.sh \
  docs/M1_ARCHITECTURE.md docs/PATCH_PROTOCOL.md project/project.env.example
GIT_AUTHOR_DATE='2026-10-15T08:00:00Z' GIT_COMMITTER_DATE='2026-10-15T08:00:00Z' \
  git -C "$OUT" -c user.name='Operator Kit M1 Foundation' \
  -c user.email='operator-kit-m1@local.invalid' commit -qm 'M1 R0: isolated external instance foundation'
git -C "$OUT" tag m1-base-r0
"$OUT/tests/m1/run-tests.sh" --kit "$OUT"
echo '====== FULL KIT ASSEMBLY PASS ======'
echo "UPSTREAM_SHA=$UPSTREAM_SHA"
echo "BASE_COMMIT=$(git -C "$OUT" rev-parse HEAD)"
echo "BASE_TREE=$(git -C "$OUT" rev-parse HEAD^{tree})"
echo "BASE_TAG=m1-base-r0"
echo "FULL_KIT=$OUT"
echo '下一轮 patch 必须基于上述 BASE_COMMIT / BASE_TREE 生成。'
