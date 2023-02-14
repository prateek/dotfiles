#!/usr/bin/env zsh
# vim:syntax=sh
# vim:filetype=sh

# git aliases
alias gs='autoload_scmpuff_status'
alias ga="git add"
alias gd="git diff"
alias gb="git branch"
alias gca="git commit -a"
alias gl="git lg"
alias gco="git checkout"
alias gp='git pull origin $(git rev-parse --abbrev-ref HEAD)'
alias gpo='git pull origin $(git rev-parse --abbrev-ref HEAD)'
alias push='git push origin $(git rev-parse --abbrev-ref HEAD)'
alias pull='git pull'
alias grim='git rebase -i master'

# # adapted from: http://stackoverflow.com/questions/14031970/git-push-current-branch-shortcut
# function gpb()
# {
#     if git rev-parse --abbrev-ref --symbolic-full-name @{u} > /dev/null 2>&1; then
#         git push origin HEAD
#     else
#         git push -u origin HEAD
#     fi
# }

alias jls="jira issue list"
# FIXME: alias ssh=sshrc

# Aliases
alias ls='ls -G'
alias ll='ls -ltrG'
alias vimd='vim -d'
alias psef='ps -ef | grep -i'
alias ps='ps -T'
alias cat='bat --style=plain'
alias grep='egrep --color=auto'
alias egrep='egrep --color=auto'

## zshrc modification aliases
alias sz='exec zsh'
alias ez='code ~/dotfiles'
alias jz='cd ~/dotfiles'

# FIXME: Pipe Aliases
# alias L=' | less '
# alias G=' | egrep --color=auto '
# alias T=' | tail '
# alias H=' | head '
# alias W=' | wc -l '
# alias S=' | sort '