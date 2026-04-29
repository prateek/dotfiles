#!/usr/bin/env zsh

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
set +x 2>/dev/null || true
unsetopt verbose 2>/dev/null || true
set +v 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "dotfiles-cli: $*"
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || die "expected output to contain: $needle"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" != *"$needle"* ]] || die "expected output not to contain: $needle"
}

DOTFILES_ROOT="${0:A:h:h}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

stub_bin="$tmp_root/bin"
mkdir -p "$stub_bin"
export DEFAULTS_CALLS="$tmp_root/defaults-calls.log"

cat >"$stub_bin/defaults" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$DEFAULTS_CALLS"
EOF
chmod +x "$stub_bin/defaults"

python3 - "$DOTFILES_ROOT/bin/dotfiles" <<'PY'
import runpy
import sys

module = runpy.run_path(sys.argv[1])

fake_data = {
    "packages": {
        "default_profile": "full",
        "profiles": {
            "core": {
                "casks": [
                    {"name": "core-app"},
                ],
            },
            "full": {
                "casks": [
                    {"name": "core-app"},
                    {"name": "full-app"},
                ],
            },
        },
    },
    "system": {"macos": {"defaults": [], "systemsetup": [], "spotlight": []}},
    "apps": {
        "core_app": {
            "cask": "core-app",
            "defaults": {
                "com.example.core": {
                    "Enabled": True,
                },
            },
        },
        "full_app": {
            "cask": "full-app",
            "defaults": {
                "com.example.full": {
                    "Enabled": True,
                },
            },
        },
    },
}

module["desired_defaults"].__globals__["load_chezmoi_data"] = lambda: fake_data

core_ops, _, _ = module["desired_defaults"]("core")
full_ops, _, _ = module["desired_defaults"]("full")

assert [op["domain"] for op in core_ops] == ["com.example.core"], core_ops
assert [op["domain"] for op in full_ops] == ["com.example.core", "com.example.full"], full_ops
print("OK profile-gated defaults")
PY

state_root="$tmp_root/state"
tx_dir="$state_root/dotfiles/transactions"
mkdir -p "$tx_dir"

cat >"$tx_dir/rollback-types.json" <<'EOF'
{
  "id": "rollback-types",
  "operations": [
    {
      "operation": { "domain": "com.example", "key": "BoolValue" },
      "before": { "exists": true, "value": "1", "type": "bool" }
    },
    {
      "operation": { "domain": "com.example", "key": "IntValue" },
      "before": { "exists": true, "value": "7", "type": "int" }
    },
    {
      "operation": { "domain": "com.example", "key": "StringValue" },
      "before": { "exists": true, "value": "hello", "type": "string" }
    },
    {
      "operation": { "domain": "com.example", "key": "MissingValue" },
      "before": { "exists": false, "value": "", "type": "" }
    }
  ]
}
EOF

PATH="$stub_bin:$PATH" \
HOME="$tmp_root/home" \
XDG_STATE_HOME="$state_root" \
  "$DOTFILES_ROOT/bin/dotfiles" rollback run rollback-types --json >/dev/null

calls="$(<"$DEFAULTS_CALLS")"
assert_contains "$calls" "write com.example BoolValue -bool true"
assert_contains "$calls" "write com.example IntValue -int 7"
assert_contains "$calls" "write com.example StringValue -string hello"
assert_contains "$calls" "delete com.example MissingValue"

full_brewfile="$("$DOTFILES_ROOT/bin/dotfiles" render brewfile --profile full)"
assert_not_contains "$full_brewfile" 'brew "yarn"'
assert_not_contains "$full_brewfile" 'brew "gemini-cli"'

print -- "OK dotfiles-cli"
