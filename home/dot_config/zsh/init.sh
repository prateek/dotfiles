#!/usr/bin/env zsh
# vim:syntax=sh
# vim:filetype=sh

source_if_readable() {
  local f="$1"
  [[ -r "$f" ]] || return 1
  source "$f"
}

keep_home_bin_first() {
  if [[ -d "$HOME/bin" ]]; then
    path=("$HOME/bin" ${path:#"$HOME/bin"})
  fi
}

sync_launchctl_path() {
  local launchctl_path=""

  launchctl_path="$(/bin/launchctl getenv PATH 2>/dev/null || true)"
  if [[ "$launchctl_path" == "$PATH" ]]; then
    return 0
  fi

  /bin/launchctl setenv PATH "$PATH"
}

# Prefer a consistent source root even if DOTFILES isn't exported for some reason.
DOTFILES_ROOT="${DOTFILES:-$HOME/dotfiles}"
ZSHCONFIG="${ZSHCONFIG:-${ZDOTDIR:-${XDG_CONFIG_HOME:-$HOME/.config}/zsh}}"
ZINIT_HOME="${ZINIT_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git}"

#-----------------------------------------------------
# bootstrap zinit script
#-----------------------------------------------------
if ! source_if_readable "$ZINIT_HOME/zinit.zsh"; then
  if ! source_if_readable "$HOME/.zinit/bin/zinit.zsh"; then
    print -u2 "zinit not found at $ZINIT_HOME/zinit.zsh (run dotfiles apply chezmoi)."
    return 0 2>/dev/null || exit 0
  fi
fi

#-----------------------------------------------------
# Setting autoloaded functions
#-----------------------------------------------------
zsh_fns=${ZSHCONFIG}/autoload
if [[ -d "$zsh_fns" ]]; then
    fpath=("$zsh_fns" $fpath)
    for func in "$zsh_fns"/*(N); do
        [[ -f "$func" ]] || continue
        autoload -Uz "${func:t}"
    done
fi
unset zsh_fns

#-----------------------------------------------------
# load zinit plugins
#-----------------------------------------------------
if ! source_if_readable "$ZSHCONFIG/zinit-init.zsh"; then
  print -u2 "Missing $ZSHCONFIG/zinit-init.zsh; skipping plugin setup."
fi

#-----------------------------------------------------
# Load all utility scripts
#-----------------------------------------------------
zsh_libs=${ZSHCONFIG}/lib
if [[ -d "$zsh_libs" ]]; then
   for file in "$zsh_libs"/*.zsh(N); do
      source "$file"
   done
fi
unset zsh_libs

#-----------------------------------------------------
# Load all extras from ${ZSHCONFIG}/extra/*.zsh
# NB: these are to be loaded after everything else,
# as they overwrite behaviour of stuff.
#-----------------------------------------------------
extras=${ZSHCONFIG}/extra
if [[ -d "$extras" ]]; then
   for file in "$extras"/*.zsh(N); do
      source "$file"
   done
fi
unset extras

# Keep ~/bin first even if plugin setup prepends helper bins later.
keep_home_bin_first
typeset -ga precmd_functions
precmd_functions=("${(@)precmd_functions:#keep_home_bin_first}")
precmd_functions+=(keep_home_bin_first)

# Set PATH for macOS (only for interactive login shells)
if [[ -z ${DOTFILES_SKIP_LAUNCHCTL_SYNC:-} && -x /bin/launchctl && -o interactive && -o login ]]; then
    sync_launchctl_path
fi
