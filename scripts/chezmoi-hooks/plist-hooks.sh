#!/usr/bin/env bash
#
# chezmoi hooks.apply.pre and hooks.apply.post, dispatched by mode ($1):
#
#   pre   Warn if any managed plist would change this apply while its app is
#         currently running. At a terminal, offers to quit those apps (a
#         real Apple Event quit, so unsaved-changes dialogs still fire) and
#         relaunch them after apply; declining or running non-interactively
#         leaves them running and refuses the apply, since a running app can
#         overwrite our write when it quits. Persists the pending bundle-id
#         list to ${XDG_STATE_HOME}/dotfiles/plist-pending.txt for `post`,
#         and the ids it successfully quit to plist-quit-by-guard.txt.
#   post  Read the pending bundle-id list written by `pre`. If non-empty,
#         kill cfprefsd once so the next read by any app picks up the new
#         files. Relaunches whatever `pre` quit, plus (if
#         DOTFILES_RELAUNCH_AFTER_APPLY=1, off by default) every app in the
#         pending list.
#
# Set DOTFILES_SKIP_PLIST_HOOKS=1 to short-circuit both modes entirely
# (sandboxed applies, force-apply over running apps, etc.).
#
set -euo pipefail

mode="${1:?usage: plist-hooks.sh pre|post}"

is_id_running() {
  /usr/bin/lsappinfo info -only bundleid "$1" 2>/dev/null | grep -q "\"$1\""
}

contains() {
  local needle="$1"; shift
  local hay
  for hay in "$@"; do
    [[ "$hay" == "$needle" ]] && return 0
  done
  return 1
}

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

# Explicit opt-out short-circuits both modes. Use cases: zsh-fresh-shells.zsh's
# sandboxed verify (running apps don't read from temp HOME, no race possible),
# or any operator who wants to force-apply over running apps without the
# cfprefsd kill side-effect.
if [ "${DOTFILES_SKIP_PLIST_HOOKS:-0}" = "1" ]; then
  exit 0
fi

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
state_file="$state_dir/plist-pending.txt"
quit_file="$state_dir/plist-quit-by-guard.txt"

case "$mode" in
pre)
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
    if is_id_running "$id"; then
      running+=("$id")
    fi
  done

  if (( ${#running[@]} == 0 )); then
    exit 0
  fi

  printf 'plist-hooks: pending plist changes for these running apps:\n' >&2
  printf '  - %s\n' "${running[@]}" >&2
  printf '\n' >&2

  # Non-interactive (CI, cron, a plain redirect): can't prompt, so refuse the
  # same way this hook always has. Interactive: offer to quit and relaunch
  # instead of just crashing. chezmoi wires a hook's stdin/stdout to its own,
  # which is the real terminal here, exactly like it does for `run_` scripts
  # (see home/.chezmoiscripts/run_onchange_after_15-xcode.sh.tmpl for the
  # same `[ -t 0 ] && [ -t 1 ]` idiom).
  if ! { [ -t 0 ] && [ -t 1 ]; }; then
    printf 'These apps will overwrite our writes when they quit. Quit them, or\n' >&2
    printf 'set DOTFILES_SKIP_PLIST_HOOKS=1 to apply anyway.\n' >&2
    exit 1
  fi

  printf 'Quit these apps now and relaunch them after apply? [Y/n] ' >&2
  response=""
  read -r response || true
  response="${response%$'\r'}"
  case "$response" in
    [Nn]*)
      printf 'Leaving them running; their plist changes may be overwritten when they quit.\n' >&2
      exit 0
      ;;
  esac

  for id in "${running[@]}"; do
    /usr/bin/osascript -e "tell application id \"$id\" to quit" >/dev/null 2>&1 || true
  done

  # Poll every app together (not one at a time) so a slow quitter doesn't
  # make the others wait their own timeout on top of its.
  : > "$quit_file"
  poll_interval=0.2
  max_iters=$(( ${DOTFILES_PLIST_QUIT_TIMEOUT_SECS:-20} * 5 ))
  still_pending=("${running[@]}")
  iters=0
  while (( ${#still_pending[@]} > 0 )) && (( iters < max_iters )); do
    next_pending=()
    for id in "${still_pending[@]}"; do
      if is_id_running "$id"; then
        next_pending+=("$id")
      else
        printf '%s\n' "$id" >> "$quit_file"
      fi
    done
    still_pending=("${next_pending[@]+"${next_pending[@]}"}")
    if (( ${#still_pending[@]} > 0 )); then
      sleep "$poll_interval"
      iters=$(( iters + 1 ))
    fi
  done

  for id in "${still_pending[@]+"${still_pending[@]}"}"; do
    printf 'plist-hooks: %s did not quit; leaving it running.\n' "$id" >&2
  done

  exit 0
  ;;
post)
  # No pre-mode output (or empty file) means no managed plists changed; nothing to do.
  if [[ ! -s $state_file ]]; then
    rm -f "$state_file" "$quit_file"
    exit 0
  fi

  /usr/bin/killall -u "$USER" cfprefsd 2>/dev/null || true

  # Relaunch everything the pre-hook quit on our behalf, unconditionally
  # (we're the one who closed them), plus the full pending list when the
  # opt-in flag is set. Dedup so an app in both lists doesn't open twice.
  relaunch=()
  if [[ -s $quit_file ]]; then
    while IFS= read -r id; do
      [[ -z $id ]] && continue
      contains "$id" "${relaunch[@]+"${relaunch[@]}"}" || relaunch+=("$id")
    done < "$quit_file"
  fi

  if [[ "${DOTFILES_RELAUNCH_AFTER_APPLY:-0}" == "1" ]]; then
    while IFS= read -r id; do
      [[ -z $id ]] && continue
      contains "$id" "${relaunch[@]+"${relaunch[@]}"}" || relaunch+=("$id")
    done < "$state_file"
  fi

  for id in "${relaunch[@]+"${relaunch[@]}"}"; do
    /usr/bin/open -b "$id" 2>/dev/null || true
  done

  rm -f "$state_file" "$quit_file"
  ;;
*)
  printf 'plist-hooks.sh: unknown mode %q (expected pre or post)\n' "$mode" >&2
  exit 1
  ;;
esac
