#!/usr/bin/env bash
# Standalone foundation entrypoint; integrating into upstream does not overwrite upstream install.sh.
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/bin/m1-init-instance.sh" "$@"
