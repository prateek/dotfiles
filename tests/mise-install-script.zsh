#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "mise-install-script: $*"
  exit 1
}

assert_eq() {
  local got="$1"
  local want="$2"
  [[ "$got" == "$want" ]] || die "expected '$want', got '$got'"
}

assert_match() {
  local got="$1"
  local pattern="$2"
  [[ "$got" == ${~pattern} ]] || die "expected '$got' to match '$pattern'"
}

DOTFILES_ROOT="${0:A:h:h}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

stub_bin="$tmp_root/bin"
mkdir -p "$stub_bin" "$tmp_root/home"

export MISE_CALLS="$tmp_root/mise-calls.log"

cat >"$stub_bin/mise" <<'EOF'
#!/bin/sh
set -eu
if [ "${MISE_RUBY_GITHUB_ATTESTATIONS:-}" != "false" ]; then
  echo "MISE_RUBY_GITHUB_ATTESTATIONS was not defaulted to false" >&2
  exit 1
fi
printf '%s\n' "$*" >> "$MISE_CALLS"
EOF
chmod +x "$stub_bin/mise"

rg -q '^github_attestations = false$' "$DOTFILES_ROOT/home/dot_config/mise/conf.d/runtimes.toml" \
  || die "mise config should disable unauthenticated Ruby attestation checks during bootstrap"

script="$tmp_root/mise-install.sh"
chezmoi \
  --source "$DOTFILES_ROOT" \
  --destination "$tmp_root/home" \
  --cache "$tmp_root/cache" \
  --persistent-state "$tmp_root/chezmoi-state.boltdb" \
  --override-data '{"run_install_scripts":true}' \
  execute-template \
  --file "$DOTFILES_ROOT/home/.chezmoiscripts/run_onchange_after_20-mise-install.sh.tmpl" \
  >"$script"

PATH="$stub_bin:/usr/bin:/bin" HOME="$tmp_root/home" bash "$script" >/dev/null

calls=("${(@f)$(<"$MISE_CALLS")}")
assert_match "${calls[1]}" 'trust */home/.config/mise/config.toml'
assert_eq "${calls[2]}" 'install -y node'
assert_eq "${calls[3]}" 'install -y go'
assert_eq "${calls[4]}" 'exec node -- mise install -y'

print -- "OK mise-install-script"
