#!/usr/bin/env zsh
set -euo pipefail

##############################################################################
# 1. Parse flags
##############################################################################
outfile=".env"
force=false
while getopts "o:f" opt; do
  case "$opt" in
    o) outfile="$OPTARG" ;;
    f) force=true ;;
    *) exit 2 ;;
  esac
done

##############################################################################
# 2. Dependency checks
##############################################################################
# sanity checks
for cmd in jq fzf; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "missing: $cmd" >&2; exit 1; }
done

emit_env() {
  # build env content
  local env_content=""
  while IFS='=' read -r key value; do
    [[ -z "$key" ]] && continue
    env_content+="${key}=${value}"$'\n'
  done

  # write the file
  if [[ -e "$outfile" && "$force" != true ]]; then
    echo "refusing to overwrite $outfile (use -f)" >&2
    return 1
  fi
  # shellcheck disable=SC2059
  printf "$env_content" > "$outfile"
  chmod 600 "$outfile"  # env files carry secrets; keep them owner-only
}

emit_env
