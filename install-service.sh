#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/lib.sh"
root_required; systemd_required; need useradd; need getent
input=${1:-"$script_dir/config.json"}
[[ -f $input ]] || die 'Generate config.json with configure.sh first.'
validate_config "$input"
if ! getent passwd "$XRAY_ACCOUNT" >/dev/null; then
  if [[ -x /usr/sbin/nologin ]]; then login_shell=/usr/sbin/nologin; else login_shell=/sbin/nologin; fi
  useradd --system --user-group --no-create-home --home-dir /nonexistent --shell "$login_shell" "$XRAY_ACCOUNT"
fi
"$script_dir/apply-config.sh" "$input"
install -d -m 0755 /usr/local/share/xray-codex
for file in lib.sh proxy.sh unproxy.sh run-codex.sh check.sh service.sh; do
  install -m 0755 "$script_dir/$file" "/usr/local/share/xray-codex/$file"
done
install -m 0644 "$script_dir/xray-codex.service" /etc/systemd/system/xray-codex.service
systemctl daemon-reload
systemctl enable --now "$XRAY_SERVICE"
wait_service_ready || die 'Service did not become ready; inspect journalctl.'
printf 'Service installed. Logs: journalctl -u %s -n 50 --no-pager\n' "$XRAY_SERVICE"
printf 'Session switch: source /usr/local/share/xray-codex/proxy.sh\n'
