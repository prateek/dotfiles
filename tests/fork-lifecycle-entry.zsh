#!/usr/bin/env zsh
#
# Regression tests for scripts/packages/fork-lifecycle-entry: the forks
# package group editor used by the fork-lifecycle automation.

set -euo pipefail
unsetopt xtrace 2>/dev/null || true
setopt typeset_silent 2>/dev/null || true

die() {
  print -u2 -- "fork-lifecycle-entry: $*"
  exit 1
}

DOTFILES_ROOT="${0:A:h:h}"
entry="$DOTFILES_ROOT/scripts/packages/fork-lifecycle-entry"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

f="$tmp_root/packages.toml"
cp "$DOTFILES_ROOT/home/.chezmoidata/packages.toml" "$f"

out="$("$entry" add --file "$f" --name prateek/tap/x-fork --kind cask --replaces x)"
[[ "$out" == *"added prateek/tap/x-fork"* ]] || die "add: unexpected output: $out"
grep -q 'name = "prateek/tap/x-fork", kind = "cask", replaces = "x"' "$f" || die "add: entry missing"

out="$("$entry" add --file "$f" --name prateek/tap/x-fork --kind cask)"
[[ "$out" == *"already listed"* ]] || die "re-add should be a no-op: $out"

# The edited file must still parse, and the entry must round-trip.
python3 - "$f" <<'PY' || die "edited file does not parse as TOML"
import sys, tomllib
data = tomllib.load(open(sys.argv[1], "rb"))
entries = data["packages"]["groups"]["forks"]["entries"]
assert entries[-1] == {"name": "prateek/tap/x-fork", "kind": "cask", "replaces": "x"}, entries
PY

# A formula entry without replaces is legal.
"$entry" add --file "$f" --name prateek/tap/y-fork --kind formula >/dev/null
grep -q 'name = "prateek/tap/y-fork", kind = "formula" }' "$f" || die "formula entry malformed"

out="$("$entry" remove --file "$f" --name prateek/tap/x-fork)"
[[ "$out" == *"removed prateek/tap/x-fork"* ]] || die "remove: unexpected output: $out"
grep -q "x-fork" "$f" && die "remove: entry still present"

out="$("$entry" remove --file "$f" --name prateek/tap/x-fork)"
[[ "$out" == *"not listed"* ]] || die "re-remove should be a no-op: $out"

# Unrelated groups are untouched by the whole session.
grep -q 'name = "git" ' "$f" || grep -q '{ name = "git" }' "$f" || die "unrelated entries disturbed"

print -- "OK fork-lifecycle-entry"
