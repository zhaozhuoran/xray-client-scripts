#!/usr/bin/env bash
# Remove only the systemd unit. Retain binary, credentials/config, helpers, and account.
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/lib.sh"
root_required; systemd_required
systemctl disable --now "$XRAY_SERVICE" || true
rm -f -- /etc/systemd/system/xray-codex.service
systemctl daemon-reload
printf 'Service removed; config, binary, helper files and service account retained.\n'
