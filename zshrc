# Profile ZSH: https://github.com/zsh-users/zsh-syntax-highlighting/issues/31#issuecomment-4310722
# u
# Begining:
# zmodload zsh/zprof
# End:
# zprof

# PATH(s)
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.7.0_80.jdk/Contents/Home
export GOPATH=/Users/prungta/code/gocode
export GOROOT=/usr/local/opt/go/libexec
export PATH=$JAVA_HOME/bin:$HOME/bin:/usr/local/bin:$GOPATH/bin:$PATH
export EDITOR="vim"


if [ -d $HOME/dotfiles ]; then
  export DOTFILES=$HOME/dotfiles
else
  export DOTFILES=$HOME
fi
fpath=( "$DOTFILES/zsh-plugins/zfunctions" "$DOTFILES/zsh-plugins/completions" $fpath )

# uber-start
# source ~/.profile_corp
export UBER_HOME="$HOME/Uber"
export UBER_OWNER="rungta@uber.com"
export UBER_LDAP_UID=rungta
# uber-end

# zplug (zsh plugin manager)
# export ZPLUG_HOME=/usr/local/opt/zplug # $(brew --prefix zplug)
# source $ZPLUG_HOME/init.zsh
# zplug mafredri/zsh-async, from:github, defer:2
# zplug sindresorhus/pure, use:pure.zsh, from:github, as:theme, defer:2
# # startup
# # Install plugins if there are plugins that have not been installed
# # NOTE: The lines below are un-commented to speedup startup. `zplug install` manually when you change packages
# # if ! zplug check --verbose; then
# #     printf "Install? [y/N]: "
# #     if read -q; then
# #         echo; zplug install
# #     fi
# # fi
# # Then, source plugins and add commands to $PATH
# zplug load

# Locale Settings
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# docker aliases
# alias d=docker
# alias dc=docker-compose

# hub alias
eval "$(hub alias -s)"

# Maven repo setup
export M2_REPO=$HOME/.m2/repository

# ipython
# alias ip='ipython qtconsole --pylab=inline'
# alias ipn="ipython notebook $HOME/trash/notebooks"
#export PYTHONPATH=/usr/local/lib/python2.7/site-packages:

# enable color support of ls and also add handy aliases
## colorize ls
if [ -x /usr/local/bin/gdircolors ]  && [ -s $HOME/.dir_colors ]; then
  eval `gdircolors $HOME/.dir_colors`
  alias ls='/usr/local/bin/gls --color=auto'
  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi
alias ls='ls -G'
alias ll='ls -ltrG'

# aliases
alias quit='exit'
alias vimd='vim -d'
alias psef='ps -ef | grep -i '

# History options
HISTFILE=$HOME/.zhistory      # enable history saving on shell exit
HISTSIZE=10000                # lines of history to maintain memory
SAVEHIST=100000               # lines of history to maintain in history file.
setopt APPEND_HISTORY         # append rather than overwrite history file.
setopt EXTENDED_HISTORY       # Save the time and how long a command ran
setopt HIST_EXPIRE_DUPS_FIRST # allow dups, but expire old ones when I hit HISTSIZE
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS   # Even if there are commands inbetween commands that are the same, still only save the last one
setopt HIST_IGNORE_DUPS       # If I type cd and then cd again, only save the last one
setopt HIST_IGNORE_SPACE      # If a line starts with a space, don't save it.
setopt HIST_NO_STORE          # If a line starts with a space, don't save it.
setopt HIST_REDUCE_BLANKS     # Pretty    Obvious.  Right?
setopt HIST_SAVE_NO_DUPS
setopt HIST_VERIFY            # When using a hist thing, make a newline show the change before executing it.
setopt INC_APPEND_HISTORY     # Write after each command

# bindings
bindkey -v # Vim bindings for zsh
# zsh key timeout
export KEYTIMEOUT=0.5

# need to start using caps instead of jj
# bindkey -Mviins 'ii' vi-cmd-mode # jj map to esc

# Who doesn't want home and end to work?
bindkey '\e[1~' beginning-of-line
bindkey '\e[4~' end-of-line

# Incremental search is elite!
bindkey -M vicmd "/" history-incremental-search-backward
bindkey -M vicmd "?" history-incremental-search-forward
bindkey -M viins '^R' history-incremental-pattern-search-backward
bindkey -M viins '^F' history-incremental-pattern-search-forward

# Search based on what you typed in already
bindkey -M vicmd "//" history-beginning-search-backward
bindkey -M vicmd "??" history-beginning-search-forward

bindkey -M vicmd "q" push-line   # copy buffer to stack and clear, reload it next tiem editor starts up
bindkey -M viins ' ' magic-space # it's like, space AND completion.  Gnarlbot.
bindkey -M vicmd '!' edit-command-output
bindkey -M vicmd 'v' edit-command-line
bindkey -M vicmd 'u' undo

# Ensure that arrow keys work as they should
bindkey '\e[A' up-line-or-history
bindkey '\e[B' down-line-or-history
bindkey '\eOA' up-line-or-history
bindkey '\eOB' down-line-or-history
bindkey '\e[C' forward-char
bindkey '\e[D' backward-char
bindkey '\eOC' forward-char
bindkey '\eOD' backward-char
bindkey "^?" backward-delete-char

