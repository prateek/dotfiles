---
name: organize-important-documents
description: Design, review, and incrementally build a personal or family filing system for important documents and official records. Use when a user wants to organize or audit life-admin records, consolidate material from folders, scans, email, or cloud drives, choose a durable storage home and backup model, or set up a recurring maintenance routine. Also use when the user asks how to organize taxes, identity, immigration, health, insurance, housing, employment, education, legal, finance, travel, estate, or family records for themselves or someone else.
---

# Organize Important Documents

## Overview

Design or review a boring, durable filing system for important records. Start with discovery, work in small batches, and optimize for retrieval, privacy, backup, and maintenance rather than clever taxonomy.

## Default Stance

- Treat this as records management, not general digital decluttering.
- Separate official records from working material such as code, notes, drafts, datasets, exports, and creative projects.
- Prefer a single source of truth over trying to keep the same documents alive in many places.
- Prefer small, reversible changes. Do not rename or move large sets of files until the user agrees with the target structure.
- Inspect folder names and filenames first. Open document contents only when that is necessary and appropriate.

## Choose The Mode

Determine the starting mode before proposing structure:

- `design`: no coherent system exists yet
- `audit`: a system exists and needs review
- `migrate`: documents are scattered and need consolidation
- `maintain`: structure exists and needs upkeep rules

If several modes apply, start with `audit`, then move to `migrate` or `maintain`.

## Discovery Workflow

Ask questions in small batches. Start with what the user wants to track, not where it lives. Use [references/interview-checklist.md](references/interview-checklist.md) when you need more prompts or examples.

Apply these interview rules on every pass:

- Ask at most 4-5 questions at a time.
- Ask only must-have questions first. Prefer questions that eliminate whole branches of work.
- Keep questions short, numbered, and easy to scan.
- Offer defaults or examples when that reduces friction.
- Do not ask questions you can answer with a low-risk read of the provided material.
- After each batch, summarize what you learned, what is still missing, and whether the next step is more questions or filesystem inspection.

### Round 1: Scope

Clarify what the system must cover:

- What kinds of important information should this system track?
- Who is it for?
- Who else needs access now or in an emergency?
- Which categories are especially sensitive?
- Which physical originals still matter?

Do not ask about folder locations until you know the scope.

### Round 2: Current State

Once scope is clear, ask where the material currently lives:

- Local folders
- Downloads or Desktop
- Email attachments
- iCloud Drive, Google Drive, Dropbox, OneDrive
- Notes apps or phone scans
- Physical paper
- Old drives or shared family folders

Also ask what the user can provide access to right now so you can build an initial version incrementally.

### Round 3: Long-Term Home

Ask where the final source of truth should live. If the user is unsure, compare realistic options with [references/storage-and-backup-options.md](references/storage-and-backup-options.md).

You must settle:

- Primary storage home
- Backup approach
- Sharing model
- Whether some categories belong in separate storage

If the user does not know every answer yet, proceed with the known sources and make the plan explicitly incremental.

## Audit Existing Material

When the user provides an existing folder tree, inspect paths and filenames before proposing moves.

Prefer inspection over more questioning when a low-risk read can answer:

- how many categories already exist
- what the dominant file types are
- whether the root is overloaded
- whether duplicate names or generated junk are present

If local filesystem access is available, use:

- `scripts/inventory_tree.py` to summarize folder depth, counts, and sizes
- `scripts/extension_summary.py` to understand file-type mix
- `scripts/duplicate_name_report.py` to surface duplicate basenames

Use these reports to identify:

- Good domain-based groupings worth preserving
- Overloaded roots
- Mixed official records and working material
- Inconsistent date and filename conventions
- Hidden junk or generated artifacts
- Duplicate names that will complicate migration

## Design Rules

Use these rules unless the user has a strong reason not to:

- Keep the root narrow and domain-based.
- Group by life domain first, then by case, provider, or year.
- Include an inbox for unsorted material.
- Include an archive area for closed or historical cases.
- Standardize on ISO dates in filenames: `YYYY-MM-DD`.
- Prefer final PDFs, scans, and signed copies in the records system.
- Keep drafts, exports, scripts, and scratch work outside the records system unless they are part of an active case folder and clearly labeled.
- Make the structure understandable to another person, not just the owner.

Use [references/category-patterns.md](references/category-patterns.md) for common top-level structures and category-specific advice.

## Exclusions

Call out what does not belong in the filing system. Common exclusions:

- Source code and git repositories
- School notes and class materials
- Creative writing and media libraries
- Build artifacts and package caches
- App exports or raw data dumps kept only for convenience
- Random downloads with no record-keeping value

## Produce The Output Package

After discovery and any local inspection, return a concrete package with these sections:

1. `Current state`
   Summarize what exists, where it lives, and the main risks.
2. `Proposed folder layout`
   Show the root tree and important subfolders.
3. `Naming convention`
   Give filename rules and examples.
4. `Migration plan`
   Map current sources into target folders.
5. `Maintenance plan`
   Split into manual tasks and LLM-assisted tasks.
6. `Backup and privacy notes`
   State source of truth, backup model, sharing, and sensitive-category handling.
7. `V1 next steps`
   Give the smallest useful checklist.

## Maintenance Guidance

Keep the upkeep plan light enough that the user will actually follow it. Use [references/maintenance-cadence.md](references/maintenance-cadence.md) when you need a default cadence.

Always distinguish:

- What the user should do manually
- What the user can ask an LLM to help with regularly
- What should only happen when explicitly prompted

Good LLM-assisted tasks:

- Propose filenames for newly downloaded documents
- Classify documents into likely folders
- Draft migration plans from messy sources
- Summarize missing paperwork for a case
- Identify duplicate or suspiciously misplaced files
- Review a folder tree for naming drift and category drift

## Safety And Consent

- Do not move or rename files without confirming the plan when working on a real filesystem.
- Do not assume a cloud service is acceptable if the user has privacy or family-sharing constraints.
- Do not ask the user to centralize everything into a single shared location if some categories need stricter access.
- Treat health, legal, immigration, identity, and finance documents as sensitive by default.

## References

Read only what you need:

- Use [references/interview-checklist.md](references/interview-checklist.md) for question batches and discovery prompts.
- Use [references/category-patterns.md](references/category-patterns.md) for folder layout patterns and exclusions.
- Use [references/storage-and-backup-options.md](references/storage-and-backup-options.md) when the storage home or backup plan is undecided.
- Use [references/maintenance-cadence.md](references/maintenance-cadence.md) when drafting the upkeep plan.
