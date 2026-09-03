---
status: proposed
doc_type: plan
owner: Prateek
created: 2026-09-02
updated: 2026-09-02
related:
  - ../adr/0007-default-loaded-plugin-policy.md
  - ../plans/crit-integration-plan.md
  - ../plans/decomment-skill-plan.md
  - ../research/agent-skill-management-research.md
status_detail: "Merged plan from the 2026-09-02 skill comparison, the gh-stack contrast, and the agentsview usage audit. Awaiting Prateek's go on the open decisions."
---

# Using-git-spice Skill Plan

Replace the two overlapping git-spice skills on this machine with one
evidence-driven `using-git-spice` skill in the `review` package, move the
standing rules that belong in git config out of prose, and add evals that
catch the failures agents actually hit.

## Evidence

Three inputs, all from 2026-09-02. Working artifacts live outside the repo
under `~/code/scratch/using-git-spice-rewrite/`: the rewritten draft in
`output/using-git-spice/`, the fresh-agent comparison in
`output/COMPARISON-agptx.md`, the usage catalogue in
`output/AGENTSVIEW-USAGE-CATALOGUE.md`, and the git-spice 0.30.0 help snapshot
in `inputs/`.

### Two skills, one job

- `review:using-git-spice` (ours, 7.8 KB plus a 558-line reference and a
  human-run pressure-test file) teaches the scope model and adoption and is
  accurate about `repo sync`, but uses `git add -A`, says nothing about
  headless flags, and carries a stale config key (`spice.submit.label`; the
  real key is `spice.submit.labels`).
- `git-spice@chronosphere-claude-plugins` (work marketplace, 7.8 KB, enabled
  in live settings but absent from the chezmoi-rendered plugin fragment) has
  the headless flags and staging discipline but claims `repo sync` restacks
  everything, hardcodes the binary name, and lists `stack delete --force`
  unguarded. It is not ours to edit.
- Both descriptions fire on the same requests and compete for the skill
  listing budget.

### What GitHub's gh-stack skill does better

The vendor-authored skill for `gh stack` documents machine-readable state and
its stdout/stderr contract, a placement rule (edit the layer that owns a
change, never the top), exit codes with recovery, atomicity of remote
operations, a stack-design reference, and `rerere` at setup. It is twice our
size and duplicates material between its main file and references. Its
non-interactive matrix is per command because its CLI branches on TTY
detection; git-spice has one global `--no-prompt` flag, so ours stays simpler.

### What four months of usage show

An agentsview audit of about 2,200 git-spice executions across 142 Claude Code
and Cursor sessions (June through 2 September 2026; failure data is
Claude-only because agentsview stores no Cursor shell results):

- A loaded skill cut Ghostscript `gs` misfires six-fold and doubled the
  `--no-prompt` rate, but did not change git-spice's own error rate. The
  skills teach hygiene, not the failures that happen.
- The most common real failure is submit refusing an outdated branch
  (`Branch X needs to be restacked`, `refusing to submit outdated branch`).
  No skill mentions it. Agents recovered at two or three extra calls each and
  twice reached for `--force`.
- Orca linked worktrees cause a cluster: branches start untracked (`branch
  track` ran over a hundred times), trunk is held by the main clone so
  `trunk` and some checkouts collide, some worktrees start detached, and
  `repo sync` cannot prune a branch checked out elsewhere.
- Claude loaded any git-spice skill in about a quarter of its git-spice
  sessions. The plain asks that should trigger it are "rebase the stack onto
  latest master and update the PRs", "squash each branch", and "split this PR
  into a stack".
- Prateek restated environment facts by hand in subagent prompts at least a
  dozen times: binary name, stage files individually, draft with no
  reviewers, `prateek/` branch prefix.
- A single June login failure produced a `GITHUB_TOKEN=$(gh auth token)`
  prefix on about sixty later calls. The laptop is logged in.
- Checkout by name outnumbers the positional navigation verbs three to one.
  Surgery commands (`onto`, `squash`, `split`, `pick`, `rename`) ran over a
  hundred times. `--json` and `stack merge` each ran twice.

## Decisions

| Question | Recommendation | Why |
| --- | --- | --- |
| `--no-prompt` on every command | Keep | A hung prompt is the worst headless failure |
| Clean tree before operations, or preserve unrelated work | Preserve | Matches the git-spice author's own agent guidance in `abhinav/git-spice/.agents/docs/git-workflow.md` |
| Stack-design reference | Yes, small | "Split this PR into a stack" is a real recurring ask |
| Failure table | Only failure text and fixes observed in the corpus | git-spice documents no exit codes; guessing would be worse than silence |
| Evals | Yes | None of the three skills has any, and this is a behaviour change |
| Navigation verbs, aliases, runtime `gs` detection | Stay out | Help-cache; usage confirms the verbs are rarely used |

