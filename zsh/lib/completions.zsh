#!/usr/bin/env zsh
# vim:syntax=zsh
# vim:filetype=zsh

################################################################################
# https://github.com/sorin-ionescu/prezto/blob/master/modules/completion/init.zsh
# https://github.com/robbyrussell/oh-my-zsh/blob/master/lib/completion.zsh
# https://github.com/zimfw/zimfw/blob/master/modules/completion/init.zsh
# https://grml.org/zsh/zsh-lovers.html
################################################################################

unsetopt menu_complete     # do not autoselect the first completion entry
unsetopt flow_control      # disable start/stop characters in shell editor
unsetopt case_glob         # makes globbing (filename generation) case-sensitive

setopt no_beep             # no beeps
setopt multios             # tee/cat automatically
setopt always_to_end       # move cursor to the end of a completed word
setopt auto_menu           # show completion menu on a successive tab press
setopt complete_in_word    # complete from both ends of a word
setopt no_complete_aliases # autoexapnd aliases
setopt nolistambiguous     # one tab for completion

# zsh completion
zstyle ':completion:*' menu select
compctl -g '*(/)' rmdir dircmp j
compctl -g '*(-/)' cd chdir dirs pushd j

## colorize completions
zstyle ':completion:*' list-colors ''
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

# [ -f ~/.fzf-tab/fzf-tab.plugin.zsh ] && source ~/.fzf-tab/fzf-tab.plugin.zsh
# zstyle ':fzf-tab:*' continuous-trigger '/'
# zstyle ':fzf-tab:*' fzf-bindings 'ctrl-e:accept'
# zstyle ':fzf-tab:*' accept-line enter

# Aliases
alias ls='ls -G'
alias ll='ls -ltrG'
alias vimd='vim -d'
alias psef='ps -ef | grep -i'
alias ps='ps -T'
alias cat='bat --style=plain'
alias grep='egrep --color=auto'
alias egrep='egrep --color=auto'

## git aliases
alias pull='git pull'
alias gp='git pull origin $(git rev-parse --abbrev-ref HEAD)'
alias gpo='git pull origin $(git rev-parse --abbrev-ref HEAD)'
alias push='git push origin $(git rev-parse --abbrev-ref HEAD)'

## zshrc modification aliases
alias sz='exec zsh'
alias ez='code ~/.zshrc'
alias jz='cd ~/dotfiles'

# FIXME: Pipe Aliases
# alias L=' | less '
# alias G=' | egrep --color=auto '
# alias T=' | tail '
# alias H=' | head '
# alias W=' | wc -l '
# alias S=' | sort '
#
# globalias() {
#    if [[ $LBUFFER =~ ' [A-Z0-9]+$' ]]; then
#      zle _expand_alias
#      zle expand-word
#    fi
#    zle self-insert
# }
#
# zle -N globalias
#
# bindkey " " globalias
# bindkey "^ " magic-space           # control-space to bypass completion
# bindkey -M isearch " " magic-space # normal space during searches