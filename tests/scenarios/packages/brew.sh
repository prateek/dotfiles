#!/bin/sh
set -eu
printf '%s%s\n' "${HOMEBREW_CASK_OPTS:+CASK_OPTS=$HOMEBREW_CASK_OPTS }" "$*" >> "$FIXTURE/brew.calls"
case "$*" in
  '--repository') printf '%s\n' "$FIXTURE/brew-repo" ;;
  tap) cat "$FIXTURE/brew.taps" ;;
  'list --formula') cat "$FIXTURE/brew.formulas" ;;
  'list --cask') cat "$FIXTURE/brew.casks" ;;
  'info --json=v2 --installed'|'outdated --json=v2')
    "$TEST_PYTHON" - "$1" <<'PYTHON'
import json, os, pathlib, re, sys
root = pathlib.Path(os.environ['FIXTURE'])
changes = {}
for line in (root / 'brew.outdated').read_text().splitlines():
    match = re.fullmatch(r'(\S+) \(([^)]+)\) != (.+)', line)
    if match: changes[match[1]] = (match[2], match[3])
data = {'formulae':[], 'casks':[]}
for file, kind in [('formulas','formulae'), ('casks','casks')]:
    for name in (root / ('brew.' + file)).read_text().splitlines():
        current, latest = changes.get(name, ('1','1'))
        if sys.argv[1] == 'outdated':
            if name in changes: data[kind].append({'name':name})
        elif kind == 'formulae':
            data[kind].append({'name':name, 'installed':[{'version':current}], 'versions':{'stable':latest}})
        else:
            data[kind].append({'token':name, 'installed':current, 'version':latest})
print(json.dumps(data))
PYTHON
    ;;
  tap\ *|install\ *|uninstall\ *) ;;
  *) printf 'unexpected brew command: %s\n' "$*" >&2; exit 99 ;;
esac
