#!/usr/bin/env bash
# Run trigger-evals.json against the installed acpx skill. Prints the runner's
# JSON to stdout; the per-query table and the fixture path go to stderr.
#
# Usage: run_trigger_evals.sh [--runs N] [--workers N] [--timeout S] [--model ID]
#                             [--transcripts DIR] [--keep]
#
# trigger_eval.py measures the real listing, so utils-agent 1.3.0 or later must
# be materialized under ~/.agents/plugins, and the eval scores the installed
# description rather than this checkout's; the wrapper warns when they differ.
# Nothing is injected into the listing, so runs can be concurrent. Pass
# --transcripts to keep each run's event stream outside the fixture.

set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$(dirname -- "$HERE")"
INSTALLED="$HOME/.agents/plugins/plugins/utils-agent/skills"
RUNS=3
WORKERS=3
TIMEOUT=120
MODEL=""
TRANSCRIPTS=""
KEEP=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs) RUNS="$2"; shift 2 ;;
    --workers) WORKERS="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --transcripts) TRANSCRIPTS="$(cd -- "$(dirname -- "$2")" && pwd)/$(basename -- "$2")"; shift 2 ;;
    --keep) KEEP=1; shift ;;
    -h | --help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

command -v claude >/dev/null || { echo "claude is not on PATH" >&2; exit 1; }
for name in acpx acpx-cli; do
  if [[ ! -f "$INSTALLED/$name/SKILL.md" ]]; then
    echo "utils-agent:$name is not installed under $INSTALLED; apply utils-agent >= 1.3.0 first" >&2
    exit 1
  fi
done

description() { sed -n '2,/^---$/p' "$1" | grep -m1 '^description:'; }
if [[ "$(description "$SKILL/SKILL.md")" != "$(description "$INSTALLED/acpx/SKILL.md")" ]]; then
  echo "warning: the installed acpx description differs from this checkout's; the eval scores the installed one" >&2
fi

FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/acpx-trigger-eval.XXXXXX")"
rmdir "$FIXTURE"
"$HERE/setup_fixture.sh" "$FIXTURE" >&2
if [[ $KEEP -eq 0 ]]; then
  trap 'rm -rf "$FIXTURE"' EXIT
else
  echo "keeping fixture: $FIXTURE" >&2
fi

args=(
  --eval-set "$HERE/trigger-evals.json"
  --runs "$RUNS"
  --workers "$WORKERS"
  --timeout "$TIMEOUT"
  --verbose
)
[[ -n "$MODEL" ]] && args+=(--model "$MODEL")
[[ -n "$TRANSCRIPTS" ]] && args+=(--transcripts "$TRANSCRIPTS")
echo "runs per query: $RUNS, workers: $WORKERS, timeout ${TIMEOUT}s${TRANSCRIPTS:+, transcripts: $TRANSCRIPTS}" >&2

cd -- "$FIXTURE"
# Not exec: the EXIT trap has to outlive the runner to remove the fixture.
if python3 "$HERE/trigger_eval.py" "${args[@]}"; then
  status=0
else
  status=$?
fi
exit "$status"
