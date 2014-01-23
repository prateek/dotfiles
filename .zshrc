# PATH
export PATH=$HOME/bin:/usr/local/bin:$PATH

# prompt stolen from http://pthree.org/2009/03/28/add-vim-editing-mode-to-your-zsh-prompt/
source ~/.zsh/.prompt

# ipython 
alias ip='ipython qtconsole --pylab=inline'
alias ipn='ipython notebook ~/trash/notebooks'
export PYTHONPATH=/usr/local/lib/python2.7/site-packages:

## colorize ls
# eval `gdircolors $HOME/.dir_colors`

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

## colorize completions
zstyle ':completion:*' list-colors ''
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

# aliases
alias quit='exit'
alias vimd='vim -d'
alias psef='ps -ef | grep -i '

# bindings
bindkey -v # Vim bindings for zsh
# need to start using caps instead of jj
bindkey -Mviins 'ii' vi-cmd-mode # jj map to esc 

# git-aliases
source ~/.zsh/.git_aliases

# History options
HISTFILE=$HOME/.zhistory       # enable history saving on shell exit
setopt APPEND_HISTORY          # append rather than overwrite history file.
HISTSIZE=10000                  # lines of history to maintain memory
SAVEHIST=100000                  # lines of history to maintain in history file.
setopt HIST_EXPIRE_DUPS_FIRST  # allow dups, but expire old ones when I hit HISTSIZE
setopt EXTENDED_HISTORY        # save timestamp and runtime information

# Maven repo setup
# from http://coe4bd.github.io/HadoopHowTo/hadoopMaven/hadoopMaven.html
export M2_REPO=$HOME/.m2/repository

# create new mr maven job
# stolen from github.com/patrickangeles/cdh-maven-archetype
# mvn archetype:generate -DarchetypeCatalog=http://repository.cloudera.com/archetype-catalog.xml

# zsh completion -- needs to be after autojump!
autoload -U compinit && compinit

zstyle ':completion:*' menu select
setopt correctall
compctl -g '*(/)' rmdir dircmp j
compctl -g '*(-/)' cd chdir dirs pushd j
compinit

# one tab for completion
setopt nolistambiguous

# convenient stuff
autoload zmv
setopt autocd
setopt extendedglob

# colorized man
man() {
  env \
    LESS_TERMCAP_mb=$(printf "\e[1;31m") \
    LESS_TERMCAP_md=$(printf "\e[1;31m") \
    LESS_TERMCAP_me=$(printf "\e[0m") \
    LESS_TERMCAP_se=$(printf "\e[0m") \
    LESS_TERMCAP_so=$(printf "\e[1;44;33m") \
    LESS_TERMCAP_ue=$(printf "\e[0m") \
    LESS_TERMCAP_us=$(printf "\e[1;32m") \
    man "$@"
}

# command tab completion for homebrew
fpath=($HOME/.zsh/func $fpath)
typeset -U fpath

# tmux color
alias tmux="TERM=screen-256color-bce tmux -2"

# stackoverflow in commandline
alias h='howdoi --color'

# http://www.drbunsen.org/the-text-triumvirate/#tmux
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward
bindkey '^P' history-search-backward
bindkey '^N' history-search-forward  

# syntax highlight
# LESSPIPE=`which src-hilite-lesspipe.sh`
# export LESSOPEN="| ${LESSPIPE} %s"
# export LESS='-R'

# iter2 profile modify
function iterm_profile() {
  echo -e "\033]50;SetProfile=${1}\a"
}
