#!/usr/bin/env zsh
# 1Password → .env (secret references)
# Function: gen_envfile_1p
# -------------------------------------------------------------------
# Use in two ways:
#  1) Source into Zsh, then call the function:
#       source ./gen_envfile_1p.zsh
#       gen_envfile_1p -o .env.1p
#  2) Run directly as a Zsh script (shebang included):
#       chmod +x ./gen_envfile_1p.zsh
#       ./gen_envfile_1p.zsh -o .env.1p
#
# NOTE: Requires **Zsh**. Do NOT run with `sh` or `bash` (you'll see
#       errors like "parse error near `local'"), because this uses Zsh
#       features (arrays, [[ ]], here-strings, etc.).
#
# What it does:
#   Lets you multi-select **API Credential** items via fzf and writes a
#   .env file containing **1Password secret references** (op://...), not
#   plaintext. Use with `op run --env-file ... -- <cmd>`.
#
# Deps: 1Password CLI `op`, `jq`, `fzf`

setopt err_return pipe_fail

# --- Function --------------------------------------------------------

gen_envfile_1p() {
  emulate -L zsh
  set -o pipefail

  local vault="" outfile=".env.1p" quiet=0 skip_confirm=0

  while getopts "v:o:qyh" opt; do
    case $opt in
      v) vault="$OPTARG" ;;
      o) outfile="$OPTARG" ;;
      q) quiet=1 ;;
      y) skip_confirm=1 ;;
      h)
        cat >&2 <<'USAGE'
gen_envfile_1p [-v <vault>] [-o <output.env>] [-q] [-y]

Creates a .env file containing 1Password secret *references* from selected
"API Credential" items. Run your command with:
  op run --env-file "<output.env>" -- <your command>

Examples:
  gen_envfile_1p -o .env.1p
  op run --env-file .env.1p -- ./server
  op run --env-file .env.1p -- env | grep -E 'KEY|TOKEN|SECRET'

Options:
  -v <vault>   Select from specific vault
  -o <file>    Output file (default: .env.1p)
  -y           Skip confirmation prompt
  -q           Suppress usage message

Tips:
  • Keep the file out of git (.gitignore).
  • This writes references (op://...), not raw secrets.
USAGE
        return 0
        ;;
      *) echo "Try: gen_envfile_1p -h" >&2; return 2 ;;
    esac
  done

  # sanity checks
  for cmd in op jq fzf; do
    command -v "$cmd" >/dev/null || { echo "Missing '$cmd' in PATH" >&2; return 1; }
  done

  # ensure we're signed in
  if ! op whoami >/dev/null 2>&1; then
    echo "Signing in to 1Password..." >&2
    eval "$(op signin)" || { echo "op signin failed" >&2; return 1; }
  fi

  # list items (filter to API Credential) and pick with fzf (multi-select)
  local -a list_cmd=(op item list --categories "API Credential" --format json)
  [[ -n "$vault" ]] && list_cmd+=(--vault "$vault")

  local rows
  rows="$("${list_cmd[@]}" \
    | jq -r '.[] | [.id, .title, .vault.name] | @tsv' \
    | fzf -m --ansi --with-nth=2,3 \
            --prompt="Select API Credential items > " \
            --preview 'op item get {1} --format json | jq -C "{title, vault:.vault.name, fields:[(.fields // [])[]|{label,type,purpose}]}"' \
            --preview-window=right:70%)" || return $?

  [[ -z "$rows" ]] && { echo "No items selected." >&2; return 1; }

  # build env content
  local env_content=""
  while IFS=$'\t' read -r id title _vault; do
    local line
    line=$(op item get "$id" --format json \
      | jq -r --arg TITLE "$title" '
          def slug(s): (s|ascii_upcase|gsub("[^A-Z0-9]+";"_")|gsub("^_+|_+$";""));
          def clean_title: slug($TITLE) | gsub("_API_CREDENTIALS?$";"") | gsub("_CREDENTIALS?$";"");
          (.fields // [])[]
          | select(.reference != null and .label == "credential")
          | clean_title + "_API_KEY=" + (.reference)
        ')
    [[ -n "$line" ]] && env_content+="$line"$'\n'
  done <<< "$rows"

  if [[ -z "$env_content" ]]; then
    echo "No secret-reference fields found. Nothing written." >&2
    return 1
  fi

  # show preview and confirm unless -y was passed
  if (( ! skip_confirm )); then
    echo "Proposed output for $outfile:" >&2
    echo "---" >&2
    echo -n "$env_content" >&2
    echo "---" >&2
    echo -n "Write this file? [y/N] " >&2
    local response
    read -r response
    if [[ "$response" != [yY]* ]]; then
      echo "Cancelled." >&2
      return 1
    fi
  fi

  # write the file
  echo -n "$env_content" > "$outfile"
  
  # set restrictive perms (harmless even though refs only)
  chmod 600 "$outfile" 2>/dev/null || true

  # default usage message -> STDERR (suppress with -q)
  if (( ! quiet )); then
    cat >&2 <<EOF
Wrote $outfile

Usage Examples:
  # Run your app with secrets injected at runtime
  op run --env-file "$outfile" -- <your command>

  # Inspect expanded env (for debugging only)
  op run --env-file "$outfile" -- env | grep -E 'KEY|TOKEN|SECRET'

Tip: keep $outfile out of git (.gitignore). Suppress this message with -q.
EOF
  fi
}

# --- If executed as a script, run the function ----------------------
if [[ -z ${ZSH_VERSION:-} ]]; then
  echo "This script requires Zsh. Run with zsh or source it in Zsh." >&2
  exit 1
fi

# If this file is executed directly (not sourced), call the function
if [[ "${(%):-%N}" == "$0" ]]; then
  gen_envfile_1p "$@"
fi
