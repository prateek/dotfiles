#!/usr/bin/env zsh

export SYSTEM=$(uname -s)
export ZSHCONFIG=$DOTFILES

ZSH_INIT=${ZSHCONFIG}/init.sh
if [[ -s ${ZSH_INIT} ]]; then
    source ${ZSH_INIT}
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
export PATH="/Users/prateek/.codeium/windsurf/bin:$PATH"

# Added by Antigravity
export PATH="/Users/prateek/.antigravity/antigravity/bin:$PATH"

# pnpm
export PNPM_HOME="/Users/prateek/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

