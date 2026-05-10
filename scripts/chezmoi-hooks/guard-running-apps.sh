#!/usr/bin/env bash
#
# chezmoi hooks.apply.pre: warn (and refuse) if any managed plist would
# change this apply while its app is currently running. Persists the
# pending bundle-id list to ${XDG_STATE_HOME}/dotfiles/plist-pending.txt
# for the matching post-hook.
#
# Set DOTFILES_SKIP_PLIST_HOOKS=1 to short-circuit both this hook and
# the post-hook entirely (sandboxed applies, force-apply over running
# apps, etc.).
#
set -euo pipefail

# chezmoi runs hooks unconditionally, including under `chezmoi apply
# --dry-run`. Detect dry-run via CHEZMOI_ARGS (chezmoi <2.70 has no
# dedicated DRY_RUN var). Handle bare `--dry-run`, `--dry-run=true`,
# and short-flag bundles like `-n`, `-nv`, `-vn`. Skip on dry-run to
# keep `chezmoi apply --dry-run` side-effect-free.
for arg in ${CHEZMOI_ARGS:-}; do
  case "$arg" in
    --dry-run|--dry-run=true) exit 0 ;;
    --*) ;;
    -*n*) exit 0 ;;
  esac
done

# Explicit opt-out short-circuits both hooks (this one and the post-hook
# read the same var). Use cases: zsh-fresh-shells.zsh's sandboxed verify
# (running apps don't read from temp HOME, no race possible), or any
# operator who wants to force-apply over running apps without the
# cfprefsd kill side-effect.
if [ "${DOTFILES_SKIP_PLIST_HOOKS:-0}" = "1" ]; then
  exit 0
fi

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
state_file="$state_dir/plist-pending.txt"
mkdir -p "$state_dir"
: > "$state_file"

# Scope the recursive `chezmoi status` to whatever destination this apply
# is targeting. chezmoi exports CHEZMOI_DEST_DIR for hooks; if the parent
# apply passed --destination=<dir>, our recursive status must check that
# same dir (otherwise it falls back to chezmoi's default destination,
# typically $HOME, and we'd report drift from a different tree). For
# default applies CHEZMOI_DEST_DIR == $HOME, so the case-glob below still
# matches the same set of paths.
target_root="${CHEZMOI_DEST_DIR:-$HOME}"
status_args=(--path-style=absolute)
[ -n "${CHEZMOI_DEST_DIR:-}" ] && status_args+=(--destination "$CHEZMOI_DEST_DIR")

# Ask chezmoi which targets would actually change. Status format is two
# status flags + space + path. Second flag describes the target side.
pending=()
while IFS= read -r line; do
  [[ ${#line} -lt 4 ]] && continue
  target_flag="${line:1:1}"
  path="${line:3}"
  case "$target_flag" in
    " "|"-") continue ;;
  esac
  case "$path" in
    "$target_root/Library/Preferences/"*.plist|\
    "$target_root/Library/Containers/"*"/Data/Library/Preferences/"*.plist)
      id="${path##*/}"; id="${id%.plist}"
      pending+=("$id")
      ;;
  esac
done < <(chezmoi status "${status_args[@]}" 2>/dev/null || true)

if (( ${#pending[@]} == 0 )); then
  exit 0
fi

printf '%s\n' "${pending[@]}" > "$state_file"

running=()
for id in "${pending[@]}"; do
  if /usr/bin/lsappinfo info -only bundleid "$id" 2>/dev/null | grep -q "\"$id\""; then
    running+=("$id")
  fi
done

if (( ${#running[@]} == 0 )); then
  exit 0
fi

printf 'guard-running-apps: pending plist changes for these running apps:\n' >&2
printf '  - %s\n' "${running[@]}" >&2
printf '\n' >&2
printf 'These apps will overwrite our writes when they quit. Quit them, or\n' >&2
printf 'set DOTFILES_SKIP_PLIST_HOOKS=1 to apply anyway.\n' >&2
exit 1
