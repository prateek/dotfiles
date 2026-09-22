# shellcheck shell=bash

touchid_sudo_payload() {
  printf '%s\n' \
    '# Managed by chezmoi (prateek/dotfiles): home/.chezmoitemplates/touchid_sudo.sh' \
    'auth       sufficient     pam_tid.so'
}

touchid_sudo_target_safe() {
  local target="$1"
  shift
  if [ -e "$target" ] || [ -L "$target" ]; then
    if [ -L "$target" ] || [ ! -f "$target" ] || ! touchid_sudo_payload | "$@" cmp -s "$target" -; then
      warn "Touch ID for sudo: $target is not the exact managed file; leaving it unchanged."
      return 1
    fi
  fi
}

# Production passes literal paths and ownership; tests use a temporary PAM directory.
touchid_sudo_reconcile() {
  local pam_dir="$1" enabled="$2" owner="$3" group="$4" module_path="$5"
  local target="$pam_dir/sudo_local"

  case "$enabled" in
    true|false) ;;
    *) die "touchid_sudo_reconcile: enabled must be true or false, got '$enabled'" ;;
  esac

  # Unreadable regular files need a privileged comparison before deciding ownership.
  if [ ! -f "$target" ] || [ -r "$target" ] || [ -L "$target" ]; then
    touchid_sudo_target_safe "$target" || return 0
  fi

  # Removal must still work when a security baseline removes the include or module.
  if [ "$enabled" = false ]; then
    if [ -e "$target" ]; then
      dotfiles_sudo_start "Disabling Touch ID for sudo needs administrator access."
      touchid_sudo_target_safe "$target" sudo || return 0
      sudo rm -f "$target" || return 1
    fi
    log "Touch ID for sudo is off."
    return 0
  fi

  if ! grep -Eq '^[[:blank:]]*auth[[:blank:]]+include[[:blank:]]+sudo_local[[:blank:]]*(#.*)?$' "$pam_dir/sudo"; then
    warn "Touch ID for sudo skipped: $pam_dir/sudo has no active sudo_local include."
    return 0
  fi
  if [ "$(stat -f '%HT %Su' "$module_path" 2>/dev/null)" != "Regular File $owner" ]; then
    warn "Touch ID for sudo skipped: $module_path must be a regular file owned by $owner."
    return 0
  fi
  if [ -r "$target" ] && [ "$(stat -f '%Su %Sg %Lp' "$target")" = "$owner $group 444" ]; then
    log "Touch ID for sudo is configured."
    return 0
  fi

  dotfiles_sudo_start "Configuring Touch ID for sudo needs administrator access."
  (
    tmp="$(mktemp)" || exit 1
    staged=""
    trap 'rm -f "$tmp"; if [ -n "$staged" ]; then sudo rm -f "$staged"; fi' EXIT
    touchid_sudo_payload >"$tmp" || exit 1
    staged="$(sudo mktemp "$pam_dir/.sudo_local.chezmoi.XXXXXX")" || exit 1
    sudo install -m 0444 -o "$owner" -g "$group" "$tmp" "$staged" || exit 1
    # Authentication and staging can outlast another administrator's edit.
    touchid_sudo_target_safe "$target" sudo || exit 0
    sudo mv -f "$staged" "$target" || exit 1
    staged=""
    log "Configured Touch ID for sudo at $target."
  )
}
