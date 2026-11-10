#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
SYPC_FLUTTER_BIN="${SYPC_FLUTTER_BIN:-flutter}"
"$SYPC_FLUTTER_BIN" pub get --enforce-lockfile
"$SYPC_FLUTTER_BIN" analyze --no-pub
"$SYPC_FLUTTER_BIN" test --no-pub --reporter expanded
