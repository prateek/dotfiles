# Adopt in a repository

Use this procedure when the user requests lifecycle adoption. Read existing
agent instructions, docs structure, task runner, and CI first. Preserve established
names and compatible conventions. If the repo uses materially different status,
retention, or frontmatter rules, describe that conflict before replacing them;
this validator implements the contract in this skill, not arbitrary schemas.

## Establish the contract

Inventory tracked docs and their consumers. Identify current guidance, open
work, locked decisions, and historical material. Review actual acceptance
criteria before closing anything. An initial migration may add metadata and
navigation without resolving every stale plan; park uncertain work and report
it. Keep unrelated files and user edits intact.

Reference [contract.md](contract.md) as the shared policy. The repo-owned lifecycle
page records only its documentation root, command names, pinned dependency,
and deliberate exceptions; it links the pinned contract instead of restating
it. Put docs in `docs/` by default; `--docs-root` supports another directory
within the repository. A dedicated subtree can avoid applying this strict
schema to unrelated product documentation.

Create a small `index.md` router and `retired.md` ledger. Add frontmatter to
in-scope Markdown docs, keeping accepted ADR bodies unchanged. Build an accurate
inventory. Empty category directories are unnecessary. Retire only documents
whose closure is established, using the skill's retirement procedure.

## Pin one complete skill dependency

The skill folder is the distribution unit: `SKILL.md`, `references/`, `scripts/`,
and `agents/` travel together. It has no runtime dependency on the repository
that publishes it. Reading the adopting repo's agent instructions and documents
is task input, not a dependency on the publisher.

Use the repo's existing dependency mechanism to pin the complete folder to an
immutable source revision or verified artifact. If it has no suitable mechanism,
vendor that folder under `vendor/document-lifecycle/` and record its upstream
source, immutable revision, and file checksums outside the vendored folder.
Treat it as a dependency: update the whole folder from upstream, verify the
receipt, and review the diff. Local edits to vendored policy or scripts are
forks; keep customizations in an adapter and document exceptions instead.

Both agents and CI use this pinned folder. An installed plugin may discover
the workflow, but must defer to the repo's pinned skill and contract when they
differ. Never silently substitute the globally installed version or fetch a
moving branch during validation. Contributors without a plugin can read the
same pinned files and run the same commands.

A repo that authors this skill already has its dependency in the source tree;
reference that folder directly instead of making a second vendored copy.
Keep tests for the producer wherever its normal test runner discovers them;
the distributed skill must execute without those tests or producer files.

## Wire the pinned tooling

The validator uses Python 3.14+ and Git, with no Python package dependencies.
Expose it through the repo's existing task runner or a thin adapter. Keep the
adapter to paths and supported options; shared policy logic belongs upstream.
For example, with the dependency at `vendor/document-lifecycle`, put this shim
at `scripts/docs-lifecycle.py`:

```python
import runpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
validator = runpy.run_path(str(
    ROOT / "vendor/document-lifecycle/scripts/validate-doc-lifecycle.py"
))
if __name__ == "__main__":
    raise SystemExit(validator["main"](
        default_repo_root=ROOT,
        inventory_command="python3 scripts/docs-lifecycle.py --write-inventory",
    ))
```

Run from the repository root:

```sh
python3 scripts/docs-lifecycle.py --write-inventory
python3 scripts/docs-lifecycle.py
python3 scripts/docs-lifecycle.py --base HEAD
python3 scripts/docs-lifecycle.py --due
```

For a custom root, pass `--docs-root /absolute/repo/guides` on every command and
include the same argument in the adapter's `inventory_command`. The adapter
can derive that absolute path from `ROOT` rather than embedding a machine path.
The `--write-inventory` command writes only the inventory; inspect validation
errors separately. The due report is read-only and advisory.

Run a current-tree check during initial adoption. Land the adoption baseline
before enabling branch-history checks: pre-adoption commits may legitimately
lack the new schema. For subsequent PRs, use `--base <target-branch-ref>` with
Git history and the target ref available; the checker walks commits since their
merge base. `--base HEAD` checks local changes against HEAD, not a whole PR.
An unborn repo uses the current-tree check until its first commit.

Wire the current-tree and appropriate base checks into existing CI. Add the
local check to an existing pre-commit mechanism if the repo has one; preserve
unrelated hooks. Verify with a temporary stale inventory and an illegal locked
body edit, then restore them. Do not claim enforcement until that check is wired
and exercised. No background scheduling is needed for ordinary document work.

## Make agents reach it

Add a short pointer to the repo's existing agent instruction surface, adjusting
paths and command names. For example:

> When creating or changing plans, ADRs, or research, or completing documented
> work, read vendor/document-lifecycle/SKILL.md and follow the pinned contract.
> Repository paths, commands, and exceptions are in docs/document-lifecycle.md. Update the affected docs in the same change;
> regenerate the inventory and run lifecycle validation before handoff.

Preserve the repo's existing `AGENTS.md`/`CLAUDE.md` relationship. The pinned
skill remains readable when the plugin is unavailable. Keep this pointer
about behavior; one-off migration results belong in the change description.

## Review due work

Run `--due` during landing reviews or periodic maintenance. It uses Git dates,
not editable frontmatter timestamps, for the ninety-day threshold. New uncommitted
docs have no Git dates and will not appear. It reports old parked/open plans,
research without consumers, and research whose present consumers are settled.
It cannot prove completion or that a consumer incorporated the findings.
Check retired consumers through the ledger as well.

Resume, park, or retire each reviewed item based on evidence and user direction.
When the user's decision is missing, leave parked work parked. Scheduling future
reviews is a separate request, not part of installing the skill.
