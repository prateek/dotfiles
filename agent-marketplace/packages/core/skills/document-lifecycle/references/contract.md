# Lifecycle contract

This is the portable default for repos adopting the skill. Existing repo policy
wins until adoption. Scope it to a chosen documentation root; repo-root README,
agent instructions, and skill files keep their own formats.

## Frontmatter and types

Every in-scope Markdown file starts with frontmatter and an H1. `status` and
`summary` are required; include `doc_type` for new documents so the inventory
can classify them. The summary is one line describing scope, without progress
or dates. Use simple scalars, inline lists, or two-space list items; nested
maps and block scalars are unsupported.

```yaml
---
status: active
doc_type: plan
summary: "Migrate the search index while preserving existing query behavior."
owner: Maintainer
created: 2026-10-17
updated: 2026-10-17
related:
  - ../adr/0001-search-index.md
status_detail: "Backfill verification remains open."
---
```

Use only links that exist; the example path must be replaced with a real
consumer or omitted. Other supported fields are `superseded_by`,
`current_guidance`, and `closed`. Dates use `YYYY-MM-DD`. Git commit dates,
not `updated`, drive the due report.

| Type | Allowed states | Purpose |
| --- | --- | --- |
| plan | draft, proposed, accepted, active, superseded, rejected, archived | Work spanning multiple landings or sessions |
| adr | proposed, active, accepted, superseded, rejected, archived | A hard-to-reverse decision, surprising without context, with a real trade-off |
| research | draft, active, current, superseded, archived | Evidence consumed by a named plan or ADR |
| reference | active, current, superseded, archived | Current structure, ownership, or configuration |
| runbook | active, current, superseded, archived | Repeatable operational procedure |
| convention | active, current, superseded, archived | Durable rules across changes |
| index | active, current | Root index.md, inventory.md, or retired.md only |

Use an ADR only when all three criteria in the table apply. Describe a
single-landing change in its commit or PR; keep disposable experiments in
ignored scratch space. Plans link their ADRs in `related`, and ADRs link the
plans that prompted them. Research links the plans or ADRs consuming it.
Use Markdown-relative paths for these links.

`draft` is exploratory, `proposed` awaits review, `accepted` is approved
intent, `active` is underway, and `current` is steady-state guidance. Plans
never become `current`. A parked plan is `draft` with a `Parked:` reason in
`status_detail`. Drafts and parked work do not authorize execution.
Park waiting work as `draft` with a `Parked:` reason. Resume it when authorized.
Close abandoned plans as `rejected` when the user decides to stop the work.

`superseded`, `rejected`, and `archived` are closed. Superseded docs name a
`superseded_by` successor; archived docs name `current_guidance`; rejected
docs explain why via `status_detail` or `current_guidance`. Closed documents
retained in the tree need a `closed` date. There is no general status transition
graph, but closed docs cannot reopen and accepted ADRs can only stay accepted
or close. A plan can become a reference or runbook; other type changes use a
new document.

## Navigation and retirement

- `index.md` routes to current guidance and open plans without duplicating
  their status prose.
- `inventory.md` is generated from frontmatter and titles. Regenerate it after
  changing those inputs; validation rejects stale output.
- `retired.md` is an append-only ledger. Git retains retired bodies.

A non-ADR document leaves the tree when it closes. Move useful facts to their
durable home, repair editable incoming links, append a ledger row, and delete
the file in the same change. The row records closure; changing the deleted
file's frontmatter first is unnecessary. Plans close with their final step.
Research retires when all its consumers are accepted ADRs or closed plans and
cite the findings they used. Consumer links live in `related`.

Start the ledger with:

```markdown
---
status: current
doc_type: index
summary: "Retired documents and the durable homes of their content."
---

# Retirement Ledger

| Closed | Path | Doc | Status | Where it went |
| --- | --- | --- | --- | --- |
```

Each row uses a docs-relative path, a closed status, and a destination or an
explicit statement that nothing needed keeping. For example:

```markdown
| 2026-10-17 | plans/search-migration.md | Search migration | archived | [Search reference](references/search.md) |
```

Existing rows cannot change or disappear. Retired paths cannot reappear. Revived
work gets a new path and names the old path in a link to the ledger. Editable
docs repoint retired links; locked docs may retain them. The ledger's own links
may age because its rows are immutable. Recover a body with:

```sh
git log --diff-filter=D --oneline -- docs/plans/search-migration.md
git show <deletion-commit>^:docs/plans/search-migration.md
```

## ADR preservation

ADRs use `adr/NNNN-slug.md`. They remain forever, even withdrawn proposals,
which close as `rejected`. Numbers cannot be reused or renumbered.
Accepted ADR bodies are locked, including across intermediate branch commits.
Finish substantive body edits before acceptance. Frontmatter can change;
link-target repairs after detected moves are allowed. A superseded ADR may
also gain one matching line directly under its H1:

```markdown
> Superseded by [ADR 0002](0002-new-decision.md).
```

The banner must match `superseded_by`. Closing a document does not authorize
rewriting its historical body. Record a changed decision in a successor ADR.

## Mechanical checks and agent decisions

The validator checks frontmatter, type/status compatibility, local links,
inventory freshness, ledger deletions and immutability, retired path reuse,
ADR numbering, and historical body edits. Markdown is the default content
format; non-Markdown research data is allowed under `research/<topic>/data/`.
Keep generated captures outside the docs tree. Relative frontmatter links must
stay within the repo; locked docs may target ledger-listed retired paths.

The checker currently accepts closed non-ADR files in the current tree for
migration compatibility. Agents must still retire them under this policy.
Likewise, it cannot infer finished acceptance criteria, summary quality, or
whether research was consumed. Those decisions belong in the workflow.

Without a base ref, validation checks only the current tree. Use a real branch
base for history enforcement after adopting the schema. `--due` is advisory:
review old open/parked plans and research with missing or settled consumers;
never retire work solely because of its age.
