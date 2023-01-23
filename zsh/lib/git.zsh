#!/usr/bin/env zsh
# vim:syntax=sh
# vim:filetype=sh

# git aliases + scmpuff
eval "$(scmpuff init -s)"
alias gt="git tag"
alias gb="git branch"
alias gca="git commit -a"
alias gl="git lg"
alias gco="git checkout"

# adapted from: http://stackoverflow.com/questions/14031970/git-push-current-branch-shortcut
function gpb()
{
    if git rev-parse --abbrev-ref --symbolic-full-name @{u} > /dev/null 2>&1; then
        git push origin HEAD
    else
        git push -u origin HEAD
    fi
}
