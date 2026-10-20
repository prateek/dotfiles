#!/usr/bin/env bash
# Run a skill's evals/trigger-evals.json against its installed copy. Prints the
# runner's JSON to stdout; the per-query table and the fixture path go to
# stderr. Exits 1 when any query misses.
#
# Usage: run.sh --skill-dir DIR [--sibling NAME]... [--runs N] [--workers N]
#               [--timeout S] [--model ID] [--transcripts DIR] [--keep]
#
# DIR is the skill's checkout directory, src/<plugin>/skills/<name>. It
# must hold evals/trigger-evals.json and an executable evals/setup_fixture.sh
# that takes one absolute, not-yet-existing destination. The skill and each
# --sibling (a skill name in the same plugin) must be materialized under
# ~/.agents/plugins; the eval scores the installed description, and warns when
# it differs from the checkout's.

set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR=""
SIBLINGS=()
RUNS=3
WORKERS=3
TIMEOUT=120
MODEL=""
TRANSCRIPTS=""
KEEP=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill-dir) SKILL_DIR="$(cd -- "$2" && pwd)"; shift 2 ;;
    --sibling) SIBLINGS+=("$2"); shift 2 ;;
    --runs) RUNS="$2"; shift 2 ;;
    --workers) WORKERS="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --transcripts) TRANSCRIPTS="$(cd -- "$(dirname -- "$2")" && pwd)/$(basename -- "$2")"; shift 2 ;;
    --keep) KEEP=1; shift ;;
    -h | --help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$SKILL_DIR" ]] || { echo "--skill-dir is required" >&2; exit 2; }
NAME="$(basename -- "$SKILL_DIR")"
PLUGIN="$(basename -- "$(dirname -- "$(dirname -- "$SKILL_DIR")")")"
INSTALLED="$HOME/.agents/plugins/plugins/$PLUGIN/skills"
EVALS="$SKILL_DIR/evals"

command -v claude >/dev/null || { echo "claude is not on PATH" >&2; exit 1; }
for name in "$NAME" ${SIBLINGS[@]+"${SIBLINGS[@]}"}; do
  if [[ ! -f "$INSTALLED/$name/SKILL.md" ]]; then
    echo "$PLUGIN:$name is not installed under $INSTALLED; materialize the plugin first" >&2
    exit 1
  fi
done

description() { sed -n '2,/^---$/p' "$1" | grep -m1 '^description:'; }
if [[ "$(description "$SKILL_DIR/SKILL.md")" != "$(description "$INSTALLED/$NAME/SKILL.md")" ]]; then
  echo "warning: the installed $NAME description differs from this checkout's; the eval scores the installed one" >&2
fi

FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/$NAME-trigger-eval.XXXXXX")"
rmdir "$FIXTURE"
"$EVALS/setup_fixture.sh" "$FIXTURE" >&2
if [[ $KEEP -eq 0 ]]; then
  trap 'rm -rf "$FIXTURE"' EXIT
else
  echo "keeping fixture: $FIXTURE" >&2
fi

args=(
  --skill "$PLUGIN:$NAME"
  --eval-set "$EVALS/trigger-evals.json"
  --runs "$RUNS"
  --workers "$WORKERS"
  --timeout "$TIMEOUT"
  --verbose
)
[[ -n "$MODEL" ]] && args+=(--model "$MODEL")
[[ -n "$TRANSCRIPTS" ]] && args+=(--transcripts "$TRANSCRIPTS")
echo "skill: $PLUGIN:$NAME, runs per query: $RUNS, workers: $WORKERS, timeout ${TIMEOUT}s${TRANSCRIPTS:+, transcripts: $TRANSCRIPTS}" >&2

cd -- "$FIXTURE"
# Not exec: the EXIT trap has to outlive the runner to remove the fixture.
if python3 -B "$HERE/trigger_eval.py" "${args[@]}"; then
  status=0
else
  status=$?
fi
exit "$status"
