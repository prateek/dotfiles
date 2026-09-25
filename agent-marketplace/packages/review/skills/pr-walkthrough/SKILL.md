---
name: pr-walkthrough
description: Walk a reader through a pull request, branch, or set of changes as if they were a senior engineer with no context on the work. Produces a Markdown document with the code flow before the change (snippets and a diagram), the problem substantiated with real evidence, then each change and why it fixes the problem. Use when asked to "walk me through" or "give me a tour of" a PR or branch, to explain a change to someone who was not there, or to understand what a branch does before reviewing it. Not for writing PR descriptions, reviews, or crit stories.
---

# PR Walkthrough

Write for a senior engineer you respect who has no context on this work and
little time. They should get the shape of the change from the summary alone,
then be able to dig into any part and check it against the code.

## Output

One Markdown file at `~/code/scratch/YYYY-MM-DD-<slug>/walkthrough.md`, where
the date is today and the slug is one to three words for the change. Create
the directory. Report the path when done.

Post nothing anywhere unless the user asks. On request, attach the document or
its images to the PR with the `github-attachments` skill, or author a
`crit story` as a companion diff tour.

## Steps

1. Establish scope. Identify the PR, branch, or range and its base. Read the
   commit messages, the full diff, and any linked issue, incident, or thread.
   Write down the problem the change claims to solve, in one sentence.
2. Trace the flow before the change. Follow the request or data path through
   the base revision, quoting snippets with `git show <base>:<path>` and
   citing `path:line`. When the flow has more than two hops, add one Mermaid
   sequence or flowchart diagram. Fewer hops need no diagram.
3. Substantiate the problem. Collect the evidence that shows the problem is
   real: measurements, traces, flamegraphs, screenshots, incident timelines.
   Apply the evidence rules below.
4. Explain the changes. Cluster hunks by theme, not by file. For each theme:
   what changed, the after-snippet, why it fixes the problem, and what it does
   not cover. Repeat the diagram with the change applied only when the shape
   of the flow changed.
5. State risk and verification. How the change rolls out, how it rolls back,
   and what to watch to know it worked.
6. Write the summary last and put it first: three to five sentences the reader
   can check at a glance, followed by a tl;dr list of the themes.

## Evidence rules

- Snippets always come from the actual revisions, with `path:line`
  references. Never paraphrase code as if quoting it.
- Include captures (screenshots, traces, flamegraphs) only when the change
  claims a performance or behavior difference. Take them yourself or link the
  originals from the PR, issue, dashboard, or thread.
- Every number carries its source. A number you did not measure or link is
  not evidence; leave it out or mark it as the author's claim.
- When proof is missing, say what would prove the point and ask for it. Do not
  invent, estimate, or reconstruct evidence.

## Document shape

```md
# <Change title>

<Summary: 3-5 sentences.>

tl;dr
- <theme 1>
- <theme 2>

## Before
<flow with snippets; diagram if more than two hops>

## The problem
<evidence, each item with its source>

## The changes
### <theme 1>
<what, after-snippet, why it fixes it, what it does not cover>

## Risk and verification
<rollout, rollback, what to watch>
```

## Completion

- Every snippet cites `path:line` from a real revision.
- Every number and capture has a source, or is marked as unverified.
- A diagram appears only where the flow has more than two hops.
- The summary stands alone.
- The file path was reported and nothing was posted without a request.
