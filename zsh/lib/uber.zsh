#!/usr/bin/env zsh
# vim:syntax=sh
# vim:filetype=sh

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
