#!/usr/local/bin/zsh

# install.sh - utility script to install zsh plugins. found this to be faster than using any plugin managers
#
# Note: This uses ZSH specific shell features, but considering this is for zsh plugin install, w/e.
# Author: Prateek Rungta

CWD=$(dirname "$0")
RAW_FOLDER=$CWD/raw
FUNCTION_FOLDER=$CWD/zfunctions
COMPLETION_FOLDER=$CWD/completions

typeset -A targets
targets=(
  "async"              "https://raw.githubusercontent.com/sindresorhus/pure/master/async.zsh"       \
  "prompt_pure_setup"  "https://raw.githubusercontent.com/sindresorhus/pure/master/pure.zsh"        \
  "hub_completions"    "https://raw.githubusercontent.com/github/hub/master/etc/hub.zsh_completion" \
)

typeset -A folders
folders=(
  "async"              "$FUNCTION_FOLDER"   \
  "prompt_pure_setup"  "$FUNCTION_FOLDER"   \
  "hub_completions"    "$COMPLETION_FOLDER" \
)

mkdir -p $RAW_FOLDER $FUNCTION_FOLDER $COMPLETION_FOLDER
install_date=$(date +%Y%m%d%H%M)
for name in "${(@k)targets}"; do
  url=$targets[$name]
  folder=$folders[$name]
  echo "Installing $name: from $url"

  # clear existing raw file
  rm -f $RAW_FOLDER/${name}-*

  # download raw file and mark executable
  raw_file=$RAW_FOLDER/${name}-${install_date}
  curl -o $raw_file $url
  chmod +x $raw_file

  # soft-link to target folder
  rm -f $folder/$name
  ln -s $raw_file $folder/$name
done
