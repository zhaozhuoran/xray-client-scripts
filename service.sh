#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/lib.sh"
systemd_required
case ${1:-status} in
  status) systemctl status "$XRAY_SERVICE" --no-pager ;;
  logs) exec journalctl -u "$XRAY_SERVICE" -n 100 -f ;;
  start|stop|restart|enable|disable) root_required; systemctl "$1" "$XRAY_SERVICE" ;;
  *) die 'Usage: service.sh [status|logs|start|stop|restart|enable|disable]' ;;
esac
