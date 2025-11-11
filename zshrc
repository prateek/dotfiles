#!/usr/bin/env zsh
# vim:syntax=zsh
# vim:filetype=zsh

export SYSTEM=$(uname -s)
export ZSHCONFIG=$DOTFILES

ZSH_INIT=${ZSHCONFIG}/init.sh
if [[ -s ${ZSH_INIT} ]]; then
    source ${ZSH_INIT}
else
    echo "Could not find the init script ${ZSH_INIT}"
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