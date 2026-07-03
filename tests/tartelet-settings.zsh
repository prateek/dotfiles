#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "tartelet-settings: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
tmpl="$DOTFILES_ROOT/home/.chezmoiscripts/run_onchange_after_17-tartelet-settings.sh.tmpl"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

# machine_type is forced via --override-data; .machines comes from the source's
# .chezmoidata. (An empty --config isolates the ambient [data] but breaks the
# settings template's includeTemplate of features.tmpl, so keep the plain form.)
render() {
  chezmoi --source "$DOTFILES_ROOT" --override-data "$1" \
    execute-template --file "$tmpl"
}

homelab="$tmp_root/homelab.sh"
render '{"machine_type":"homelab"}' >"$homelab"

bash -n "$homelab" || die "homelab render is not valid bash"

assert_has() { grep -qF -- "$1" "$homelab" || die "homelab render missing: $1"; }

# Desired values resolved from the homelab machine-type layer.
assert_has 'scope="repo"'
assert_has 'labels="tartelet,homelab"'
assert_has 'vm="virtualMachine=tartelet-runner"'
assert_has 'count=1'
assert_has 'start_read=1; start_write=true'
# tart_home is a host fact (empty off a store host); the assignment and the
# runtime-guarded write are always rendered.
grep -qE '^tart_home=' "$homelab" || die "homelab render missing tart_home assignment"

# Managed keys are written through defaults (cfprefsd-authoritative), not a file.
assert_has 'defaults write "$domain" githubRunnerScope -string "$scope"'
assert_has 'defaults write "$domain" numberOfVirtualMachines -int "$count"'
assert_has 'defaults write "$domain" startVirtualMachinesOnLaunch -bool "$start_write"'
assert_has 'defaults write "$domain" tartHomeFolderURL -string "$tart_home"'

# Credentials must never be written by this script.
grep -qiE 'defaults write .*(appId|ownerName|repositoryName|privateKey|PEM)' "$homelab" \
  && die "settings script must not touch credential keys" || true

# Personal render: no tartelet cask. The runner_* facts do not exist for personal,
# so the block must be gated at template time — the render must not reference them
# and must fall through to the skip branch.
personal="$tmp_root/personal.sh"
render '{"machine_type":"personal"}' >"$personal"
bash -n "$personal" || die "personal render is not valid bash"
grep -qF 'tartelet cask not selected' "$personal" || die "personal render should skip tartelet settings"
grep -q 'runner\|githubRunnerScope\|dk.shape.Tartelet' "$personal" \
  && die "personal render leaked tartelet settings (template guard missing)" || true

print -- "OK tartelet-settings"