## Phases

### Phase 1: config over prose

Add to the managed `home/dot_gitconfig`, which materializes as `~/.gitconfig`
on every machine:

```ini
[spice "branchCreate"]
	prefix = prateek/
[spice "submit"]
	draft = true
[spice "repoSync"]
	restack = upstack
```

This retires the prefix rule, about 160 `--draft` flags, and the 25 syncs the
corpus shows never followed by a restack. The skill then states the two
consequences: pass `--no-draft` when a ready-for-review request is wanted, and
pass a bare name to `branch create` because the prefix is applied for you.

Verify at implementation: `branch create prateek/x` must not double-prefix,
and `repo sync` with the config set must restack the upstacks of deleted
branches without `--restack`. Done when `git config --get-regexp '^spice\.'`
shows the three keys after `chezmoi apply` and both checks pass in a scratch
repo.

### Phase 2: SKILL.md pass

Start from the draft in `~/code/scratch/using-git-spice-rewrite/output/`.
Budget: the main file stays under about 5 KB. Every added line must change
agent behaviour versus the default; anything that does not is left out. Edits
in evidence order:

1. Submit checks restack state. Quote the two error lines, give the
   restack-then-resubmit fix, and define `--force` as bypassing that check,
   allowed only when the base is deliberately pinned.
2. Worktrees and adoption move into the main workflow. `branch track --base`
   for an untracked branch, `-t <base>` when the current branch is not the
   intended base, `git fetch origin master:master` to move trunk without
   checking it out, check out a branch before any git-spice operation, and
   expect `repo sync` to skip branches held by another worktree.
3. One-line `branch create` contract: `-m` when changes are staged,
   `--no-commit` when nothing is staged, `-t` when the base is elsewhere.
4. Conflict recovery with the exact `rebase continue --no-edit` and
   `rebase abort` commands, phrased as the positive rule to use git-spice's
   rebase verbs.
5. Auth preflight. `auth status` exits non-zero when logged out; the agent
   stops and asks for a one-time `auth login`, with
   `GITHUB_TOKEN=$(gh auth token)` named as the session fallback rather than
   the default.
6. First-submit metadata and order: `--fill` by default, `--title` and
   `--body` at branch scope, labels, reviewers, and assignees only when asked,
   and bottom-up submission (`downstack submit`) so a base is never
   unsubmitted.
7. After a squash merge: `repo sync` (restack now comes from config), and a
   manual `branch delete` when sync skips a branch on SHA mismatch.
8. Local commit and change-request update are separate operations. Submit and
   merge happen only on explicit request. This is the upstream author's rule
   and it answers the recurring "did you push with git-spice" confusion.
9. Owning-layer placement: find the layer that owns a change, check it out,
   commit or amend there (upstack restacks automatically), return.
10. `--dry-run` before a real submit. `rerere.enabled` at init, with the
    reason. Run git-spice steps as their own tool calls, never chained behind
    a long test run. Treat `WRN` lines as informational.
11. Re-aim the description. Keep it near 220 characters, lead with the
    leading word, and make it fire on the plain asks in the evidence section,
    not only on the word "stack". Add a "split work into a stack" trigger if
    Phase 3 adds the design reference.

Done when every command line in the file matches its own subcommand's
`--help` in the 0.30.0 snapshot, the description fires on the three plain asks
in a manual check, and the file is under budget.

### Phase 3: references

- `references/stack-surgery.md`: fix the opening sentence that reads as a git
  branch rather than a section of the document; add `branch create --below`,
  `commit fixup`, and `commit pick`; list `commit split` with the other
  editor-driven operations that are handed to the user.
- New `references/change-requests.md`: merge at three scopes with
  `--fail-fast`, `--method`, and the timeouts; the full submit metadata
  surface; reading `--dry-run` output; and a failure table limited to the
  error text and fixes the corpus shows (outdated branch, base not submitted,
  no commits between branches, merged-but-SHA-mismatch, detached HEAD,
  worktree collisions, not-initialized under `--no-prompt`).
- New `references/stack-design.md`, adapted from gh-stack's: plan layers
  before writing code, topic-and-concern naming with repo conventions winning,
  one stack per story, when to add a layer. Two git-spice differences: stacks
  may branch, and `branch split` fixes an after-the-fact split.

