#!/usr/bin/env bash
# Materialize the lore trigger-eval fixture in a fresh absolute destination.
# Usage: setup_fixture.sh <dest_dir>
#
# A small git repo holding the symbols trigger-evals.json names, with a short
# history behind each, so the model has nothing to hunt for before it decides
# whether to consult the skill.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <dest_dir>" >&2
  exit 2
fi

DEST="$1"

if [[ "$DEST" != /* ]]; then
  echo "destination must be absolute: $DEST" >&2
  exit 1
fi

if [[ -e "$DEST" || -L "$DEST" ]]; then
  echo "refusing to overwrite fixture path: $DEST" >&2
  exit 1
fi

mkdir -p -- "$DEST"/{.claude,internal/source,internal/usage,internal/flush,deploy/gateway,scripts}
cd -- "$DEST"

git init -q -b main
git config user.name "Fixture Author"
git config user.email "fixture@example.invalid"
commit() { git add -A && git commit -q -m "$1"; }

cat > internal/usage/config.go <<'GO'
package usage

const defaultNumShards = 64
GO
cat > internal/source/resolve.go <<'GO'
package source

import "errors"

var ErrUnknownSource = errors.New("unknown source")

func resolveSource(caller string) (string, error) {
	if caller == "" {
		return "default", nil
	}
	return caller, nil
}
GO
commit "usage: add sharded store and source resolution"

sed -i.bak 's/64/128/' internal/usage/config.go && rm internal/usage/config.go.bak
commit "usage: double shard count"

cat > internal/flush/flush.go <<'GO'
package flush

import "time"

const flushTimeout = 30 * time.Second
GO
cat > deploy/gateway/values.yaml <<'YAML'
resources:
  limits:
    memory: 2Gi
YAML
cat > scripts/clone.sh <<'SH'
#!/usr/bin/env bash
git clone https://github.com/example/tools.git "$1"
SH
cat > README.md <<'MD'
# fixture service

Usage store, source resolution, and a flush loop.
MD
commit "flush: add timeout; gateway chart; clone helper"

echo "// TODO: retry" >> internal/flush/flush.go
