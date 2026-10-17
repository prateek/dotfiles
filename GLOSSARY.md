# Dotfiles Documentation

The lifecycle vocabulary for Markdown documents under `docs/` in this repo: how a document is classified, when it stops being guidance, and what remains once it is gone.

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
