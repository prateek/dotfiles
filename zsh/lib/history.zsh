#!/usr/bin/env zsh
# vim:syntax=sh
# vim:filetype=sh

# history options
# nb: careful updating the history size - it gets expensive
export HISTFILE=$HOME/.zhistory      # enable history saving on shell exit
export HISTSIZE=30000                # lines of history to maintain memory
export SAVEHIST=30000                # lines of history to maintain in history file.

setopt EXTENDED_HISTORY			  # write in the ":start:elapsed;command" format
setopt HIST_EXPIRE_DUPS_FIRST # allow dups, but expire old ones when I hit HISTSIZE
setopt HIST_FIND_NO_DUPS      # do not find dups in history
setopt HIST_IGNORE_ALL_DUPS   # Even if there are commands inbetween commands that are the same, still only save the last one
setopt HIST_IGNORE_DUPS       # If I type cd and then cd again, only save the last one
setopt HIST_IGNORE_SPACE      # If a line starts with a space, don't save it.
setopt HIST_NO_STORE          # dont store invocations of history command.
setopt HIST_REDUCE_BLANKS     # Pretty    Obvious.  Right?
setopt HIST_SAVE_NO_DUPS      # dont save dupes
setopt INC_APPEND_HISTORY     # Write after each command