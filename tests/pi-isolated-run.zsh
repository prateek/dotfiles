#!/usr/bin/env zsh
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-${0:A:h:h}}"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

settings="$tmp_root/settings.json"
dry_run="$tmp_root/dry-run.txt"
root="$tmp_root/isolated"

"$REPO_ROOT/scripts/pi-isolated-run" --root "$root" --empty --print-settings >"$settings"

python3 - "$settings" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
assert data["packages"] == [
    "npm:@earendil-works/pi-ai",
    "npm:@earendil-works/pi-coding-agent",
    "npm:@earendil-works/pi-tui",
    "npm:pi-claude-marketplace",
    "npm:pi-cursor-sdk",
    "npm:typebox",
    "npm:pi-vim",
    "npm:pi-statusline",
]
assert data["piVim"]["clipboardMirror"] == "yank"
assert data["statusLine"]["command"] == "~/.pi/agent/statusline.sh"
PY

[[ -f "$root/home/.pi/agent/settings.json" ]] || { echo "missing isolated settings" >&2; exit 1; }
[[ -d "$root/sessions" ]] || { echo "missing isolated sessions dir" >&2; exit 1; }
[[ -x "$root/home/.pi/agent/statusline.sh" ]] || { echo "missing isolated pi statusline" >&2; exit 1; }

"$REPO_ROOT/scripts/pi-isolated-run" --root "$root" --empty --dry-run -- --no-approve >"$dry_run"
grep -qF "HOME=$root/home" "$dry_run" || { echo "missing isolated home env" >&2; exit 1; }
grep -qF "PI_CODING_AGENT_DIR=$root/home/.pi/agent" "$dry_run" || { echo "missing isolated agent env" >&2; exit 1; }
grep -qF "PI_CODING_AGENT_SESSION_DIR=$root/sessions" "$dry_run" || { echo "missing isolated session env" >&2; exit 1; }
grep -qF "pi update --extensions" "$dry_run" || { echo "missing isolated package update" >&2; exit 1; }
grep -qF "pi --no-approve" "$dry_run" || { echo "missing pi command" >&2; exit 1; }

no_install="$tmp_root/no-install.txt"
"$REPO_ROOT/scripts/pi-isolated-run" --root "$root" --empty --no-install --dry-run >"$no_install"
if grep -qF "pi update --extensions" "$no_install"; then
  echo "unexpected package update with --no-install" >&2
  exit 1
fi

auto_dry_run="$tmp_root/auto-dry-run.txt"
"$REPO_ROOT/scripts/pi-isolated-run" --empty --dry-run >"$auto_dry_run"
grep -qF "cleanup: automatic rm -rf" "$auto_dry_run" || { echo "missing automatic dry-run cleanup" >&2; exit 1; }
auto_home=$(grep '^HOME=' "$auto_dry_run" | sed 's/^HOME=//')
auto_root="${auto_home%/home}"
[[ ! -d "$auto_root" ]] || { echo "auto dry-run root leaked: $auto_root" >&2; exit 1; }

mixed_args="$tmp_root/mixed-args.txt"
"$REPO_ROOT/scripts/pi-isolated-run" --root "$root" --empty --dry-run --no-install foo -- bar >"$mixed_args"
grep -qF "pi foo bar" "$mixed_args" || { echo "positional args before -- were not preserved" >&2; exit 1; }

help="$tmp_root/help.txt"
"$REPO_ROOT/scripts/pi-isolated-run" --help >"$help" 2>&1
grep -qF "Usage:" "$help" || { echo "help output is missing usage" >&2; exit 1; }
if grep -qF "set -euo pipefail" "$help"; then
  echo "help output leaked script body" >&2
  exit 1
fi

echo "ok: pi isolated run helper (settings render, package update, env, dry-run)"
