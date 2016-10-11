#!/usr/local/bin/zsh

bindkey -M filterselect '^R' down-line-or-history
bindkey -M filterselect '^S' up-line-or-history
bindkey -M filterselect '^E' accept-search
zstyle ':filter-select:highlight' selected bg=red
zstyle ':filter-select:highlight' matched fg=yellow,standout
zstyle ':filter-select' rotate-list yes
zstyle ':filter-select' case-insensitive yes
zstyle ':filter-select' extended-search yes
