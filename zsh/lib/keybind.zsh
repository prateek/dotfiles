#!/usr/bin/env zsh
# vim:syntax=sh
# vim:filetype=sh

# map ctrl-space to accept auto-completion suggestions.
bindkey '^ ' autosuggest-accept

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

# TODO: rerurn last command and page output using the bat help pager
# rerun-last-command-with-bat() {
#   bathelp='bat --plain --language=help'
#   $history[$((HISTCMD-1))]
# }