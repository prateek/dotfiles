#!/usr/bin/env zsh
# vim:syntax=sh
# vim:filetype=sh

source_if_readable() {
  local f="$1"
  [[ -r "$f" ]] || return 1
  source "$f"
}

#-----------------------------------------------------
# Cache homebrew prefix early (before plugins need it)
#-----------------------------------------------------
if [[ -z ${HOMEBREW_PREFIX:-} ]] && command -v brew >/dev/null 2>&1; then
    export HOMEBREW_PREFIX="$(brew --prefix)"
fi

# Prefer a consistent repo root even if DOTFILES isn't exported for some reason.
DOTFILES_ROOT="${DOTFILES:-${ZSHCONFIG:-$HOME/dotfiles}}"
ZSHCONFIG="${ZSHCONFIG:-$DOTFILES_ROOT}"

#-----------------------------------------------------
# bootstrap zinit script
#-----------------------------------------------------
if ! source_if_readable "$HOME/.zinit/bin/zinit.zsh"; then
  print -u2 "zinit not found at \$HOME/.zinit/bin/zinit.zsh (run ./bootstrap.sh to install zinit)."
  return 0 2>/dev/null || exit 0
fi

#-----------------------------------------------------
# load zinit plugins
#-----------------------------------------------------
if ! source_if_readable "$DOTFILES_ROOT/zinit-init.zsh"; then
  print -u2 "Missing $DOTFILES_ROOT/zinit-init.zsh; skipping plugin setup."
fi

#-----------------------------------------------------
# Setting autoloaded functions
#-----------------------------------------------------
zsh_fns=${ZSHCONFIG}/zsh/autoload
if [[ -d "$zsh_fns" ]]; then
    fpath=("$zsh_fns" $fpath)
    for func in "$zsh_fns"/*(N); do
        [[ -f "$func" ]] || continue
        autoload -Uz "${func:t}"
    done
fi
unset zsh_fns

#-----------------------------------------------------
# Load all utility scripts
#-----------------------------------------------------
zsh_libs=${ZSHCONFIG}/zsh/lib
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
extras=${ZSHCONFIG}/zsh/extra
if [[ -d "$extras" ]]; then
   for file in "$extras"/*.zsh(N); do
      source "$file"
   done
fi
unset extras

# Set PATH for macOS (only for interactive login shells)
if [[ -x /bin/launchctl && -o interactive && -o login ]]; then
    /bin/launchctl setenv PATH "$PATH"
fi
