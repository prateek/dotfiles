#!/usr/local/bin/zsh

# install.sh - utility script to install zsh plugins. found this to be faster than using any plugin managers
#
# Note: This uses ZSH specific shell features, but considering this is for zsh plugin install, w/e.
# Author: Prateek Rungta

typeset -A targets
targets=(
  "async"              "https://raw.githubusercontent.com/sindresorhus/pure/master/async.zsh"       \
  "prompt_pure_setup"  "https://raw.githubusercontent.com/sindresorhus/pure/master/pure.zsh"        \
  "hub_completions"    "https://raw.githubusercontent.com/github/hub/master/etc/hub.zsh_completion" \
)

install_date=$(date +%Y%m%d%H%M)

for name in "${(@k)targets}"; do
  url=$targets[$name]
  echo "Installing $name: from $url"
  rm -f ${name}-*
  local_file=${name}-${install_date}
  curl -o $local_file $url
  chmod +x $local_file
  rm -f ./zfunctions/$name
  ln -s $PWD/$local_file ./zfunctions/$name
done
