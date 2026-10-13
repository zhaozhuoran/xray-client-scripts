#!/usr/bin/env bash
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  printf 'Use: source ./unproxy.sh. Executing this file cannot change the parent shell.\n' >&2
  exit 2
fi
_xray_codex_proxy_disable() {
  if [[ ${_XRAY_CODEX_PROXY_ACTIVE:-0} != 1 ]]; then
    printf 'No proxy state to restore in this shell.\n'; return 0
  fi
  local name declaration flags
  local -a names=(HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY http_proxy https_proxy all_proxy no_proxy)
  for name in "${names[@]}"; do
    declaration=$(declare -p "$name" 2>/dev/null) || declaration=''
    flags=${declaration#declare -}; flags=${flags%% *}
    if [[ -n $flags && $flags != '-' && $flags != x ]]; then
      printf 'Cannot restore %s; it acquired special attributes. Backup retained.\n' "$name" >&2; return 1
    fi
  done
  for name in "${names[@]}"; do
    if [[ ${_XRAY_CODEX_PROXY_OLD_SET[$name]} == 1 ]]; then
      printf -v "$name" '%s' "${_XRAY_CODEX_PROXY_OLD_VALUES[$name]}"
      if [[ ${_XRAY_CODEX_PROXY_OLD_EXPORT[$name]} == 1 ]]; then export "$name"
      else export -n "$name"; fi
    else
      unset "$name"
      if [[ ${_XRAY_CODEX_PROXY_OLD_DECLARED[$name]} == 1 ]]; then
        declare -g "$name"
        if [[ ${_XRAY_CODEX_PROXY_OLD_EXPORT[$name]} == 1 ]]; then export "$name"; fi
      fi
    fi
  done
  unset _XRAY_CODEX_PROXY_ACTIVE _XRAY_CODEX_PROXY_OLD_VALUES _XRAY_CODEX_PROXY_OLD_SET _XRAY_CODEX_PROXY_OLD_EXPORT _XRAY_CODEX_PROXY_OLD_DECLARED
  printf 'Original proxy variables and export flags restored. Existing processes are unchanged.\n'
}
if _xray_codex_proxy_disable; then
  unset -f _xray_codex_proxy_disable
  return 0
else
  unset -f _xray_codex_proxy_disable
  return 1
fi
