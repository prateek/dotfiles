# NB: need to run `autoload zkbd && zkbd` to setup keycode file being sourced below
# ideally, only need to run ^ once when setting up a new computer.
source ~/.zkbd/$TERM-${${DISPLAY:t}:-$VENDOR-$OSTYPE}

# as god intended
export EDITOR="vim"

# Export existing paths.
typeset -gxU path PATH
typeset -gxU fpath FPATH
typeset -gxU manpath MANPATH

# github base path (useful for `ghc`)
GHPATH=/Users/rungta/code/gocode/src/github.com
export GPATH

# Multiple installs of go using https://dave.cheney.net/2014/04/20/how-to-install-multiple-versions-of-go
GOBASE=/Users/rungta/code/go1.17.3/bin
export GOPATH=/Users/rungta/code/gocode

# PATH(s), relies on zsh magic (path == $PATH but in array form and sync'd)
path=(
  $GOBASE
  $HOME/bin
  /usr/local/{sbin,bin}
  $GOPATH/bin
  $HOME/code/FlameGraph
  $HOME/code/gocode/src/code.uber.internal/go-code/bin
  $HOME/code/gocode/src/code.uber.internal/go-code/tools
  $HOME/.cargo/bin
  /usr/{sbin,bin}
  /{sbin,bin}
  $path
)
path=($^path(N-/))

# Set the list of directories that man searches for manuals.
manpath=(
  /usr/local/man
  /usr/local/share/man
  /usr/share/man
)
manpath=($^manpath(N-/))

if [ -d $HOME/dotfiles ]; then
  export DOTFILES=$HOME/dotfiles
else
  export DOTFILES=$HOME
fi

# avoid every command forking for this
export HOMEBREW_PREFIX=$(brew --prefix)

fpath=( "$DOTFILES/zsh/completions" $fpath )

# Locale Settings
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# set the prompt to `pure`: https://github.com/sindresorhus/pure
# assumes: (1) zsh used is from brew; (2) `brew install pure` has been run
autoload -U promptinit && promptinit
prompt pure

# setup zsh so that we automatically page if output doesn't fit on screen.
# https://stackoverflow.com/questions/15453394/would-it-be-possible-to-automatically-page-the-output-in-zsh
# -F: Causes less to automatically exit if the entire file can be displayed on the first screen.
# -X: Disables sending the termcap initialization and deinitialization strings to the terminal. (stops less clearing the screen)
# -R: color it up
# -j.5: make results appear in the center of the screen (.5 = 50%)
export LESS="-FXRj.5"

# sensible zsh defaults
setopt no_complete_aliases # autoexapnd aliases
setopt NO_BEEP             # no beeps
setopt nolistambiguous     # one tab for completion
setopt MULTIOS             # tee/cat automatically

# History options
# nb: careful updating the history size - it has a
HISTFILE=$HOME/.zhistory      # enable history saving on shell exit
HISTSIZE=10000                # lines of history to maintain memory
SAVEHIST=10000                # lines of history to maintain in history file.
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

# key bindings
bindkey -v            # Vim bindings for zsh
export KEYTIMEOUT=0.3 # zsh key timeout

# Who doesn't want home and end to work?
bindkey -M viins "${key[Home]}" beginning-of-line
bindkey -M viins "${key[End]}" end-of-line

# Incremental search is elite!
bindkey '^R' history-incremental-pattern-search-backward
bindkey '^F' history-incremental-pattern-search-forward

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

# zsh completion
setopt correctall
zstyle ':completion:*' menu select
compctl -g '*(/)' rmdir dircmp j
compctl -g '*(-/)' cd chdir dirs pushd j

## colorize completions
zstyle ':completion:*' list-colors ''
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

# wire up fzf baby.
export FZF_DEFAULT_OPTS="
  --bind=ctrl-e:accept
  --cycle
  --height=40% --layout=reverse --border=none --info=hidden --margin=0% --marker='*' --history-size=${HISTSIZE}
  --color=dark
  --color=fg:-1,bg:-1,hl:#c678dd,fg+:#ffffff,bg+:#252931,hl+:#d858fe
  --color=info:#98c379,prompt:#61afef,pointer:#be5046,marker:#e5c07b,spinner:#61afef,header:#61afef
"
export FZF_CTRL_R_OPTS="--no-sort"

source $DOTFILES/zsh/fzf
[ -f ~/.fzf-tab/fzf-tab.plugin.zsh ] && source ~/.fzf-tab/fzf-tab.plugin.zsh
zstyle ':fzf-tab:*' continuous-trigger '/'
zstyle ':fzf-tab:*' fzf-bindings 'ctrl-e:accept'
zstyle ':fzf-tab:*' accept-line enter

autoload -U compinit && compinit

# enable color support of ls and also add handy aliases
# colorize ls
# if [ -x /usr/local/bin/gdircolors ]  && [ -s $HOME/.dir_colors ]; then
#   eval `gdircolors $HOME/.dir_colors`
#   alias ls='/usr/local/bin/gls --color=auto'
#   alias grep='grep --color=auto'
#   alias fgrep='fgrep --color=auto'
#   alias egrep='egrep --color=auto'
# fi

