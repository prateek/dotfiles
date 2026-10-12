# shellcheck shell=zsh
#
# Run the whole adapter inside a subshell so any sourced helpers
# (banner_*, BANNER_*, DOTFILES_BANNER_*) die when the subshell exits and
# never pollute the user's interactive shell.

(
  emulate -L zsh
  setopt no_nomatch typeset_silent

  [[ -o interactive ]] || exit 0
  [[ -t 1 ]] || exit 0
  [[ -n "${TERM:-}" && "${TERM:-}" != dumb ]] || exit 0
  [[ -z "${SSH_TTY:-}${SSH_CONNECTION:-}" ]] || exit 0

  root="${DOTFILES_BANNER_ROOT:-${${(%):-%x}:A:h:h}}"
  [[ -r "$root/lib/cache.sh"   ]] || exit 0
  [[ -r "$root/lib/sources.sh" ]] || exit 0
  source "$root/lib/cache.sh"
  source "$root/lib/sources.sh"

  banner_load_config "$root"
  [[ -r "$root/local.env" ]] && banner_load_local_config "$root/local.env"
  [[ "${DOTFILES_BANNER_ENABLED:-1}" == 1 ]] || exit 0

  fastfetch_bin="${DOTFILES_BANNER_FASTFETCH_BIN:-fastfetch}"
  config="${DOTFILES_BANNER_FASTFETCH_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/config.jsonc}"
  refresh_bin="$root/bin/refresh"

  if whence -p "$fastfetch_bin" >/dev/null 2>&1 && [[ -r "$config" ]]; then
    "$fastfetch_bin" --config "$config" 2>/dev/null || true
  else
    print -r -- 'shell-banner: fastfetch not installed yet (run `brew install fastfetch`).'
  fi

  if [[ -x "$refresh_bin" ]]; then
    "$refresh_bin" --if-stale </dev/null >/dev/null 2>&1 &!
  fi
)
