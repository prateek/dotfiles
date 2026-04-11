#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "macos-settings-coverage: $*"
  exit 1
}

assert_eq() {
  local got="$1"
  local want="$2"
  [[ "$got" == "$want" ]] || die "assert_eq failed: got='$got' want='$want'"
}

DOTFILES_ROOT="${0:A:h:h}"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

stub_bin="$tmp_root/bin"
mkdir -p "$stub_bin"
export PATH="$stub_bin:/usr/bin:/bin"

cat >"$stub_bin/defaults" <<'EOF'
#!/bin/sh
set -eu

case "${1:-}" in
  read)
    if [ "${2:-}" = "-g" ]; then
      domain="NSGlobalDomain"
      key="${3:-}"
    else
      domain="${2:-}"
      key="${3:-}"
    fi

    case "$domain $key" in
      "NSGlobalDomain AppleShowAllExtensions")
        printf '%s\n' "1"
        ;;
      "com.apple.finder AppleShowAllFiles")
        printf '%s\n' "1"
        ;;
      "com.apple.finder ShowPathbar")
        printf '%s\n' "1"
        ;;
      "com.apple.finder ShowStatusBar")
        printf '%s\n' "1"
        ;;
      *)
        exit 1
        ;;
    esac
    ;;
  *)
    printf 'unexpected defaults invocation: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$stub_bin/defaults"

output="$(
  MACOS_SCRIPT="$DOTFILES_ROOT/macos" \
  APPLY_SCRIPT="$DOTFILES_ROOT/scripts/macos/apply.sh" \
  bash "$DOTFILES_ROOT/scripts/audit/macos-settings-coverage.sh"
)"

line="$(print -r -- "$output" | awk -F '\t' '$1 == "com.apple.finder" && $2 == "AppleShowAllFiles" { print $0 }')"
[[ -n "$line" ]] || die "expected AppleShowAllFiles row in audit output"

managed="$(print -r -- "$line" | awk -F '\t' '{ print $4 }')"
where="$(print -r -- "$line" | awk -F '\t' '{ print $5 }')"

assert_eq "$managed" "yes"
[[ "$where" != "-" ]] || die "expected AppleShowAllFiles to point at a managing script line"
