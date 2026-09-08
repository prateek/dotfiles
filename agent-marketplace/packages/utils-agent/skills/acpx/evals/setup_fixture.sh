#!/usr/bin/env bash
# Materialize the acpx trigger-eval fixture in a fresh absolute destination.
# Usage: setup_fixture.sh <dest_dir>
#
# Every query in trigger-evals.json names a path in this tree, so the model has
# nothing to hunt for before it decides whether to consult the skill. The tree
# is a git repo with one uncommitted change (the "diff on this branch" cases)
# and a project CLAUDE.md that retires the machine conventions' old pointer to
# ~/.agents/docs/acpx.md, so a machine that has not applied the change yet does
# not read that doc first and count as a miss.

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

mkdir -p -- "$DEST"/{.claude,internal/queue,internal/http/middleware,pkg/store,deploy/api,db/migrations,docs/design}
cd -- "$DEST"

cat > CLAUDE.md <<'MD'
# Project notes

The machine conventions' pointer to `~/.agents/docs/acpx.md` is retired. Do not
read that file; it carries no current guidance.
MD

cat > internal/queue/dispatch.go <<'GO'
package queue

import "time"

// dispatch drains the ready queue, retrying failed deliveries with
// exponential backoff before handing them to the DLQ writer.
func (d *Dispatcher) run() {
	backoff := 50 * time.Millisecond
	for job := range d.ready {
		for attempt := 0; attempt < d.maxAttempts; attempt++ {
			if err := d.deliver(job); err == nil {
				break
			}
			time.Sleep(backoff)
			backoff *= 2
		}
		d.dlq <- job // shares d.mu with the writer goroutine
	}
}
GO

cat > internal/http/middleware/auth.go <<'GO'
package middleware

import "net/http"

// Auth validates the bearer token and stashes the principal on the context.
func Auth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if _, ok := principalFrom(r); !ok {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(w, r)
	})
}
GO

cat > pkg/store/txn.go <<'GO'
package store

// Txn holds the shard lock, then the index lock. Commit releases in reverse.
func (s *Store) Txn(fn func(*Tx) error) error {
	s.shardMu.Lock()
	s.indexMu.Lock()
	defer s.indexMu.Unlock()
	defer s.shardMu.Unlock()
	return fn(&Tx{s: s})
}

// Reindex takes the index lock first, then walks shards under shardMu.
func (s *Store) Reindex() {
	s.indexMu.Lock()
	defer s.indexMu.Unlock()
	s.shardMu.Lock()
	defer s.shardMu.Unlock()
	s.rebuild()
}
GO

cat > deploy/api/Dockerfile <<'DF'
FROM golang:1.23 AS build
WORKDIR /src
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 go build -o /out/api ./cmd/api

FROM gcr.io/distroless/static
COPY --from=build /out/api /api
ENTRYPOINT ["/api"]
DF

for i in $(seq -w 1 12); do
  printf -- '-- migrate:up\nALTER TABLE orders ADD COLUMN col_%s text;\n-- migrate:down\n' "$i" \
    > "db/migrations/00${i}_add_col_${i}.sql"
done

cat > db/migrations/0007_add_orders_idx.sql <<'SQL'
-- migrate:up
CREATE INDEX orders_customer_created_idx ON orders (customer_id, created_at DESC);
-- migrate:down
DROP INDEX orders_customer_created_idx;
SQL

cat > docs/migration-plan.md <<'MD'
# Orders table migration plan

1. Add the new columns nullable.
2. Backfill in batches of 10k, ordered by id.
3. Flip the application read path behind a flag.
4. Drop the old columns one release later.
MD

cat > docs/design/sharding.md <<'MD'
# Sharding the orders store

Shard by customer_id modulo 64. Cross-customer reports fan out to all shards
and merge in the API layer. Rebalancing is out of scope for v1.
MD

cat > README.md <<'MD'
# Orderflow

Orderflow is a next-generation, cloud-native order orchestration platform that
empowers teams to unlock unprecedented velocity across the entire fulfillment
lifecycle. Built from the ground up for scale, it delivers best-in-class
reliability with a delightful developer experience.

## Slug rules

Valid: `acme`, `acme-corp`, `a1-b2`. Invalid: `-acme`, `acme-`, `Acme`, `a--b`.
MD

printf 'test:\n\tgo test ./...\n' > Makefile

git init -q .
git -c user.name="acpx eval" -c user.email="acpx-eval@example.com" add -A
git -c user.name="acpx eval" -c user.email="acpx-eval@example.com" commit -qm "fixture"
printf '// wip\n' >> internal/queue/dispatch.go

printf 'fixture=%s\n' "$DEST"
