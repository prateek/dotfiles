---
status: proposed
doc_type: plan
owner: Prateek
created: 2026-09-26
updated: 2026-09-26
related:
  - ../../home/dot_agents/docs/books.md
status_detail: "Pending proposal and TODO backlog; archive and tool implementation have not started."
---

# Self-help and psychology book archive and agent tools

Archive all of our self-help and psychology books, extract their useful
lessons with source references, and turn those lessons into agent workflows
and tools that help us learn and apply them in daily life.

## Pending work

- [ ] Inventory the full collection, including physical books, ebooks,
  highlights, and existing notes. Track title, author, edition, ISBN, available
  formats, and missing digital copies.
- [ ] Choose a private archive location, backup and restore process, and
  ownership before moving files. Keep book binaries outside the dotfiles
  repository; preserve originals, checksums, and acquisition metadata.
- [ ] Ingest and deduplicate books by edition. Verify readable text and
  distinguish complete books from samples; preserve page or chapter anchors
  for retrieval and citations.
- [ ] Build a searchable knowledge base of concepts, exercises, and practical
  strategies. Record each strategy's source, intended situation, steps, and
  limitations; distinguish book claims, supporting research, and our own
  observations. Retain disagreements between sources.
- [ ] Prototype agentic implementations of selected lessons: habit planning,
  task initiation and breakdown, structured reflection, and spaced practice.
  Give each tool a clear trigger, concrete action, source references, and a
  way to record user feedback and outcomes.
- [ ] Pilot a small set of tools in daily use, evaluate usefulness and
  interruption burden, and refine or retire them based on results. Explore
  the focus pet as one possible consumer.
- [ ] Decide the implementation repository, agent interfaces, and first
  delivery milestone when this proposal is picked up.

## Starting point

The ADHD reading-list downloads under `~/Downloads/ADHD-Books-2026/` are an
initial ingestion candidate, not the full collection or a durable archive.
Reconcile that directory's `README.md` and `manifest.json`, including pending
books and the separately labeled sample, before importing it. Follow the
[book retrieval workflow](../../home/dot_agents/docs/books.md) for acquisition.

The first pilot should demonstrate a restored book, retrieval to a specific
source passage, and a useful agent workflow derived from that source with
recorded feedback.
