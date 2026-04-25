#!/usr/bin/env zsh
# vim:syntax=sh
# vim:filetype=sh

# make key presses work a lot faster
# `man keytimeout`: The time the shell waits, in hundredths of seconds,
# for another key to be pressed when reading bound multi-character sequences.
KEYTIMEOUT=1

# Enable bracketed paste mode for better paste handling in vi-mode
autoload -Uz bracketed-paste-magic
zle -N bracketed-paste bracketed-paste-magic

# Fix paste issues in vi-mode
zstyle ':bracketed-paste-magic' active-widgets '.self-insert-unmeta'

# Zsh vi-mode has two keymaps: `vicmd` (normal/command mode) and `viins` (insert mode).
# Keep `vicmd` behaving like vim, but make `viins` behave like emacs so common Ctrl keys
# (Ctrl-W/Ctrl-K/Ctrl-A/Ctrl-E/etc) work while you're inserting.
# Note: this copies the emacs map into `viins`, so it must run *before* any custom `viins`
# bindings below (Home/End, fzf Ctrl-T, etc.) which intentionally override defaults.
bindkey -A emacs viins
bindkey -M viins $'\e' vi-cmd-mode
bindkey -M emacs $'\e' vi-cmd-mode

dotfiles-use-emacs-insert-keymap() {
  zle "$1"
  zle -K emacs
}

dotfiles-vi-insert() { dotfiles-use-emacs-insert-keymap .vi-insert }
dotfiles-vi-add-next() { dotfiles-use-emacs-insert-keymap .vi-add-next }
dotfiles-vi-add-eol() { dotfiles-use-emacs-insert-keymap .vi-add-eol }
dotfiles-vi-insert-bol() { dotfiles-use-emacs-insert-keymap .vi-insert-bol }
dotfiles-vi-open-line-above() { dotfiles-use-emacs-insert-keymap .vi-open-line-above }
dotfiles-vi-open-line-below() { dotfiles-use-emacs-insert-keymap .vi-open-line-below }
dotfiles-vi-change-eol() { dotfiles-use-emacs-insert-keymap .vi-change-eol }
dotfiles-vi-change-whole-line() { dotfiles-use-emacs-insert-keymap .vi-change-whole-line }

zle -N dotfiles-vi-insert
zle -N dotfiles-vi-add-next
zle -N dotfiles-vi-add-eol
zle -N dotfiles-vi-insert-bol
zle -N dotfiles-vi-open-line-above
zle -N dotfiles-vi-open-line-below
zle -N dotfiles-vi-change-eol
zle -N dotfiles-vi-change-whole-line

bindkey -M vicmd i dotfiles-vi-insert
bindkey -M vicmd a dotfiles-vi-add-next
bindkey -M vicmd A dotfiles-vi-add-eol
bindkey -M vicmd I dotfiles-vi-insert-bol
bindkey -M vicmd o dotfiles-vi-open-line-below
bindkey -M vicmd O dotfiles-vi-open-line-above
bindkey -M vicmd C dotfiles-vi-change-eol
bindkey -M vicmd S dotfiles-vi-change-whole-line

# Make word-wise editing behave like shell token editing instead of zsh's
# default "word chars include punctuation" behavior. This affects Alt+Backspace,
# Alt+Arrow, and other word widgets around paths and flags.
autoload -Uz select-word-style
select-word-style shell

bind_if_sequence() {
  local keymap="$1"
  local sequence="$2"
  local widget="$3"
  [[ -n "$sequence" ]] || return 0
  bindkey -M "$keymap" "$sequence" "$widget"
}

# map ctrl-space to accept auto-suggestions.
# color map: https://upload.wikimedia.org/wikipedia/commons/1/15/Xterm_256color_chart.svg
# usable attributes: https://zsh.sourceforge.io/Doc/Release/Zsh-Line-Editor.html#Character-Highlighting
# export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=252,standout"
# bindkey '^ ' autosuggest-accept # toggle on ctrl-space

# Who doesn't want home and end to work?
zmodload zsh/terminfo 2>/dev/null || true
typeset -g __dotfiles_key_home=''
typeset -g __dotfiles_key_end=''
if (( ${+key} )); then
  __dotfiles_key_home="${key[Home]-}"
  __dotfiles_key_end="${key[End]-}"
fi
bind_if_sequence viins "${terminfo[khome]-$__dotfiles_key_home}" beginning-of-line
bind_if_sequence viins "${terminfo[kend]-$__dotfiles_key_end}" end-of-line
bind_if_sequence emacs "${terminfo[khome]-$__dotfiles_key_home}" beginning-of-line
bind_if_sequence emacs "${terminfo[kend]-$__dotfiles_key_end}" end-of-line
unset __dotfiles_key_home __dotfiles_key_end

# ensure alt+arrow keys work
bindkey -M viins "^[^[[D" backward-word
bindkey -M viins "^[^[[C" forward-word
bindkey -M emacs "^[^[[D" backward-word
bindkey -M emacs "^[^[[C" forward-word

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
bindkey -M emacs "^P" insert-last-command-output

# ctrl-u in vi-cmd mode invokes the url_select autoload function
zle -N url_select
bindkey -M vicmd "^u" url_select

# TODO: rerurn last command and page output using the bat help pager
# rerun-last-command-with-bat() {
#   bathelp='bat --plain --language=help'
#   $history[$((HISTCMD-1))]
# }
