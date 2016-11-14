# Profile ZSH: https://github.com/zsh-users/zsh-syntax-highlighting/issues/30#issuecomment-4310722
# u
# Begining:
# zmodload zsh/zprof
# End:
# zprof

# PATH(s)
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.7.0_80.jdk/Contents/Home
# export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.8.0_73.jdk/Contents/Home
# export JAVA_HOME="/System/Library/Frameworks/JavaVM.framework/Versions/CurrentJDK/Home"
# export JAVA_HOME="/System/Library/Frameworks/JavaVM.framework/Versions/Current/Home"
[ -z "$GOPATH" ] && export GOPATH="/Users/prungta/gocode"
export PATH=$JAVA_HOME/bin:$HOME/bin:/usr/local/bin:$GOPATH/bin:$PATH
export EDITOR="vim"

if [ -d $HOME/dotfiles ]; then
  export DOTFILES=$HOME/dotfiles
else
  export DOTFILES=$HOME
fi

# Uber-start
source ~/.profile_corp
# Uber-end

# zplug (zsh plugin manager)
export ZPLUG_HOME=$HOME/.zplug
source $(brew --prefix zplug)/init.zsh
# zsh plugins
zplug "mafredri/zsh-async", on:sindresorhus/pure
zplug "sindresorhus/pure"
zplug "felixr/docker-zsh-completion", as:plugin, lazy:true
zplug "zsh-users/zaw"
# startup
zplug load

# Zaw Configs
bindkey -M filterselect '^R' down-line-or-history
bindkey -M filterselect '^S' up-line-or-history
bindkey -M filterselect '^E' accept-search
zstyle ':filter-select:highlight' selected bg=red
zstyle ':filter-select:highlight' matched fg=yellow,standout
zstyle ':filter-select' rotate-list yes
zstyle ':filter-select' case-insensitive yes
zstyle ':filter-select' extended-search yes
bindkey '^R' zaw-history

# Locale Settings
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# docker aliases
alias d=docker
alias dc=docker-compose

# hub alias
eval "$(hub alias -s)"

# Maven repo setup
export M2_REPO=$HOME/.m2/repository

# ipython
alias ip='ipython qtconsole --pylab=inline'
alias ipn="ipython notebook $HOME/trash/notebooks"
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

# create new mr maven job
# stolen from github.com/patrickangeles/cdh-maven-archetype
# mvn archetype:generate -DarchetypeCatalog=http://repository.cloudera.com/archetype-catalog.xml

# vim editing for commands
autoload -z edit-command-line
zle -N edit-command-line

autoload -z edit-command-output
zle -N edit-command-output

autoload -Uz copy-earlier-word
zle -N copy-earlier-word

# zsh completion
zstyle ':completion:*' menu select
setopt correctall
compctl -g '*(/)' rmdir dircmp j
compctl -g '*(-/)' cd chdir dirs pushd j

## colorize completions
zstyle ':completion:*' list-colors ''
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

compinit

setopt nolistambiguous # one tab for completion
setopt MULTIOS         # tee/cat automatically

# convenient stuff
autoload zmv
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

# stackoverflow in commandline
alias h='howdoi --color'

# zmv aliases
alias mmv='noglob zmv -W'

# drake using drip
# via https://gist.github.com/daguar/5368778
alias drake='drip -jar /Applications/drake/target/drake.jar'

# Neovim
# alias vim="nvim"

# scmpuff
eval "$(scmpuff init -s)"
alias gt="git tag"
alias gb="git branch"
alias gca="git commit -a"
alias gl="git lg"

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
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# npm, nodejs
# via: http://stackoverflow.com/questions/28017374/what-is-the-suggested-way-to-install-brew-node-js-io-js-nvm-npm-on-os-x
export NVM_DIR=~/.nvm
alias nvms="source $(brew --prefix nvm)/nvm.sh"

# zprof
