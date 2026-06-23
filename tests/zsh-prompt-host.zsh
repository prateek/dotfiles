#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "zsh-prompt-host: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
TMPL="$DOTFILES_ROOT/home/dot_config/zsh/lib/prompt.zsh.tmpl"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

[[ -f "$TMPL" ]] || die "missing template: $TMPL"

render() {
  chezmoi \
    --source "$DOTFILES_ROOT" \
    --destination "$tmp_root/home" \
    --cache "$tmp_root/cache" \
    --persistent-state "$tmp_root/state.boltdb" \
    --override-data "{\"machine_type\":\"$1\"}" \
    execute-template --file "$TMPL"
}

expect_color() {
  local machine_type="$1" want="$2"
  render "$machine_type" |
    grep -Fq "zstyle ':prompt:pure:custom:prefix' color $want" ||
    die "machine_type=$machine_type: expected custom:prefix color $want"
}

expect_color personal 108
expect_color homelab  109
expect_color vm       242   # unknown type -> Pure default host grey

# Render work once, reused for the color assertion and the behavioral checks.
rendered_work="$(render work)"
print -r -- "$rendered_work" |
  grep -Fq "zstyle ':prompt:pure:custom:prefix' color 167" ||
  die "machine_type=work: expected custom:prefix color 167"

# Behavioral: host shown locally, suppressed when Pure already renders user@host.
zsh -f -c '
  eval "$1"
  psvar=(); prompt_pure_precustom
  [[ -n ${psvar[22]} ]]            || exit 21   # local: host prefix present
  [[ ${psvar[22]} == ${(%):-%m} ]] || exit 22   # and equals the short hostname
  psvar[13]=1; psvar[22]=; prompt_pure_precustom
  [[ -z ${psvar[22]} ]]            || exit 23   # ssh/root/container: suppressed
' _ "$rendered_work" || die "prompt_pure_precustom behavior wrong (exit $?)"

print -- "OK zsh-prompt-host"
