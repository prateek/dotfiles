# shellcheck shell=zsh
#
# Source registry. Keep this in sync with bin/sources/<name> scripts.
#
# Each entry maps a source name to:
#   verb           — the noun used in the formatted row (`outdated` / `drifted`)
#   ttl_var        — env-var name holding the per-source refresh TTL
#   enabled_var    — env-var name holding the per-source enable flag
#   binary         — the underlying binary the check requires (used to detect
#                    "disabled: not installed" before invoking the script)
#   params_var     — optional env-var name whose value is folded into the
#                    cache params token (so changing it invalidates the cache)

typeset -gA BANNER_SOURCE_VERB=(
  chezmoi  drifted
  brew     outdated
  mise     outdated
  apm      outdated
)

typeset -gA BANNER_SOURCE_TTL_VAR=(
  chezmoi  DOTFILES_BANNER_CHEZMOI_REFRESH_TTL_SECONDS
  brew     DOTFILES_BANNER_BREW_REFRESH_TTL_SECONDS
  mise     DOTFILES_BANNER_MISE_REFRESH_TTL_SECONDS
  apm      DOTFILES_BANNER_APM_REFRESH_TTL_SECONDS
)

typeset -gA BANNER_SOURCE_ENABLED_VAR=(
  chezmoi  DOTFILES_BANNER_CHEZMOI_ENABLED
  brew     DOTFILES_BANNER_BREW_ENABLED
  mise     DOTFILES_BANNER_MISE_ENABLED
  apm      DOTFILES_BANNER_APM_ENABLED
)

typeset -gA BANNER_SOURCE_BINARY=(
  chezmoi  chezmoi
  brew     brew
  mise     mise
  apm      apm
)

typeset -gA BANNER_SOURCE_PARAMS_VAR=(
  chezmoi  DOTFILES_BANNER_CHEZMOI_SCOPE
  brew     ''
  mise     ''
  apm      ''
)

banner_known_source() {
  local source="$1"
  [[ -n "${BANNER_SOURCE_VERB[$source]:-}" ]]
}

banner_enabled_sources() {
  local raw="${DOTFILES_BANNER_SOURCES:-chezmoi,brew,mise}"
  local -a wanted
  wanted=(${(s:,:)raw})

  local source enabled_var enabled
  for source in "${wanted[@]}"; do
    source="${source// /}"
    [[ -n "$source" ]] || continue
    banner_known_source "$source" || continue
    enabled_var="${BANNER_SOURCE_ENABLED_VAR[$source]}"
    enabled="${(P)enabled_var:-1}"
    [[ "$enabled" == 1 ]] || continue
    print -r -- "$source"
  done
}

banner_source_enabled() {
  local wanted="$1" source
  [[ "${DOTFILES_BANNER_ENABLED:-1}" == 1 ]] || return 1
  while IFS= read -r source; do
    [[ "$source" == "$wanted" ]] && return 0
  done < <(banner_enabled_sources)
  return 1
}

banner_source_ttl() {
  local source="$1"
  local var="${BANNER_SOURCE_TTL_VAR[$source]:-}"
  [[ -n "$var" ]] || { print -r -- 3600; return 0; }
  print -r -- "${(P)var:-3600}"
}

banner_source_params() {
  local source="$1"
  [[ "$source" == (brew|mise|apm) ]] && { print -r -- scope=dotpkgs-v1; return 0; }
  local var="${BANNER_SOURCE_PARAMS_VAR[$source]:-}"
  [[ -n "$var" ]] || { print -r -- ''; return 0; }
  local value="${(P)var:-}"
  # Self-describing token so a stored params value can be compared without
  # ambiguity (e.g. chezmoi -> "scope=files" vs "scope=apply").
  case "$source" in
    chezmoi) print -r -- "scope=${value}" ;;
    *)       print -r -- "$value" ;;
  esac
}

banner_source_binary() {
  local source="$1"
  print -r -- "${BANNER_SOURCE_BINARY[$source]:-$source}"
}

banner_source_verb() {
  local source="$1"
  print -r -- "${BANNER_SOURCE_VERB[$source]:-outdated}"
}
