#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/proxy.sh"
command -v codex >/dev/null 2>&1 || { printf 'codex is not on PATH.\n' >&2; exit 1; }
exec codex "$@"
