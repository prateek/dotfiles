#!/usr/bin/env zsh
# vim:syntax=sh
# vim:filetype=sh

# map ctrl-space to accept auto-suggestions.
# color map: https://upload.wikimedia.org/wikipedia/commons/1/15/Xterm_256color_chart.svg
# usable attributes: https://zsh.sourceforge.io/Doc/Release/Zsh-Line-Editor.html#Character-Highlighting
# export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=252,standout"
# bindkey '^ ' autosuggest-accept # toggle on ctrl-space

# Who doesn't want home and end to work?
bindkey -M viins "${key[Home]}" beginning-of-line
bindkey -M viins "${key[End]}" end-of-line

# ensure alt+arrow keys work
bindkey "^[^[[D" backward-word
bindkey "^[^[[C" forward-word

# copy buffer to stack and clear, reload it next time editor starts up
bindkey -M vicmd 'q' push-line

# vim editing for command line
autoload -z edit-command-line
zle -N edit-command-line
bindkey -M vicmd 'v' edit-command-line

# rerun last command & insert output into current buffer
zmodload -i zsh/parameter
insert-last-command-output() {
  LBUFFER+="$(eval $history[$((HISTCMD-1))])"
}
zle -N insert-last-command-output
bindkey -M viins "^P" insert-last-command-output

# ctrl-u in vi-cmd mode invokes the url_select autoload function
zle -N url_select
bindkey -M vicmd "^u" url_select

# TODO: rerurn last command and page output using the bat help pager
# rerun-last-command-with-bat() {
#   bathelp='bat --plain --language=help'
#   $history[$((HISTCMD-1))]
# }