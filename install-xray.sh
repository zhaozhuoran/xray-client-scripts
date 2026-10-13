#!/usr/bin/env bash
# Install/update this bundle's private Xray binary without touching another Xray installation.
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/lib.sh"
root_required
need curl; need python3; need install
version=${1:-latest}
[[ $version == latest || $version =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die 'Use latest or a release tag such as v26.3.27.'
case $(uname -m) in
  x86_64|amd64) asset='Xray-linux-64.zip' ;;
  aarch64|arm64) asset='Xray-linux-arm64-v8a.zip' ;;
  armv7l) asset='Xray-linux-arm32-v7a.zip' ;;
  *) die 'Supported Linux architectures: x86_64, aarch64, armv7l.' ;;
esac
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
if [[ $version == latest ]]; then api='https://api.github.com/repos/XTLS/Xray-core/releases/latest'
else api="https://api.github.com/repos/XTLS/Xray-core/releases/tags/$version"; fi
curl --fail --show-error --silent --location --retry 3 --connect-timeout 15 --max-time 90 \
  -H 'Accept: application/vnd.github+json' -H 'User-Agent: xray-codex-client-installer' "$api" -o "$tmp/release.json"
mapfile -t release < <(python3 - "$tmp/release.json" "$asset" <<'PY'
import json,sys
r=json.load(open(sys.argv[1])); matches=[a for a in r.get('assets',[]) if a['name']==sys.argv[2]]
if len(matches)!=1 or r.get('prerelease') or r.get('draft'): sys.exit('Stable release asset not found.')
a=matches[0]; print(r['tag_name']); print(a['browser_download_url']); print(a.get('digest') or '')
dgst=next((x['browser_download_url'] for x in r['assets'] if x['name']==sys.argv[2]+'.dgst'),'')
print(dgst)
PY
)
[[ ${#release[@]} -eq 4 && ${release[0]} == v* && ${release[1]} == https://github.com/XTLS/Xray-core/releases/download/* ]] || die 'Could not resolve a valid official release.'
printf 'Downloading official %s (%s)...\n' "${release[0]}" "$asset"
curl --fail --show-error --location --retry 3 --connect-timeout 15 --max-time 600 "${release[1]}" -o "$tmp/xray.zip"
if [[ ! ${release[2]} =~ ^sha256:[0-9a-fA-F]{64}$ ]]; then
  [[ ${release[3]} == https://github.com/XTLS/Xray-core/releases/download/* ]] || die 'Release has no SHA256 metadata or digest asset.'
  curl --fail --show-error --silent --location --retry 3 --connect-timeout 15 --max-time 90 "${release[3]}" -o "$tmp/checksum.dgst"
fi
python3 - "$tmp" "${release[2]}" <<'PY'
import sys,pathlib,hashlib,re,zipfile
d=pathlib.Path(sys.argv[1]); digest=sys.argv[2]
if digest.startswith('sha256:'): expected=digest.split(':',1)[1].lower()
else:
    text=(d/'checksum.dgst').read_text()
    match=re.search(r'SHA2?-?256[^\n]*?\b([0-9a-fA-F]{64})\b',text,re.I)
    if not match: sys.exit('Cannot read SHA256 from official .dgst file.')
    expected=match.group(1).lower()
if hashlib.sha256((d/'xray.zip').read_bytes()).hexdigest()!=expected: sys.exit('SHA256 mismatch; refusing to install.')
with zipfile.ZipFile(d/'xray.zip') as z:
    if z.namelist().count('xray')!=1: sys.exit('Archive does not contain exactly one root xray binary.')
    (d/'xray').write_bytes(z.read('xray'))
(d/'xray').chmod(0o755)
print('Official SHA256 verified.')
PY
"$tmp/xray" version
if [[ -f $XRAY_CONFIG ]]; then validate_config "$XRAY_CONFIG" "$tmp/xray"; fi
install -d -m 0755 /usr/local/lib/xray-codex
if [[ -f $XRAY_BIN ]]; then install -m 0755 "$XRAY_BIN" "$XRAY_BIN.previous"; fi
install -m 0755 "$tmp/xray" "$XRAY_BIN.new"
mv -f -- "$XRAY_BIN.new" "$XRAY_BIN"
printf 'Installed %s at %s. Use update-xray.sh to also restart an active service.\n' "${release[0]}" "$XRAY_BIN"
