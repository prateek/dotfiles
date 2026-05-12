# Migrating from ios-flow-audit

`ios-audit` subsumes the former `ios-flow-audit` skill. Flow capture is
now the UX pillar of a broader 4-pillar audit. Existing flow YAMLs work
with no edits.

## What's the same

- Workflow YAML schema is unchanged. `examples/movies-do.yaml` and
  `examples/silly-tavern.yaml` port across without modification.
- `scripts/ux/run_workflows.py`, `scripts/ux/generate_report.py`, and
  `scripts/ux/review_screenshots.py` are the same files, relocated under
  `scripts/ux/` within `ios-audit`.
- The ios-simulator-skill dependency and execution model are unchanged.
- Screenshots, accessibility trees, and results.json are produced in the
  same format.

## What's new

- **Four pillars** instead of one: Code Health, UX, Runtime, Release.
- **Four phases**: COLLECT → ANALYZE → RENDER → DIFF.
- **audit.json baseline** for trend tracking across runs.
- **audit-diff.md** showing fixed / new / regressed findings since the
  previous baseline.
- **docs/ replacement**: the render phase writes a complete documentation
  tree, not just an HTML flow report. The HTML report is still produced
  as `audit.html` alongside the docs.
- **Pillar-scoped ANALYZE prompts** under `scripts/analyze/prompts/` that
  an invoking agent reads to author the markdown and findings JSON.
- **Per-screen layer hierarchies**, **gesture conflict detection**,
  **concurrency smells**, **privacy manifest checks**, and many other
  static analyses that flow-audit did not cover.

## How to update an existing caller

Old call:

```bash
python3 ~/.agents/skills/ios-flow-audit/scripts/run_workflows.py \
  --workflows .audit/flows.yaml \
  --output-dir /tmp/audit
python3 ~/.agents/skills/ios-flow-audit/scripts/generate_report.py \
  --results /tmp/audit/results.json \
  --output /tmp/audit/report.html
```

New equivalent (UX-only, no other pillars):

```bash
~/.agents/skills/ios-audit/scripts/audit.py collect \
  --repo ~/code/my-app \
  --workflows .audit/flows.yaml \
  --output /tmp/audit \
  --pillars ux
```

Or the legacy scripts still work directly from `scripts/ux/`:

```bash
~/.agents/skills/ios-audit/scripts/ux/run_workflows.py \
  --workflows .audit/flows.yaml \
  --output-dir /tmp/audit
```

For a full 4-pillar run (recommended):

```bash
~/.agents/skills/ios-audit/scripts/audit.py all \
  --repo ~/code/my-app \
  --workflows .audit/flows.yaml \
  --output /tmp/audit \
  --docs-dir ~/code/my-app/docs
```

## Removing the old skill

After verifying `ios-audit` works for your project, delete the old skill:

```bash
rm -rf ~/.agents/skills/ios-flow-audit
```

(Or `rm -rf ~/.claude/skills/ios-flow-audit` if installed there.)

There is no backward-compat symlink. The name change is intentional and
final.
