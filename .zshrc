# Profile ZSH: https://github.com/zsh-users/zsh-syntax-highlighting/issues/30#issuecomment-4310722
# Begining:
# zmodload zsh/zprof
# End:
# zprof

# PATH(s)
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.7.0_65.jdk/Contents/Home
# export JAVA_HOME="/System/Library/Frameworks/JavaVM.framework/Versions/CurrentJDK/Home"
export GOPATH=$HOME/go
export PATH=$HOME/bin:/usr/local/bin:$GOPATH/bin:$HOME/trash/vowpal_wabbit/utl:$PATH
export EDITOR="vim"

if [ -d $HOME/dotfiles ]; then
  export DOTFILES=$HOME/dotfiles
else
  export DOTFILES=$HOME
fi

# RESET LS to ensure antigen works
OLD_LS=$(alias ls | sed -e "s/.*'\(.*\)'.*/\1/g")
if [ "$OLD_LS" != "" ]; then
  unalias ls
fi

# source antigen
source $DOTFILES/.zsh/antigen/antigen.zsh

# Load the oh-my-zsh's library.
antigen use oh-my-zsh

# Bundles from the default repo (robbyrussell's oh-my-zsh).
antigen bundle git
antigen bundle git-extras
antigen bundle github

antigen bundle pip
antigen bundle mvn
antigen bundle colored-man
antigen bundle command-not-found
antigen bundle rsync
antigen bundle python
antigen bundle virtualenvwrapper
antigen bundle command-not-found
antigen bundle history

antigen bundle zsh-users/zsh-completions src
# TODO: antigen bundle zsh-users/zaw
source /Users/prungta/trash/zaw/zaw.zsh
bindkey '^R' zaw-history

# Locale Settings
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

DARVIN_OS=darwin
if [ "${OSTYPE/$DARVIN_OS}" = "$OSTYPE" ]; then
    antigen-bundle osx
fi

antigen bundle zsh-users/zsh-syntax-highlighting
# Theme
antigen theme Granze/G-zsh-theme-2 granze2

# Tell antigen that you're done.
antigen apply
if [ "$OLD_LS" != "" ]; then
  alias ls="$OLD_LS"
fi

# if mode indicator wasn't setup by theme, define default
if [[ "$MODE_INDICATOR" == "" ]]; then
  MODE_INDICATOR="%{$fg_bold[red]%}<%{$fg[red]%}<<%{$reset_color%}"
fi

function vi_mode_prompt_info() {
  echo "${${KEYMAP/vicmd/$MODE_INDICATOR}/(main|viins)/}"
}

# define right prompt, if it wasn't defined by a theme
if [[ "$RPS1" == "" && "$RPROMPT" == "" ]]; then
  RPS1='$(vi_mode_prompt_info)'
fi

## Vim inner word key bindings
# . $DOTFILES/.zsh/opp.zsh/opp.zsh
# . $DOTFILES/.zsh/opp.zsh/opp/*.zsh

# source zsh file completions
# fpath=($HOME/.zsh/func /usr/local/share/zsh/site-functions $fpath)
# typeset -U fpath

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

if [ -x /usr/bin/dircolors ]; then
    test -r $HOME/dircolors && eval "$(dircolors -b $HOME/dircolors)" || eval "$(dircolors -b)"
   #  alias ls='ls --color=auto'
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

# History options
HISTFILE=$HOME/.zhistory      # enable history saving on shell exit
HISTSIZE=10000                # lines of history to maintain memory
SAVEHIST=100000               # lines of history to maintain in history file.
# setopt SHARE_HISTORY        # Killer: share history between multiple shells
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
autoload -U compinit && compinit

zstyle ':completion:*' menu select
setopt correctall
compctl -g '*(/)' rmdir dircmp j
compctl -g '*(-/)' cd chdir dirs pushd j
compinit

setopt nolistambiguous # one tab for completion
setopt MULTIOS         # tee/cat automatically

# convenient stuff
autoload zmv
setopt autocd
setopt extendedglob

# autoexapnd aliases
setopt no_complete_aliases

# no beeps
setopt NO_BEEP

# zsh modification aliases
alias sz='source ~/.zshrc'
alias ez='vim ~/.zshrc'

# ssh with vi mode enabled
function sshv { ssh -t $* "bash -i -o vi"  }
compdef sshv='ssh'

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

# SCM_BREEZE!!
source "/Users/prungta/.scm_breeze/scm_breeze.sh"

# convenience
alias l="| less"
alias v="| vim"
alias eclimd="/Applications/eclipse/eclimd"
alias j7="export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.7.0_65.jdk/Contents/Home"
alias yoink="open -a Yoink"
