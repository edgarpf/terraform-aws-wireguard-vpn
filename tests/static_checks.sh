#!/usr/bin/env bash
# Static checks: user list changes must not alter bootstrap user_data (peers=[] only).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

grep -q 'user_data.*base64encode(local.setup_script)' "$ROOT/main.tf" \
  || fail "main.tf must use local.setup_script for user_data"

grep -q 'user_data_replace_on_change = false' "$ROOT/main.tf" \
  || fail "main.tf must set user_data_replace_on_change = false"

grep -q 'peers              = \[\]' "$ROOT/locals.tf" \
  || fail "locals.tf wg_bootstrap_config must use peers = []"

grep -q 'local.wg_server_config' "$ROOT/wg_sync.tf" \
  || fail "wg_server_config must be applied via wg_sync.tf only"

if grep -q 'local.wg_server_config' "$ROOT/main.tf"; then
  fail "main.tf must not embed wg_server_config in user_data"
fi

echo "OK: bootstrap user_data is stable; full peer list is synced via wg syncconf only."
