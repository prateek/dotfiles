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
alias pushf='git push origin $(git rev-parse --abbrev-ref HEAD) --force'
alias pull='git pull'
alias grim='git rebase -i $(git symbolic-ref refs/remotes/origin/HEAD | sed "s@^refs/remotes/origin/@@")'
alias grimb='BASE=$(git symbolic-ref refs/remotes/origin/HEAD | sed "s@^refs/remotes/origin/@@") && git rebase -i $(git merge-base $BASE HEAD)'

# use fzf to autocomplete git branches
gcf() {
    git checkout $(git branch | fzf)
}

# use fzf to delete branches, allow multiple selections
gbd() {
    # use TAB/S-TAB to select multiple branches
    git branch -D $(git branch | fzf -m)
}

# adapted from https://github.com/Phantas0s/.dotfiles/blob/master/zsh/scripts_fzf.zsh
# git log browser with FZF
fgl() {
  git log --graph --color=always \
      --format="%C(auto)%h%d %s %C(black)%C(bold)%cr" "$@" |
  fzf --ansi --no-sort --reverse --tiebreak=index --bind=ctrl-s:toggle-sort \
      --bind "ctrl-m:execute:
                (grep -o '[a-f0-9]\{7\}' | head -1 |
                xargs -I % sh -c 'git show --color=always % | less -R') << 'FZF-EOF'
                {}
FZF-EOF"
}

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