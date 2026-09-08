#!/usr/bin/env bash
# Run trigger-evals.json through skill-creator's trigger runner against the
# installed skill listing. Prints the runner's JSON to stdout; progress and the
# per-query table go to stderr.
#
# Usage: run_trigger_evals.sh [--runs N] [--timeout S] [--model ID] [--keep]
#
# Serial on purpose. The runner materializes one temporary command per run in
# the fixture's .claude/commands/, and every concurrent worker shares that
# directory, so parallel runs each see several identical acpx entries in the
# listing and score each other's picks as misses. The first full run here was
# 0/27 on the positives at four workers and 6/9 at one.

set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$(dirname -- "$HERE")"
RUNS=3
TIMEOUT=120
MODEL=""
KEEP=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs) RUNS="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --keep) KEEP=1; shift ;;
    -h | --help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

command -v claude >/dev/null || { echo "claude is not on PATH" >&2; exit 1; }

# skill-creator ships the runner; look in the Anthropic marketplace checkout
# first, then any plugin that vendors the skill.
CREATOR=""
for candidate in \
  "$HOME/.claude/plugins/marketplaces/anthropic-agent-skills/skills/skill-creator" \
  "$HOME"/.agents/plugins/plugins/*/skills/skill-creator; do
  if [[ -f "$candidate/scripts/run_eval.py" ]]; then
    CREATOR="$candidate"
    break
  fi
done
[[ -n "$CREATOR" ]] || { echo "skill-creator's scripts/run_eval.py not found under ~/.claude/plugins or ~/.agents/plugins" >&2; exit 1; }

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
  --skill-path "$SKILL"
  --runs-per-query "$RUNS"
  --num-workers 1
  --timeout "$TIMEOUT"
  --verbose
)
[[ -n "$MODEL" ]] && args+=(--model "$MODEL")

# Record the model the runs will actually use. Without --model, claude -p takes
# the user's default, which only a real call reports (modelUsage in the result).
if [[ -z "$MODEL" ]]; then
  MODEL_USED="$(env -u CLAUDECODE claude -p 'Reply with the single word ok.' --output-format json 2>/dev/null \
    | python3 -c 'import json,sys; print(",".join(json.load(sys.stdin).get("modelUsage", {})) or "unknown")')"
else
  MODEL_USED="$MODEL"
fi

{
  echo "runner: $CREATOR/scripts/run_eval.py"
  echo "model: $MODEL_USED"
  echo "runs per query: $RUNS, serial, timeout ${TIMEOUT}s"
} >&2

cd -- "$FIXTURE"
PYTHONPATH="$CREATOR" exec python3 -m scripts.run_eval "${args[@]}"
