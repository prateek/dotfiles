#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true

die() {
  print -u2 -- "brew-inventory: $*"
  exit 1
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" != *"$needle"* ]] || die "unexpected output: $needle"
}

DOTFILES_ROOT="${0:A:h:h}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

stub_bin="$tmp_root/bin"
mkdir -p "$stub_bin"

brewfile="$tmp_root/Brewfile"
cat >"$brewfile" <<'EOF'
tap "yqrashawn/goku"
brew "homebrew/core/xcodes", args: ["force-bottle"]
brew "yqrashawn/goku/goku"
EOF

cat >"$stub_bin/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$*" in
  tap)
    printf 'yqrashawn/goku\n'
    ;;
  "list --formula --full-name")
    printf 'xcodes\nyqrashawn/goku/goku\n'
    ;;
  "list --formula --installed-on-request --full-name")
    printf 'xcodes\nyqrashawn/goku/goku\n'
    ;;
  *)
    printf 'unexpected brew call: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$stub_bin/brew"

out="$(
  PATH="$stub_bin:/usr/bin:/bin" \
  BREWFILE="$brewfile" \
  "$DOTFILES_ROOT/scripts/audit/brew-inventory.sh"
)"

assert_not_contains "$out" "- homebrew/core/xcodes"

print -- "OK brew-inventory"
