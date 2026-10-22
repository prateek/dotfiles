# Review lens

`--review <ref|PR>` reads a change through its history. Review panels can
point a reviewer here in one line: "apply the lore review lens to `<ref>`".

## Scope

Resolve the change without touching the worktree: `git diff <base>...<head>`,
`git show <sha>`, or `gh pr diff <n>`. Read the PR body and existing review
threads first so findings do not repeat them.

## Questions per touched hunk

1. **Why does the code look like this today?** Run the repo anchor recipe on
   the base revision's lines that the change edits or deletes, naming the base
   in each command (`git blame <base> -L <start>,<end> -- <file>`,
   `git log <base> -L <start>,<end>:<file> --no-patch --oneline`). Line numbers
   come from the diff's base side.
2. **Does the change undo a deliberate choice?** A removed guard, constant,
   field, or branch that an earlier PR or discussion justified is the
   highest-value finding.
3. **Does it collide with work in flight?** Open PRs touching the same paths
   or symbols, and recent reverts of similar changes.
4. **Does it drift from local precedent?** Naming, error handling, config
   shape, and rollout practice compared with how the repo did the same thing
   before.
5. **Do the surrounding comments and docs still hold?** A comment whose
   rationale the change invalidates.

Search `team` and `agents` with the PR's terms and the touched symbols when
the repo record leaves a question open; read-only always, including chat.

## Findings

Each finding carries `file:line`, the historical evidence with its tier and
citation, a concrete consequence (what breaks, regresses, or re-opens), and
whether it reads as an oversight or a possibly deliberate departure the
author should confirm. End with sources checked. Report nothing rather than
pad: an empty lens with its sources listed is a valid result.
