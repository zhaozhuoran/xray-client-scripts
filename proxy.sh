#!/usr/bin/env bash
# Source this file in Bash. Do not set shell options or traps in the caller.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  printf 'Use: source ./proxy.sh (or ./run-codex.sh). Executing this file cannot change the parent shell.\n' >&2
  exit 2
fi
_xray_codex_proxy_enable() {
  if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 3) )); then
    printf 'Bash 4.3 or newer is required.\n' >&2; return 1
  fi
  if [[ ${_XRAY_CODEX_PROXY_ACTIVE:-0} == 1 ]]; then
    printf 'Proxy is already enabled in this shell.\n'; return 0
  fi
  local proxy_url=${XRAY_CODEX_PROXY_URL:-http://127.0.0.1:17890}
  local name declaration flags
  local -a names=(HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY http_proxy https_proxy all_proxy no_proxy)
  for name in "${names[@]}"; do
    declaration=$(declare -p "$name" 2>/dev/null) || declaration=''
    flags=${declaration#declare -}; flags=${flags%% *}
    if [[ -n $flags && $flags != '-' && $flags != x ]]; then
      printf 'Cannot safely change a variable with special attributes: %s\n' "$name" >&2; return 1
    fi
  done
  command -v python3 >/dev/null 2>&1 || { printf 'python3 is required for the listener check.\n' >&2; return 1; }
  python3 - "$proxy_url" <<'PY' || return 1
import sys,socket,urllib.parse
u=urllib.parse.urlsplit(sys.argv[1])
if u.scheme!='http' or not u.hostname or not u.port:
    sys.exit('XRAY_CODEX_PROXY_URL must be an HTTP proxy URL with an explicit port.')
try:
    with socket.create_connection((u.hostname,u.port),timeout=2): pass
except OSError:
    sys.exit('Local proxy is not listening. Start xray-codex.service and run check.sh.')
PY
  declare -gA _XRAY_CODEX_PROXY_OLD_VALUES=()
  declare -gA _XRAY_CODEX_PROXY_OLD_SET=()
  declare -gA _XRAY_CODEX_PROXY_OLD_EXPORT=()
  declare -gA _XRAY_CODEX_PROXY_OLD_DECLARED=()
  for name in "${names[@]}"; do
    if [[ -v $name ]]; then
      _XRAY_CODEX_PROXY_OLD_SET[$name]=1
      _XRAY_CODEX_PROXY_OLD_VALUES[$name]=${!name}
    else
      _XRAY_CODEX_PROXY_OLD_SET[$name]=0
      _XRAY_CODEX_PROXY_OLD_VALUES[$name]=''
    fi
    declaration=$(declare -p "$name" 2>/dev/null) || declaration=''
    if [[ -n $declaration ]]; then _XRAY_CODEX_PROXY_OLD_DECLARED[$name]=1
    else _XRAY_CODEX_PROXY_OLD_DECLARED[$name]=0; fi
    flags=${declaration#declare -}; flags=${flags%% *}
    if [[ $flags == *x* ]]; then _XRAY_CODEX_PROXY_OLD_EXPORT[$name]=1
    else _XRAY_CODEX_PROXY_OLD_EXPORT[$name]=0; fi
  done
  export HTTP_PROXY="$proxy_url" HTTPS_PROXY="$proxy_url" http_proxy="$proxy_url" https_proxy="$proxy_url"
  export NO_PROXY='localhost,127.0.0.1,::1' no_proxy='localhost,127.0.0.1,::1'
  unset ALL_PROXY all_proxy
  _XRAY_CODEX_PROXY_ACTIVE=1
  printf 'Proxy enabled for this shell and subsequently started children. Existing Codex processes are unchanged.\n'
}
if _xray_codex_proxy_enable; then
  unset -f _xray_codex_proxy_enable
  return 0
else
  unset -f _xray_codex_proxy_enable
  return 1
fi
