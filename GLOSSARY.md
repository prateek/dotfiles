# Dotfiles Documentation

The shared vocabulary for this repo: how a Markdown document under `docs/` is classified, when it stops being guidance, and what remains once it is gone; and the chezmoi source state that materializes into `$HOME`.

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
