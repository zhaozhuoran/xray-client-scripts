#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/lib.sh"
need curl; need python3
url=${XRAY_CODEX_PROXY_URL:-http://127.0.0.1:17890}
target=${1:-https://api.openai.com/v1/models}
[[ $target == https://* ]] || die 'Use an HTTPS target for this check.'
if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
  printf 'Service: '
  systemctl is-active "$XRAY_SERVICE" || true
fi
python3 - "$url" <<'PY'
import socket,urllib.parse,sys
u=urllib.parse.urlsplit(sys.argv[1])
if u.scheme!='http' or not u.hostname or not u.port: sys.exit('Invalid HTTP proxy URL.')
try:
    with socket.create_connection((u.hostname,u.port),timeout=2): pass
except OSError: sys.exit('Proxy TCP listener is not reachable.')
print('Local proxy TCP listener is reachable.')
PY
code=$(curl --silent --show-error --proxy "$url" --noproxy '' --connect-timeout 10 --max-time 45 \
  --output /dev/null --write-out '%{http_code}' "$target") || die 'Proxy CONNECT/TLS/request failed; inspect Xray logs.'
printf 'Target HTTPS response: HTTP %s\n' "$code"
case $code in
  2??|3??|401|404|405) printf 'Transport test passed. HTTP 401 is expected for /v1/models without an API key.\n' ;;
  403|429) printf 'Transport reached an HTTPS responder, but access or rate limiting was denied; this is not a usable Codex login/inference check.\n' >&2; exit 2 ;;
  *) die 'Unexpected target status; inspect the endpoint and Xray logs.' ;;
esac
