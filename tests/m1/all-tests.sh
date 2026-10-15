#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
bash "$HERE/run-tests.sh"
bash "$HERE/test-assembler.sh"
echo 'M1_ALL_TESTS=PASS'
