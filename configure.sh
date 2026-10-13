#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/lib.sh"
need python3
input=${1:-"$script_dir/settings.json"}
output=${2:-"$script_dir/config.json"}
[[ -f $input ]] || die 'Copy settings.example.json to settings.json, then fill in the remote connection details.'
python3 - "$input" "$output" "$script_dir/configs/config-tcp-tls.json" <<'PY'
import json,sys,pathlib,tempfile,os,uuid
s=json.load(open(sys.argv[1],encoding='utf-8'))
c=json.load(open(sys.argv[3],encoding='utf-8'))
address=s.get('server_address',''); name=s.get('tls_server_name','')
if not address or address.endswith('.example.com') or address=='example.com':
    sys.exit('Please set server_address to the real remote address.')
if not name or name.endswith('.example.com'):
    sys.exit('Please set tls_server_name to the real certificate domain.')
try: identifier=str(uuid.UUID(s['uuid']))
except (KeyError,ValueError,TypeError): sys.exit('uuid must be a valid UUID.')
if identifier=='00000000-0000-0000-0000-000000000000': sys.exit('Replace the placeholder UUID.')
port=s.get('server_port',443); local=s.get('local_http_port',17890)
if type(port)!=int or not 1<=port<=65535: sys.exit('Invalid server_port.')
if type(local)!=int or not 1024<=local<=65535: sys.exit('Invalid local_http_port.')
transport=s.get('transport','raw')
if transport=='tcp': transport='raw'
if transport not in ('raw','ws','grpc'): sys.exit('transport must be raw, tcp, ws, or grpc.')
flow=s.get('flow','')
if flow not in ('','xtls-rprx-vision','xtls-rprx-vision-udp443'): sys.exit('Unsupported flow.')
if flow and transport!='raw': sys.exit('This bundle supports Vision only with RAW/TCP + TLS.')
out=c['outbounds'][0]
out['settings'].update(address=address,port=port,id=identifier,flow=flow,encryption=s.get('vless_encryption','none'))
if not out['settings']['encryption']: sys.exit('vless_encryption cannot be empty.')
stream=out['streamSettings']; stream['network']=transport
stream['tlsSettings']['serverName']=name
if transport=='ws':
    stream['tlsSettings']['alpn']=['http/1.1']
    stream['wsSettings']={'path':s.get('ws_path','/vless'),'host':s.get('ws_host') or name}
elif transport=='grpc':
    stream['tlsSettings']['alpn']=['h2']
    stream['grpcSettings']={'serviceName':s.get('grpc_service_name','vless'),'multiMode':False}
c['inbounds'][0]['port']=local
dest=pathlib.Path(sys.argv[2]).absolute(); dest.parent.mkdir(parents=True,exist_ok=True)
fd,tmp=tempfile.mkstemp(prefix='.config-',dir=dest.parent)
try:
    with os.fdopen(fd,'w',encoding='utf-8') as f: json.dump(c,f,ensure_ascii=False,indent=2); f.write('\n')
    os.chmod(tmp,0o600); os.replace(tmp,dest)
finally:
    if os.path.exists(tmp): os.unlink(tmp)
print(f'Generated {dest}; HTTP listener: 127.0.0.1:{local}.')
PY
if [[ -x $XRAY_BIN ]]; then
  "$XRAY_BIN" run -test -config "$output"
fi
