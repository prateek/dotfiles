#!/bin/zsh
set -euo pipefail
source "$1"
case "$2" in
  color)
    zstyle -s ':prompt:pure:custom:prefix' color prefix_color
    print -r -- "$prefix_color"
    ;;
  host)
    psvar=()
    prompt_pure_precustom
    [[ -n ${psvar[22]} && ${psvar[22]} == ${(%):-%m} ]] || {
      print -u2 'local prompt must show the short hostname'
      exit 1
    }
    psvar[13]=1
    psvar[22]=
    prompt_pure_precustom
    [[ -z ${psvar[22]} ]] || {
      print -u2 'custom host must be absent when Pure already shows user@host'
      exit 1
    }
    ;;
esac
