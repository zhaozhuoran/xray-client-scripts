#!/usr/bin/env bash
# Shared functions for executable deployment scripts; do not source into a login shell.
XRAY_SERVICE='xray-codex.service'
XRAY_BIN='/usr/local/lib/xray-codex/xray'
XRAY_CONFIG='/etc/xray-codex/config.json'
XRAY_ACCOUNT='xray-codex'

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }
root_required() { [[ $EUID -eq 0 ]] || die 'Run this deployment command with sudo.'; }
systemd_required() { need systemctl; [[ -d /run/systemd/system ]] || die 'This host is not running systemd.'; }
validate_config() {
  local config=$1 binary=${2:-$XRAY_BIN}
  [[ -x $binary ]] || die "Xray binary not found: $binary"
  need python3
  python3 - "$config" <<'PY' || return 1
import json,sys,ipaddress
c=json.load(open(sys.argv[1],encoding='utf-8'))
ins=c.get('inbounds',[])
if len(ins)!=1 or ins[0].get('protocol')!='http' or ins[0].get('listen')!='127.0.0.1':
    sys.exit('Expected one HTTP inbound listening on 127.0.0.1.')
port=ins[0].get('port')
if type(port) is not int or not 1024 <= port <= 65535:
    sys.exit('Local HTTP port must be in 1024..65535.')
outs=c.get('outbounds',[])
v=[o for o in outs if o.get('protocol')=='vless']
if len(v)!=1 or any(o.get('protocol') not in ('vless','blackhole') for o in outs):
    sys.exit('Expected one VLESS outbound and optional blackhole only; no direct fallback.')
s=v[0]['settings']
if 'vnext' in s:
    peer=s['vnext'][0]; user=peer['users'][0]
else:
    peer=user=s
address=peer.get('address','')
if not address or address.endswith('.example.com') or address=='example.com':
    sys.exit('Replace the example server address before deploying.')
if user.get('id') in ('','00000000-0000-0000-0000-000000000000'):
    sys.exit('Replace the placeholder UUID before deploying.')
st=v[0].get('streamSettings',{})
tls=st.get('tlsSettings',{})
if st.get('security')!='tls' or tls.get('allowInsecure',False):
    sys.exit('This bundle requires TLS with certificate verification.')
if not tls.get('serverName') or tls['serverName'].endswith('.example.com'):
    sys.exit('Set the real TLS serverName before deploying.')
print('Deployment checks passed (no network connection attempted).')
PY
  "$binary" run -test -config "$config"
}

wait_service_ready() {
  # Type=simple can become active before the process has bound its socket.
  python3 - "$XRAY_CONFIG" "$XRAY_SERVICE" <<'PY'
import json,socket,subprocess,sys,time
c=json.load(open(sys.argv[1])); host=c['inbounds'][0]['listen']; port=c['inbounds'][0]['port']
deadline=time.monotonic()+20
while time.monotonic()<deadline:
    active=subprocess.run(['systemctl','is-active','--quiet',sys.argv[2]],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0
    if active:
        try:
            with socket.create_connection((host,port),timeout=.5): pass
            time.sleep(.3)
            if subprocess.run(['systemctl','is-active','--quiet',sys.argv[2]],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0:
                print('Service active and local HTTP listener ready.');sys.exit(0)
        except OSError: pass
    time.sleep(.25)
sys.exit('Service/HTTP listener did not become ready within 20 seconds.')
PY
}