# Aliases
alias ls='ls -G'
alias ll='ls -ltrG'
alias vimd='vim -d'
alias psef='ps -ef | grep -i'
alias ps='ps -T'
alias cat='bat --style=plain'

## zshrc modification aliases
alias sz='source ~/.zshrc'
alias ez='vim ~/.zshrc'

# git aliases + scmpuff
eval "$(scmpuff init -s)"
alias gt="git tag"
alias gb="git branch"
alias gca="git commit -a"
alias gl="git lg"
alias gco="git checkout"

# TODO: jump to common directories quickly
# lets me avoid avoid `j` and the ilk i think.
# autojump sourcing
# h/t https://kevin.burke.dev/kevin/profiling-zsh-startup-time/ for the lazy-loading trick.
function j() {
    (( $+commands[brew] )) && {
        local pfx=$(brew --prefix)
        [[ -f "$pfx/etc/autojump.sh" ]] && . "$pfx/etc/autojump.sh"
        j "$@"
    }
}

# adapted from: http://stackoverflow.com/questions/14031970/git-push-current-branch-shortcut
function gpb()
{
    if git rev-parse --abbrev-ref --symbolic-full-name @{u} > /dev/null 2>&1; then
        git push origin HEAD
    else
        git push -u origin HEAD
    fi
}

function gcam() {
  git commit -am "$@"
}

# `ghc`: github-checkout -- quick checkout and directory switcher
# usage (1) `$ ghc <github-user>/<github-repo>`
# usage (2) `$ ghc github.com/<github-user>/<github-repo>(/.*)?`
function ghc() {
  local ghstub=$(echo $1 | sed -e 's/.*github.com\///g' -e 's/#.*$//g' | cut -d/ -f1,2)
  local target=$GHPATH/$ghstub
  if ! [ -d "$target" ]; then
    dirname=$(dirname $target)
    mkdir -p $dirname
    git clone git@github.com:${ghstub}.git $target
  fi
  cd $target
  # check directory git status
  if [ -n "$(git status --porcelain)" ]; then
    echo "WARNING: git status is not clean"
  else
    git checkout master
    git pull origin master
  fi
}

# ipython
# alias ip='ipython qtconsole --pylab=inline'
# alias ipn="ipython notebook $HOME/trash/notebooks"
# export PYTHONPATH=/usr/local/lib/python2.7/site-packages:
# export PIP_REQUIRE_VIRTUALENV=false
# # define a "global pip" function to use outside virtualenv:
# gpip(){
#     PIP_REQUIRE_VIRTUALENV="" pip "$@"
# }
#
# init_pyenv(){
#   eval "$(pyenv init -)"
#   eval "$(pyenv virtualenv-init -)"
# }

# uber-start
alias prod='DOMAIN=system.uberinternal.com; PROD=https://ignored:$(usso -ussh $DOMAIN -print)@$DOMAIN'

list_adhoc() {
  lzc host list --group=m3-adhoc --format H
}

# example usage
# $ resolve_uns uns://phx2/phx2-prod03/us1/statsdex_query/preprod/p-phx2/0:http
resolve_uns() {
  uns_path=$1
  jump_host=$(list_adhoc | head -n 1)
  ssh ${jump_host} "uns --format compact $uns_path"
}

# example_usage
# $ setup_tunnel 8080 $(resolve_uns uns://phx2/phx2-prod03/us1/statsdex_query/preprod/p-phx2/0:http)
setup_tunnel() {
  local_port=$1
  target_hostport=$2
  jump_host=$(list_adhoc | head -n 1)
  echo "setting up tunnel on localhost:$local_port to hit $target_hostport via $jump_host"
  ssh -L ${local_port}:${target_hostport} -N $jump_host
}

function reposearch() {
  echo "{\"constraints\": {\"query\": \"$1\"}}"     \
    | arc call-conduit diffusion.repository.search \
    | jq -r '.response.data[] | "\(.fields.name) - https://code.uberinternal.com/diffusion/\(.fields.callsign)"'
}

# functions to make working with arc suck less.
## WIP quick git commit
alias wip='git commit -am "squash! WIP"'

function squash() {
  GIT_SEQUENCE_EDITOR="sed -i -re '2,\$s/^pick /fixup /'" git rebase -i master
}

# extract_diff assumes a bunch of shit
# requires that the differential revision be mentioned in the commit message of the first commit on the branch based off master
# i.e. no chaining of diffs, no base branch which isn't master, etc.
function extract_diff() {
  git log --format='%B' -n1 $(git log master..HEAD --oneline | tail -n1 | cut -d ' ' -f 1) | grep 'https://code.uberinternal.com' | sed -e 's@.*\(D[0-9][0-9]*\)$@\1@'
}

# au is only meant to be used during update, not for creation.
function au() {
  arc diff --update $(extract_diff) $(git merge-base master HEAD) --message '.' $@
}
alias ws='wip && squash'
alias wsa='wip && squash && au'
# uber-end

# direnv
eval "$(direnv hook zsh)"
