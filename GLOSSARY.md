# Dotfiles Vocabulary

The shared vocabulary for documentation, chezmoi source state, and the portable agent workflows maintained in this repo.

## Language

**Closed**:
A document whose `status` is terminal: `superseded`, `rejected`, or `archived`. Its body is history, not guidance.
_Avoid_: Done, finished, completed, dead

**Retired**:
A closed document whose file has been deleted from the tree, leaving only its retirement record and git history.
_Avoid_: Deleted, removed, purged, exited

**Router**:
The short, hand-maintained entry point that lists current guidance and open work and points at everything else.
_Avoid_: Index, table of contents, docs home

**Inventory**:
The generated listing of every document in the tree with its status, derived from frontmatter and never edited by hand.
_Avoid_: Index, catalogue, manifest

**Retirement ledger**:
The append-only record of every retired document: what it was, when it closed, and where its durable content went.
_Avoid_: Graveyard, archive list, changelog

**Evergreen**:
A document body that reads as written today by someone who knows only the current decisions, with each fact in one home; what changed, when, and who asked lives in Progress or the commit.
_Avoid_: Up to date, current, clean, final

**Accretion**:
The drift of a document revised in place over many turns: stale claims beside later decisions, review findings appended as caveats, history narrated in the body, and one rule stated in several places.
_Avoid_: Bloat, cruft, drift, rot

## Chezmoi source state

**`home/`**:
The chezmoi source directory. Every file under it materializes to the same path under `$HOME`.
_Avoid_: Dotfiles dir, source root

**Bootstrap**:
The one-time first install on a machine: the Xcode command line tools, then the chezmoi one-liner that clones the repo and runs init and apply together.
_Avoid_: Install script, setup

**`.chezmoidata/`**:
Committed structured desired state that templates and scripts read: package groups, machine layers, the agent catalogue, secret refs, license paths, and permission intent. It is never templated, and init cannot read it.

**`.chezmoiassets/`**:
Committed payloads that templates and modify scripts include byte for byte, never rendered as templates.

**`.chezmoiscripts/`**:
Chezmoi-owned side effects that run as part of apply: idempotent setup, ordered by numeric prefix, gated by once or onchange attributes.

**`.chezmoiexternal`**:
Chezmoi-owned acquisition of a dependency that is only a repository or archive, refreshed on its declared period. Preferred over a clone inside a script.

**Capture**:
A local observation of live machine state, such as an exported preference domain, a Mackup candidate list, or a TCC audit, written under XDG state. It never becomes desired state without a hand edit.
_Avoid_: Snapshot, export, dump

## Agent delegation

**Model shortcut**:
A stable name for a model family, capability tier, and thinking increment, resolved against the access available on a machine.
_Avoid_: Model ID, harness, fixed pin

## Agent conventions

**Ghost ledger**:
`GHOST_OF_COMMITS_PAST.md` at a repo root: committed entries, one per landing, listing checks on landed work whose result is still unknown.
_Avoid_: TODO list, handoff doc, progress log

**Ghost entry**:
One dated message in the ghost ledger, at most 100 words, written for the next agent: the checks to run and how each is known to be done.

**Ghost buffer**:
`GHOST_MESSAGE_BUFFER.md`, an ignored scratch file at the repo root where an agent accrues candidate checks while working; folded into one ghost entry at landing.

## Search selection

**Evidence area**:
The kind of evidence a request needs: web, code, social or shopping. It determines checks, not a mandatory platform.
_Avoid_: Provider, source

**Source**:
The site, platform or scoped collection supplying evidence, expressed as an alias or `site:hostname[/path]`. One source can serve several evidence areas.
_Avoid_: Search API, transport

**Source family**:
A group considered for a shared evidence purpose, such as owner forums, technical communities or institutional surplus. It guides selection without promising access.
_Avoid_: Required source list

**Search provider**:
An executable route with declared operations, source scope, access, cost and retention rules. Its method is API, native, host or browser; its upstream identifies the index or service behind it.
_Avoid_: Source, independent evidence

**Search facet**:
A bounded evidence question naming an area, source, operation, query or target, and required checks. Facets share one run's limits.
_Avoid_: Global source pin

**Source decision**:
A recorded host judgment selecting, deferring, excluding or finding a source family irrelevant, linked to facets where applicable. Execution outcomes and semantic usefulness are separate facts.
_Avoid_: Provider health, relevance score

**Search run**:
One logical search spanning query expansion, discovery, enrichment, content inspection and final selection within a shared budget.
_Avoid_: Provider call, query

**Candidate pool**:
The distinct candidates returned by discovery after canonical duplicate grouping, with their original observations preserved. Membership does not imply relevance or verification.
_Avoid_: Shortlist, recommendations

**Shortlist**:
The ordered candidates selected for the answer after assessing task fit, hard constraints and supporting evidence.
_Avoid_: Top hits, most popular results

**Search receipt**:
The compact account of a run's retrieval, inspection, selection, gaps and durable trace accompanying the answer.
_Avoid_: Quality score, success score
