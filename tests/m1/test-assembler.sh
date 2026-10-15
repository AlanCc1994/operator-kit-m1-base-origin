#!/usr/bin/env bash
# Offline assembly smoke test with dummy git upstream. No access to real private repo required.
set -euo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/upstream/project" "$TMP/upstream/bin" "$TMP/foundation/scripts"
printf 'IDENTITY_MANIFEST="$KIT_ROOT/project/identity/accepted.sha256"\n' > "$TMP/upstream/project/project.env.example"
printf '#!/bin/bash\nexit 0\n' > "$TMP/upstream/install.sh"
printf '2.0.0\n' > "$TMP/upstream/VERSION"
cp "$KIT/operator.env.example" "$TMP/upstream/operator.env.example"
git -C "$TMP/upstream" init -q -b main
git -C "$TMP/upstream" add .
git -C "$TMP/upstream" -c user.name='M1 Test' -c user.email='m1-test@local.invalid' commit -qm 'dummy upstream'
expected="$(git -C "$TMP/upstream" rev-parse HEAD)"
# Only the fixture's script is modified to pin its synthetic upstream commit.
cp -a "$KIT/m1" "$KIT/bin" "$KIT/tests" "$KIT/docs" "$KIT/project" "$KIT/_ssh" "$TMP/foundation/"
cp "$KIT/operator.env.example" "$TMP/foundation/"
sed "s/78187984af240cec1a1c9568f5a14429701cc860/$expected/" "$KIT/scripts/assemble-full-kit.sh" > "$TMP/foundation/scripts/assemble-full-kit.sh"
chmod +x "$TMP/foundation/scripts/assemble-full-kit.sh"
"$TMP/foundation/scripts/assemble-full-kit.sh" --source "$TMP/upstream" --out "$TMP/full" > "$TMP/log" 2>&1 || { tail -100 "$TMP/log"; exit 1; }
[[ "$(git -C "$TMP/full" tag -l m1-base-r0)" == 'm1-base-r0' ]]
[[ -z "$(git -C "$TMP/full" status --porcelain)" ]]
[[ -f "$TMP/full/bin/m1-init-instance.sh" ]]
[[ -f "$TMP/full/m1/init.sh" ]]
[[ "$(cat "$TMP/full/VERSION")" == '2.0.0' ]]
[[ "$(grep -c '\$OPERATOR_HOME/project/identity/accepted.sha256' "$TMP/full/project/project.env.example")" == 1 ]]
[[ "$(sed -n '2p' "$TMP/full/install.sh")" == 'exit 0' ]]
echo 'M1_ASSEMBLER_TEST=PASS synthetic_upstream=true actual_private_upstream_tested=false'
