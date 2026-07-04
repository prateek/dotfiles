#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "tartelet-softnet-wrapper: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
tmpl="$DOTFILES_ROOT/home/.chezmoiscripts/run_after_18-tartelet-tart-softnet-wrapper.sh.tmpl"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

render() {
  chezmoi --source "$DOTFILES_ROOT" --override-data "$1" \
    execute-template --file "$tmpl"
}

# Homelab selects the tartelet cask, so the installer body renders.
homelab="$tmp_root/homelab.sh"
render '{"machine_type":"homelab"}' >"$homelab"
bash -n "$homelab" || die "homelab render is not valid bash"

assert_has() { grep -qF -- "$1" "$homelab" || die "homelab render missing: $1"; }

# Owns the path Tartelet's TartLocator hardcodes, forwarding to the real binary.
assert_has 'target="/opt/homebrew/bin/tart"'
assert_has 'real="/opt/homebrew/opt/tart/bin/tart"'
# Injects softnet isolation, and only reinstalls when the target differs.
assert_has '--net-softnet'
assert_has 'cmp -s "$tmp" "$target"'
# Warns rather than fails when the softnet sudo grant is absent.
assert_has 'sudo -n /opt/homebrew/bin/softnet'

# Personal has no tartelet cask, so the script must skip via the template gate and
# never touch /opt/homebrew/bin/tart.
personal="$tmp_root/personal.sh"
render '{"machine_type":"personal"}' >"$personal"
bash -n "$personal" || die "personal render is not valid bash"
grep -qF 'tart softnet wrapper skipped' "$personal" || die "personal render should skip the wrapper install"
grep -qF 'target="/opt/homebrew/bin/tart"' "$personal" \
  && die "personal render leaked the wrapper install (template guard missing)" || true

print -- "OK tartelet-softnet-wrapper"
