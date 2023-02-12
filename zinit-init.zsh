#!/usr/bin/env zsh
# vim:syntax=sh
# vim:filetype=sh

# https://zdharma-continuum.github.io/zinit/wiki/GALLERY/

# fzf pack via zinit
# https://zdharma-continuum.github.io/zinit/wiki/Zinit-Packages/
zinit pack for fzf

# zinit ice wait"0" atload"_zsh_autosuggest_start" lucid
# zinit light zsh-users/zsh-autosuggestions

zinit ice wait"0" lucid
zinit light zsh-users/zsh-completions

zinit ice wait"0" atinit"zpcompinit; zpcdreplay" lucid
zinit light zdharma-continuum/fast-syntax-highlighting

zinit from"gh-r" as"program" mv"direnv* -> direnv"          \
    atclone'./direnv hook zsh > zhook.zsh' atpull'%atclone' \
    pick"direnv" src="zhook.zsh" for direnv/direnv

# Load the pure theme, with zsh-async library that's bundled with it
zinit ice pick"async.zsh" src"pure.zsh" lucid
zinit light sindresorhus/pure

# way better vim motions
zinit ice wait"0" lucid
zinit light zsh-vi-more/vi-motions
