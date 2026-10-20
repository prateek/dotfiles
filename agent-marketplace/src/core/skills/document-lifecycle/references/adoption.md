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
page records only its documentation root, command names, skill discovery and
setup commands, and deliberate exceptions; it links the contract instead of
restating it. Put docs in `docs/` by default; `--docs-root` supports another
directory within the repository. A dedicated subtree can avoid applying this
strict schema to unrelated product documentation.

Create a small `index.md` router and `retired.md` ledger. Add frontmatter to
in-scope Markdown docs, keeping accepted ADR bodies unchanged. Build an accurate
inventory. Empty category directories are unnecessary. Retire only documents
whose closure is established, using the skill's retirement procedure.

## Use the environment's skill first

The skill folder is the distribution unit: `SKILL.md`, `references/`, `scripts/`,
and `agents/` travel together. It has no runtime dependency on the repository
that publishes it. Reading the adopting repo's agent instructions and documents
is task input, not a dependency on the publisher.

Do not vendor, pin, or checksum the skill in an adopting repo. Resolve it in
this order:

1. An explicit `DOCUMENT_LIFECYCLE_SKILL` path to a complete skill folder. Fail
   when that path lacks the validator; do not fall through.
2. A copy already available in the environment: a `document-lifecycle` folder
   in a user skill directory such as `.agents/skills`, `.claude/skills`, or
   `.codex/skills` under the home directory, or in the skill folder of an
   installed plugin that ships it. Use that version as is; its installer or
   plugin manager owns updates.
3. The repo-local fallback at `.agents/skills/document-lifecycle`, installed by
   the setup step below.

Agents apply the same rule: when the repo sets `DOCUMENT_LIFECYCLE_SKILL`, they
read that folder; otherwise, when their skill catalog already offers
`document-lifecycle`, they use it and do not install another copy. Versions may
differ between machines and CI, so validation output names the resolved folder.

### Install the latest fallback

Give the repo an explicit setup command for machines without an environment
copy. It installs the complete folder from the publisher's default branch into
`.agents/skills/document-lifecycle` and makes it visible to Claude Code at
`.claude/skills/document-lifecycle`. Add both paths to `.gitignore`; the
fallback follows upstream and is never committed. If the repo already links
`.claude/skills` to `../.agents/skills`, that link covers the skill. Otherwise
link only the skill folder, and leave an existing `.claude` path from another
installation alone.

Setup asks the adapter below whether an environment copy resolves; when one
does, setup reports it and installs nothing, so agents never see two catalog
entries with the same name. GitHub CLI's `gh skill install` (preview) records
the source ref in the installed `SKILL.md` frontmatter. It prefers a repository's
latest GitHub release and otherwise uses the default branch head; prateek/dotfiles
publishes no release, so the install follows its default branch:

```sh
python3 scripts/docs-lifecycle.py --environment || {
  gh skill install prateek/dotfiles \
    agent-marketplace/src/core/skills/document-lifecycle \
    --dir .agents/skills --force
  mkdir -p .claude/skills
  [ -e .claude/skills/document-lifecycle ] ||
    ln -s ../../.agents/skills/document-lifecycle .claude/skills/document-lifecycle
}
```

Re-running setup refreshes only the repo-local fallback; `gh skill update --dir
.agents/skills --all` also refreshes it in place. An environment copy keeps the
version its installer or plugin manager provides, even when it is older; set
`DOCUMENT_LIFECYCLE_SKILL` to select a different folder deliberately. Use the
repo's existing skill installer instead of `gh` when it can target the default
branch and these paths. A plain sparse `git clone --depth=1` of the default
branch, copying the folder, is an equivalent fallback without `gh`. Nothing
refreshes the fallback in the background.

Checks never install or fetch implicitly. When no skill resolves, they fail and
name the setup command. CI runs setup as its own step before validation, so each
run uses the publisher's current default branch: an upstream change can fail an
unchanged PR, and the resolved path in the log identifies the version used.
Setup runs upstream code, so give the CI job a read-only token, such as
`permissions: contents: read` with `GH_TOKEN: ${{ github.token }}` for `gh`.

Treat local edits to the fallback as forks. Keep customizations in the adapter
and document exceptions instead; setup overwrites the fallback folder.

A repo that authors this skill already has its dependency in the source tree;
reference that folder directly instead of resolving another copy, so changes are
validated with the version being written. Keep tests for the producer wherever
its normal test runner discovers them; the distributed skill must execute
without those tests or producer files.

## Wire the resolved tooling

The validator uses Python 3.14+ and Git, with no Python package dependencies.
Expose it through the repo's existing task runner or a thin adapter. Keep the
adapter to skill resolution, paths, and supported options; shared policy logic
belongs upstream. For example, put this adapter at `scripts/docs-lifecycle.py`.
It checks user skill folders and Claude Code's installed-plugin registry; add
any other plugin location your environment materializes.

```python
import json
import os
import runpy
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKILL = "skills/document-lifecycle"
VALIDATOR = "scripts/validate-doc-lifecycle.py"


def plugin_skills(home):
    registry = home / ".claude/plugins/installed_plugins.json"
    if not registry.is_file():
        return []
    entries = json.loads(registry.read_text()).get("plugins", {}).values()
    return [Path(entry["installPath"]) / SKILL
            for installs in entries for entry in installs
            if entry.get("projectPath") in (None, str(ROOT))]


def find_skill(include_local=True):
    override = os.environ.get("DOCUMENT_LIFECYCLE_SKILL")
    if override:
        skill = ROOT / Path(override).expanduser()
        if not (skill / VALIDATOR).is_file():
            raise SystemExit(f"Invalid DOCUMENT_LIFECYCLE_SKILL: {skill}")
        return skill
    home = Path.home()
    candidates = [home / folder / SKILL for folder in (".agents", ".claude", ".codex")]
    candidates += plugin_skills(home)
    if include_local:
        candidates.append(ROOT / ".agents" / SKILL)
    return next((p for p in candidates if (p / VALIDATOR).is_file()), None)


if __name__ == "__main__":
    if sys.argv[1:] == ["--environment"]:
        skill = find_skill(include_local=False)
        print(skill or "no environment copy of document-lifecycle", file=sys.stderr)
        raise SystemExit(0 if skill else 1)
    skill = find_skill()
    if skill is None:
        raise SystemExit("document-lifecycle skill unavailable; run docs setup")
    print(f"Lifecycle skill: {skill}", file=sys.stderr, flush=True)
    validator = runpy.run_path(str(skill / VALIDATOR))
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

Wire setup, the current-tree check, and the appropriate base check into existing
CI. Add the local check to an existing pre-commit mechanism if the repo has one;
preserve unrelated hooks. Verify with a temporary stale inventory and an illegal
locked body edit, then restore them. Do not claim enforcement until that check
is wired and exercised. No background scheduling is needed for ordinary
document work.

## Make agents reach it

Add a short pointer to the repo's existing agent instruction surface, adjusting
paths and command names. For example:

> When creating or changing plans, ADRs, or research, or completing documented
> work, use the `document-lifecycle` skill available in your environment; if
> none is available, run the docs setup command and read
> .agents/skills/document-lifecycle/SKILL.md. Repository paths, commands, and
> exceptions are in docs/document-lifecycle.md. Update the affected docs in the
> same change; regenerate the inventory and run lifecycle validation before
> handoff.

Preserve the repo's existing `AGENTS.md`/`CLAUDE.md` relationship. The fallback
remains readable as plain files when no plugin is available. Keep this pointer
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
