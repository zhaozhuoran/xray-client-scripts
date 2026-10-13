#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/lib.sh"
root_required; systemd_required
input=${1:-"$script_dir/config.json"}
[[ -f $input ]] || die "Configuration not found: $input"
getent passwd "$XRAY_ACCOUNT" >/dev/null || die 'Run install-service.sh first to create the service account.'
validate_config "$input"
install -d -m 0750 -o root -g "$XRAY_ACCOUNT" /etc/xray-codex
tmp=$(mktemp /etc/xray-codex/.config.XXXXXX)
trap 'rm -f -- "$tmp"' EXIT
install -m 0640 -o root -g "$XRAY_ACCOUNT" "$input" "$tmp"
had_previous=0
if [[ -f $XRAY_CONFIG ]]; then
  install -m 0640 -o root -g "$XRAY_ACCOUNT" "$XRAY_CONFIG" "$XRAY_CONFIG.previous"
  had_previous=1
fi
active=0
if systemctl is-active --quiet "$XRAY_SERVICE"; then active=1; fi
mv -f -- "$tmp" "$XRAY_CONFIG"
if (( active )); then
  if ! systemctl restart "$XRAY_SERVICE" || ! wait_service_ready; then
    if (( had_previous )); then
      install -m 0640 -o root -g "$XRAY_ACCOUNT" "$XRAY_CONFIG.previous" "$XRAY_CONFIG"
      systemctl restart "$XRAY_SERVICE" || true
    fi
    die 'Service restart failed; previous config restored where available. Inspect journalctl.'
  fi
fi
printf 'Config deployed to %s. Remote reachability still requires check.sh.\n' "$XRAY_CONFIG"
