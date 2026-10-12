# shellcheck shell=zsh

banner_packages_check() {
  local manager="$1" helper="${DOTFILES_BANNER_DOTPKGS_BIN:-$HOME/.local/bin/dotpkgs}"
  if [[ ! -x "$helper" ]]; then
    BANNER_SOURCE_DISABLED_REASON='dotpkgs not installed'
    return 1
  fi
  local output error_file rc=0 counts pinned unknown
  error_file="$(banner_mktemp banner-dotpkgs)" || return 2
  output="$(DOTPKGS_BREW_BIN="${DOTFILES_BANNER_BREW_BIN:-brew}" \
    DOTPKGS_MISE_BIN="${DOTFILES_BANNER_MISE_BIN:-mise}" \
    "$helper" summary --manager "$manager" 2>"$error_file")" || rc=$?
  if (( rc != 0 )); then
    if (( rc == 3 )); then
      BANNER_SOURCE_DISABLED_REASON="$(<"$error_file")"
      /bin/rm -f "$error_file"
      return 1
    fi
    BANNER_SOURCE_ERROR="dotpkgs $manager: $(<"$error_file")"
    /bin/rm -f "$error_file"
    return 2
  fi
  /bin/rm -f "$error_file"
  counts="${output%%$'\n'*}"
  IFS=$'\t' read -r BANNER_SOURCE_OUTDATED BANNER_SOURCE_TOTAL pinned unknown <<< "$counts"
  if ! banner_is_uint "$BANNER_SOURCE_OUTDATED" || ! banner_is_uint "$BANNER_SOURCE_TOTAL" \
      || ! banner_is_uint "$pinned" || ! banner_is_uint "$unknown"; then
    BANNER_SOURCE_ERROR='invalid dotpkgs summary'
    return 2
  fi
  BANNER_SOURCE_RAW="${output#*$'\n'}"
  BANNER_SOURCE_DETAIL=''
  (( pinned > 0 )) && BANNER_SOURCE_DETAIL+=" · $pinned pinned"
  (( unknown > 0 )) && BANNER_SOURCE_DETAIL+=" · $unknown unknown"
  return 0
}