# vim editing for commands
autoload -z edit-command-line
zle -N edit-command-line

autoload -z edit-command-output
zle -N edit-command-output

autoload -Uz copy-earlier-word
zle -N copy-earlier-word

# zsh completion
# setopt correctall
zstyle ':completion:*' menu select
compctl -g '*(/)' rmdir dircmp j
compctl -g '*(-/)' cd chdir dirs pushd j

## colorize completions
zstyle ':completion:*' list-colors ''
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

# Zaw Configs
source $DOTFILES/zsh-plugins/zaw/zaw.zsh
bindkey -M filterselect '^R' down-line-or-history
bindkey -M filterselect '^S' up-line-or-history
bindkey -M filterselect '^E' accept-search
zstyle ':filter-select:highlight' selected bg=red
zstyle ':filter-select:highlight' matched fg=yellow,standout
zstyle ':filter-select' rotate-list yes
zstyle ':filter-select' case-insensitive yes
zstyle ':filter-select' extended-search yes
bindkey '^R' zaw-history

autoload -U promptinit && promptinit
prompt pure
autoload -U compinit && compinit

setopt nolistambiguous # one tab for completion
setopt MULTIOS         # tee/cat automatically

# convenient stuff
# autoload zmv
# setopt autocd
setopt extendedglob

# autoexapnd aliases
setopt no_complete_aliases

# no beeps
setopt NO_BEEP

# zsh modification aliases
alias sz='source ~/.zshrc'
alias ez='vim ~/.zshrc'

# copy with a progress bar
alias cpv="rsync -poghb --backup-dir=/tmp/rsync -e /dev/null --progress --"

# tmux color
alias tmux="TERM=screen-256color-bce tmux -2"
alias ta='tmux attach -t'
alias ts='tmux new-session -s'
alias tl='tmux list-sessions'

# Neovim
# alias vim="nvim"

# scmpuff
eval "$(scmpuff init -s)"
alias gt="git tag"
alias gb="git branch"
alias gca="git commit -a"
alias gl="git lg"
alias gco="git checkout --recurse-submodules"
# git worktree (tutorial: https://stacktoheap.com/blog/2016/01/19/using-multiple-worktrees-with-git/)
alias gwa='git worktree add'
alias gwp='git worktree prune'
alias gwl='git worktree list'
# adapted from: http://stackoverflow.com/questions/14031970/git-push-current-branch-shortcut
function gpb()
{
    if git rev-parse --abbrev-ref --symbolic-full-name @{u} > /dev/null 2>&1; then
        git push origin HEAD
    else
        git push -u origin HEAD
    fi
}

# convenience
alias l="| less"
alias v="| vim"
alias eclimd="/Applications/eclipse/eclimd"
alias yoink="open -a Yoink"

export PIP_REQUIRE_VIRTUALENV=true
# define a "global pip" function to use outside virtualenv:
gpip(){
    PIP_REQUIRE_VIRTUALENV="" pip "$@"
}

init_pyenv(){
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
}

# rbenv
# eval "$(rbenv init -)"

# npm, nodejs
# via: http://stackoverflow.com/questions/28017374/what-is-the-suggested-way-to-install-brew-node-js-io-js-nvm-npm-on-os-x
# export NVM_DIR=~/.nvm
# alias nvms="source $(brew --prefix nvm)/nvm.sh"

# WIP quick git commit
alias wip='git commit -am "WIP"'

# go-test-all
# from http://stackoverflow.com/questions/16353016/how-to-go-test-all-testings-in-my-project
alias gotestall='go test $(go list ./... | grep -v /vendor/)'
add_licence(){
  go list ./... | grep -v /vendor/ | xargs -I{} sh -c "cd $GOPATH/src/{} && uber-licence --file *.go"
}

# autojump sourcing
source /usr/local/etc/profile.d/autojump.sh

diff_statsdex_configs()
{
  set -e # paranoia, ftw

  if [ -z "$1" ]; then
    echo "usage: diff_statsdex_configs <branch>"
    return 0
  fi
  local branch=$1

  cd ~/code/gocode/src/code.uber.internal/infra/statsdex

  source ./udeploy/cfg_clusters.sh
  temp_dir=$(mktemp -d)
  echo "temp dir: ${temp_dir}"

  git checkout master
  echo "making master"
  make clean
  for c in $(echo $CFG_CLUSTERS | tr ' ' '\n'); do echo $c ; CLUSTER=$c make build-all-config ; done
  echo "moving ./out/ to ${temp_dir}/out-master"
  mv ./out ${temp_dir}/out-master

  git checkout ${branch}
  echo "making ${branch}"
  make clean
  for c in $(echo $CFG_CLUSTERS | tr ' ' '\n'); do echo $c ; CLUSTER=$c make build-all-config ; done
  echo "moving ./out/ to ${temp_dir}/out-branch"
  mv ./out ${temp_dir}/out-branch

  echo "configs created"
  echo "suggested diffs to look at: "
  echo "  vim -d ${temp_dir}/out-master ${temp_dir}/out-branch"
  echo "  diff -rq ${temp_dir}/out-master ${temp_dir}/out-branch"

  echo "remember to cleanup dir: ${temp_dir} once you're done diffing"
}

# zprof
