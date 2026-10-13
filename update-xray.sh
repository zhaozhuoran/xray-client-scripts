#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/lib.sh"
root_required; systemd_required
active=0
if systemctl is-active --quiet "$XRAY_SERVICE"; then active=1; fi
"$script_dir/install-xray.sh" "${1:-latest}"
if (( active )); then
  if ! systemctl restart "$XRAY_SERVICE" || ! wait_service_ready; then
    if [[ -f $XRAY_BIN.previous ]]; then
      install -m 0755 "$XRAY_BIN.previous" "$XRAY_BIN.rollback"
      mv -f -- "$XRAY_BIN.rollback" "$XRAY_BIN"
      systemctl restart "$XRAY_SERVICE" || true
    fi
    die 'Updated service could not start; previous binary restored where available.'
  fi
fi
printf 'Update complete. Existing proxy connections may have been interrupted. Run check.sh.\n'
