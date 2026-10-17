---
status: current
doc_type: index
summary: "Append-only record of every retired document: what it was, when it closed, and where its durable content went."
created: 2026-10-17
related:
  - document-lifecycle.md
  - inventory.md
---

# Retirement Ledger

A retired document is a closed document whose file has left the tree. This
ledger is the only in-tree record that it existed. Rows are append-only: the
validator refuses a change that edits or removes one, and a path listed here
cannot come back; revived work gets a new file that links this ledger.

To read a retired document, use git:

```sh
git log --diff-filter=D --oneline -- docs/<path>
git show <commit>^:docs/<path>
```

Add a row in the same change that deletes the file. `Where it went` names the
reference, runbook, ADR, or skill that now holds anything durable, or says
there was nothing to keep. Links in that column may point at paths that have
since retired themselves.

| Closed | Path | Doc | Status | Where it went |
| --- | --- | --- | --- | --- |