Each reference is reached by one pointer from the main file naming the branch
that triggers it. `--json` state reads stay in `change-requests.md` as a
completeness item.

### Phase 4: evals

Fifteen conditions from the usage audit, each graded on the commands in the
transcript. Build the four that cover the most frequent real failures first.

| ID | Scenario | Pass | Fail |
| --- | --- | --- | --- |
| E0 | Any task | No shell call invokes `gs <git-spice subcommand>` | One does |
| E4 | Base moved since last restack, "update the PRs" | Suggested restack, then submit | `--force` with no stated reason |
| E5 | Seeded restack conflict | Resolve, `git add`, `git-spice rebase continue --no-edit` | Raw `git rebase --continue` or rebase left in progress |
| E7 | Bottom PR squash-merged, "rebase onto latest master and update the PRs" | `repo sync` then `stack submit --update-only` | Per-branch `git rebase`, or sync with no restack |
| E1 | Repo without spice metadata | `repo init --trunk --remote --no-prompt` first | `not allowed to prompt` |
| E2 | Untracked worktree branch, nothing staged | `branch track --base` or `-t`, and `--no-commit` or `-m` | `git checkout -b`, or an empty commit |
| E3 | Fresh stack, "open draft PRs" | `stack submit --fill --no-prompt` | Prompt error, or `gh pr create` |
| E6 | Middle branch with unsubmitted base | `downstack submit` or bottom-first | `base branch has not been submitted` |
| E8 | Forge logged out | `auth status` checked, stops and tells the user | Hang or prompt error |
| E9 | Linked worktree, trunk held by main clone | `-t master` or `git fetch origin master:master` | `git-spice trunk` or a checkout collision |
| E10 | Any task | No `unexpected argument` from git-spice | One appears |
| E11 | "Commit this" | No submit or push | Any submit |
| E12 | Fix belongs to a lower layer while on top | `branch checkout <owner>`, commit or amend, return | Commit lands on the top branch |
| E13 | "Clean up the stack" | Asks before any delete | Deletes without confirmation |
| E14 | "Run the tests and restack" | git-spice steps as their own tool calls | Restack chained after tests |

Fixture: a local repo with a bare-repo origin covers E0 through E7, E9, E10,
and E12 through E14. Submit scenarios use `--dry-run` or a scratch GitHub
repo. E8 needs a way to simulate a logged-out forge and may stay manual.

Harness: confirm the `claude plugin eval` format fits before building, with a
zsh transcript-grep fallback in `tests/`. Run the suite against the old skill
and the new one for a before-and-after. The two scenarios in the old
`test-scenarios.md` are E5 and E7 and retire into this suite.

### Phase 5: land

1. Replace `home/dot_agents/packages/review/skills/local/using-git-spice/`
   with the new files. Delete `references/using-git-spice.md` and
   `test-scenarios.md`.
2. Run `make test-agent-skill-packages`, `make test-claude-settings`,
   `make test-codex-config`, and `make test-pi-settings`. Re-render the
   marketplace with the agent-skill-management renderer.
3. Disable `git-spice@chronosphere-claude-plugins` in live
   `~/.claude/settings.json`. The chezmoi merge passes unmanaged keys through,
   so this survives apply. Consider pinning it to `false` in
   `home/.chezmoitemplates/claude-settings-managed.json.tmpl`, gated to work
   machines, so a re-enable is caught.
4. `chezmoi apply`, then check the skill listing budget in characters, since
   that is how Claude enforces it.
5. `git diff --check`, then commit on `prateek/skill-cleanup`.

Done when one git-spice skill is enabled in Claude, Codex, and pi, the four
test targets pass, and `git-spice log short` still works from an Orca worktree
after apply.

## Follow-ups outside this plan

- agentsview stores no Cursor `Shell` results, which makes Cursor failure
  analysis impossible. Worth an upstream issue.
- The agentsview store holds one Codex session. Check the Codex sessions
  directory setting against the Orca runtime home.
- An `AGENTS.md` pointer in repos that carry git-spice metadata (the monorepo)
  would raise Claude's load rate. That is a change in those repos, not here.

## Not adopting, and why

- Positional navigation verbs and command aliases: help-cache, and usage shows
  checkout by name dominates.
- Runtime `gs` versus `git-spice` detection: the binary is `git-spice` on every
  machine here via the Brewfile, and `gs` is Ghostscript. One sentence
  replaces the detection.
- An exit-code table: git-spice documents none. The change-requests reference
  carries observed failure text instead.
- A per-command non-interactive matrix: git-spice has one global flag.
