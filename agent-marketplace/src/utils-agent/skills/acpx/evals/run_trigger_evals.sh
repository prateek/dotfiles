#!/usr/bin/env bash
# Run trigger-evals.json against the installed acpx skill, with acpx-cli as the
# competing sibling. Every argument passes through to the shared runner
# (agent-marketplace/scripts/trigger-eval/run.sh), which documents them. Run it
# from the checkout; the shared runner is not part of the published plugin.

set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/../../../../../scripts/trigger-eval/run.sh" \
  --skill-dir "$(dirname -- "$HERE")" --sibling acpx-cli "$@"
