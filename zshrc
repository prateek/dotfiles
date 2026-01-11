#!/usr/bin/env zsh

export SYSTEM=$(uname -s)
export DOTFILES="${DOTFILES:-$HOME/dotfiles}"
export ZSHCONFIG="${ZSHCONFIG:-$DOTFILES}"

# Allow `#` comments in interactive shells.
setopt interactivecomments

# Globs: keep zsh's strict default (`nomatch`) so typos fail fast.
#
# Why: Unmatched patterns like `rm *.tmp` should error if there are no matches,
# rather than silently passing a literal `*.tmp` or expanding to nothing.
#
# Risk: This can feel "not bash-like" and can be annoying when you intentionally
# want a glob to be optional or you want to pass a literal pattern through.
#
# Idiomatic escape hatch: use zsh's `(N)` qualifier for optional globs, e.g.
#   ls *.log(N)
# or
#   for f in ~/.config/*.json(N); do ...; done
#
# Reconsider switching away from `nomatch` if you routinely run commands with
# globs where "no files is fine" and you keep hitting `no matches found`.
# Alternatives:
# - `unsetopt nomatch`  (bash-like: unmatched globs stay literal)
# - `setopt nullglob`   (unmatched globs disappear; can be risky globally)
setopt nomatch

ZSH_INIT="${ZSHCONFIG}/init.sh"
if [[ -s "${ZSH_INIT}" ]]; then
    source "${ZSH_INIT}"
else
    echo "Could not find the init script ${ZSH_INIT}"
fi

# Prefer Neovim when invoking vim
if command -v nvim >/dev/null 2>&1; then
  alias vim='nvim'
fi

# Compinit optimization - only regenerate dump once per day
# https://gist.github.com/ctechols/ca1035271ad134841284
# https://carlosbecker.com/posts/speeding-up-zsh
#
# Note: This is now handled by zinit with zpcompinit in zinit-init.zsh
# Commenting out to avoid duplicate initialization
#
# autoload -Uz compinit
# case $SYSTEM in
#   Darwin)
#     if [ $(date +'%j') != $(/usr/bin/stat -f '%Sm' -t '%j' ${ZDOTDIR:-$HOME}/.zcompdump) ]; then
#       compinit;
#     else
#       compinit -C;
#     fi
#     ;;
#   Linux)
#     # not yet match GNU & BSD stat
#   ;;
# esac

# Source local rc overlay if present (work configs)
if [ -f "$HOME/.zshrc.local" ]; then
  source "$HOME/.zshrc.local"
fi

# Added by Windsurf
export PATH="$HOME/.codeium/windsurf/bin:$PATH"

# Added by Antigravity
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
