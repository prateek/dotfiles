---
status: active
doc_type: plan
owner: Prateek
created: 2026-09-02
updated: 2026-09-03
related:
  - ../adr/0007-default-loaded-plugin-policy.md
  - ../plans/crit-integration-plan.md
  - ../plans/decomment-skill-plan.md
  - ../research/agent-skill-management-research.md
status_detail: "Replacement skill and config applied, duplicate disabled, and Orca smoke passed; only the disruptive manual E8 logged-out auth check remains."
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
in `inputs/`. The 2026-09-03 acpx matrix, dual-agent grades, and human-review
HTML are under `eval-workspace/acpx-agpt-aopus-2026-09-03/`.

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

An agentsview audit of 2,185 git-spice executions across 142 Claude Code and
Cursor sessions (June through 2 September 2026). Cursor supplied command-shape
data for 1,323 executions but no shell results; the failure taxonomy therefore
covers the remaining 862 Claude executions, 39% of the corpus. Skill-loaded
sessions also skew toward harder work, so comparisons by skill load are
confounded:

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
| `--no-prompt` on every command | Keep | Cheap insurance when a harness allocates a PTY; it does not suppress editors, so commands still need `-m`, `--no-edit`, or `--fill` |
| Clean tree before operations, or preserve unrelated work | Preserve | Matches the git-spice author's own agent guidance in `abhinav/git-spice/.agents/docs/git-workflow.md` |
| Scope the Git config | Machine-wide | These are Prateek's defaults in every git-spice repo; repo-local config can override an exception |
| Stack-design reference | Yes, small | "Split this PR into a stack" is a real recurring ask |
| Failure table | Only failure text and fixes observed in the corpus | git-spice documents no exit codes; guessing would be worse than silence |
| Evals | Hermetic local suite plus opt-in forge suite | Local fixtures cannot reach submit behavior; networked evals need a named scratch forge repository |
| Main-file budget | About 5 KB | Keep common workflow in the main file; move remote and low-frequency recovery into triggered references |
| Disable rebase-continue editors | Yes, in Git config | `rebase continue` is common and an editor is the confirmed headless hang path |
| Experimental commit operations | Enable fixup and pick | Both commands are gated in 0.30.0; they provide stack-aware downstack fixup and cherry-pick operations |
| Navigation verbs, aliases, runtime `gs` detection | Stay out | Help-cache; usage confirms the verbs are rarely used |

## Phases

### Phase 1: config over prose

Add to the managed `home/dot_gitconfig`, which materializes as `~/.gitconfig`
on every machine:

```ini
[rerere]
	enabled = true
[spice "branchCreate"]
	prefix = prateek/
[spice "submit"]
	draft = true
[spice "repoSync"]
	restack = upstack
[spice "rebaseContinue"]
	edit = false
[spice "experiment"]
	commitFixup = true
	commitPick = true
```

The prefix applies to `branch create`, not every naming command. The skill
passes a bare name to `branch create`, strips a leading `prateek/` supplied by
the user, and passes explicitly prefixed names to `branch split` and
`branch rename`, which do not apply the create prefix. The draft default
applies to newly created change requests;
pass `--no-draft` when the user asks for ready-for-review. Verify against a
real ready change request that an update without an explicit draft flag does
not return it to draft.

`spice.repoSync.restack = upstack` restacks descendants of branches that sync
merges or deletes. It does not restack a stack merely because trunk advanced.
The skill retains an explicit restack step for that case. `rerere.enabled` and
`spice.rebaseContinue.edit = false` move recurring conflict behavior out of
agent prose and prevent a continue operation from opening an editor. Git-spice
0.30.0 gates `commit fixup` and `commit pick`; the experiment keys make the
documented owning-layer and commit-move workflows executable.

Implement and test the config source in this phase, but deploy the prefix and
draft defaults with the replacement skill in Phase 5. Before deployment:

1. In an isolated local config, verify bare and already-prefixed
   `branch create` inputs plus the unprefixed behavior of `branch split` and
   `branch rename`.
2. Verify that sync restacks the upstack of a merged or deleted branch, and
   that a trunk-only advance still leaves a visible `(needs restack)` state
   until an explicit restack.
3. In a scratch forge repository chosen by Prateek, open a draft change
   request, mark it ready, then run an update with the draft config set and
   confirm that it stays ready.
4. Preview `~/.gitconfig` with worktree-scoped `chezmoi diff` and
   `apply --dry-run`; do not apply it live before the new skill is ready.

Done when the local checks pass, the real change-request check confirms the
draft behavior, and rendered config contains the seven intended keys.

### Phase 2: SKILL.md pass

Start from the draft in `~/code/scratch/using-git-spice-rewrite/output/`.
Budget: the main file stays under about 5 KB. Every added line must change
agent behaviour versus the default; anything that does not is left out. Edits
in evidence order:

1. Worktrees and adoption move into the main workflow. Use
   `branch track --base` for an untracked branch and `-t <base>` when the
   current branch is not the intended base. Check out a branch before a
   git-spice operation that requires one. Use `repo sync` to advance trunk
   from a linked worktree; Git refuses `git fetch origin master:master` when
   another worktree holds `master`. Expect sync to skip deletion of branches
   held by another worktree.
2. One-line `branch create` contract: `-m` when changes are staged,
   `--no-commit` when nothing is staged, and `-t` when the base is elsewhere.
   Pass a bare branch name because config adds `prateek/`; strip that prefix
   from user input before invoking create. Pass explicitly prefixed names to
   split and rename; the create prefix does not apply to them.
3. Submit checks restack state. Quote the two observed error lines, give the
   restack-then-resubmit fix, and describe `--force` accurately: it
   force-pushes and bypasses safety checks, not only the restack check. Use it
   only on explicit request after verifying the remote and deliberately
   pinned base.
4. Conflict recovery uses the exact `rebase continue --no-edit` and
   `rebase abort` commands, phrased as the positive rule to use git-spice's
   rebase verbs. Keep explicit editor-suppression flags even though config
   supplies a fallback.
5. Keep only the common first-submit rule in the main file: use `--fill`,
   submit bottom-up with `downstack submit` when a base is unsubmitted, and
   add labels, reviewers, or assignees only when asked. Move auth diagnosis,
   full metadata, `--dry-run`, merge, warning, and remote-failure details to
   `references/change-requests.md`.
6. After sync, inspect `log short` for `(needs restack)`. A trunk-only advance
   still needs an explicit `upstack restack` or `stack restack`; the config
   handles only descendants of branches sync merges or deletes. After a
   squash merge, delete a merged branch manually when sync skips it on SHA
   mismatch, then restack the surviving upstack.
7. Local commit and change-request update are separate operations. Submit and
   merge happen only on explicit request. This is the upstream author's rule
   and answers the recurring "did you push with git-spice" confusion.
8. Owning-layer placement: find the layer that owns a change and work in that
   branch or its existing worktree. `commit fixup` can rewrite a reachable
   downstack commit only when another worktree does not hold its branch. When
   the owner is held, amend it in that worktree, then restack each skipped
   descendant from its own worktree instead of committing on the top branch.
9. Run git-spice steps as their own tool calls, never chained behind a long
   test run.
10. Re-aim the description. Keep it near 220 characters, lead with the
    leading word, and make it fire on the plain asks in the evidence section,
    including splitting work into a stack.

Done when every command line in the file matches its own subcommand's
`--help` in the 0.30.0 snapshot, the description fires on the three plain asks
in a manual check, and the file is under budget. The main file does not absorb
low-frequency material merely to satisfy reference completeness.

### Phase 3: references

First extend the 0.30.0 snapshot with dedicated help for every command cited
here, including `branch merge`, `downstack merge`, `downstack restack`,
`commit fixup`, and `commit pick`. Attribute flags only to the scopes whose
own help documents them.

- `references/stack-surgery.md`: fix the opening sentence that reads as a git
  branch rather than a section of the document; add `branch create --below`,
  `commit fixup`, and `commit pick`; list `commit split` with the other
  editor-driven operations that are handed to the user.
- New `references/change-requests.md`: merge behavior at branch, downstack,
  and stack scope, with `--fail-fast`, `--method`, and timeouts only where
  supported; the full submit metadata surface; auth preflight and the
  session-only token fallback; reading `--dry-run` output; the full
  force-push and safety-bypass meaning of `--force`; harmless `WRN` handling;
  and a failure table limited to observed error text and fixes (outdated
  branch, base not submitted, no commits between branches,
  merged-but-SHA-mismatch, detached HEAD, worktree collisions, and
  not-initialized under `--no-prompt`).
- New `references/stack-design.md`, adapted from gh-stack's: plan layers
  before writing code, topic-and-concern naming with repo conventions winning,
  one stack per story, when to add a layer. Two git-spice differences: stacks
  may branch, and `branch split` fixes an after-the-fact split.

Each reference is reached by one pointer from the main file naming the branch
that triggers it. `--json` state reads stay in `change-requests.md` as a
completeness item.

### Phase 4: evals

Keep the fifteen conditions from the usage audit, each graded on transcript
commands and observable end state. Store them with the skill using the repo's
existing `evals/evals.json`, `evals/forge-evals.json`,
`evals/setup_fixture.sh`, `evals/baselines/`, and `agents/openai.yaml`
convention. Use `scripts/eval-review.py` for human review.

The required hermetic suite is E0, E1, E2, E5, E9, E10, E11, E12, E13, and
E14. E3, E4, E6, and E7 form an opt-in forge suite against the private
`prateek/git-spice-evals` repository; they do not run in ordinary CI. E8 stays
manual because logging out cannot be isolated safely from the machine
credential. Build E0 and E5 first locally, then E4 and E7.

| ID | Scenario | Pass | Fail |
| --- | --- | --- | --- |
| E0 | Any task | No shell call invokes `gs` as a git-spice candidate | One does |
| E4 | Base moved since last restack, "update the PRs" | Restack, preview, then submit | `--force` with no stated reason |
| E5 | Seeded restack conflict | Resolve, `git add`, `git-spice rebase continue --no-edit` | Raw `git rebase --continue` or rebase left in progress |
| E7 | Bottom PR squash-merged, "rebase onto latest master and update the PRs" | Sync, explicitly restack if needed, preview, then submit the smallest scope covering every survivor | Per-branch `git rebase`, submission while stale, or sync treated as an unconditional restack |
| E1 | Repo without spice metadata and ambiguous trunk | `repo init --trunk --remote --no-prompt` before any other git-spice command | `not allowed to prompt` |
| E2 | Untracked worktree branch, nothing staged | `branch track --base` or `-t`, and `--no-commit` | `git checkout -b`, an editor abort/hang, or `-m` creating an empty commit |
| E3 | Fresh stack, "open draft PRs" | Preview, then submit the smallest scope covering the stack with `--fill --no-prompt` | Prompt error, or `gh pr create` |
| E6 | Middle branch with unsubmitted base | `downstack submit` or bottom-first | `base branch has not been submitted` |
| E8 | Forge logged out | `auth status` checked, stops and tells the user | Hang or prompt error |
| E9 | Linked worktree, trunk held by main clone | `-t master` or `git-spice repo sync` | `git-spice trunk`, `git fetch origin master:master`, or a checkout collision |
| E10 | Any task | No `unexpected argument` from git-spice | One appears |
| E11 | "Commit this" | No submit or push | Any submit |
| E12 | Fix belongs to a lower layer while on top | Amend in the owning worktree, then restack the held descendant from its worktree | Commit lands on the top branch or fixup collides with the held owner |
| E13 | "Clean up the stack" | Asks before any rewrite | Rewrites without clarification |
| E14 | "Run the tests and restack" | git-spice steps as their own tool calls | Restack chained after tests |

The local fixture uses a bare origin only for Git topology; a file remote
cannot exercise submit, even with `--dry-run`. Give each run an isolated
`GIT_CONFIG_GLOBAL` and set the intended `spice.*` values explicitly in the
fixture so the live machine config cannot leak into results. E1 must make
trunk ambiguous rather than relying on a one-branch repo that auto-initializes.

The forge fixture creates unique branches, records cleanup metadata, owns
change-request cleanup, and checks auth preconditions. Run old and new skills
with the same explicit fixture config when measuring skill behavior; report a
separate target-bundle smoke test for the new skill plus managed config. The
two scenarios in the old `test-scenarios.md` are E5 and E7 and retire into
this suite.

### Phase 5: land

1. Replace `home/dot_agents/packages/review/skills/local/using-git-spice/`
   with the new files. Delete `references/using-git-spice.md` and
   `test-scenarios.md`.
2. Pin `git-spice@chronosphere-claude-plugins` to `false` in
   `home/.chezmoitemplates/claude-settings-managed.json.tmpl`, gated to work
   machines. Do not rely on a live-only settings edit that another machine or
   settings reset can lose.
3. Validate package source with `validate-agent-packages`, render to an
   explicit temporary plugins root, and run the renderer's `--check` mode
   against that root. Run `make test-agent-skill-packages`,
   `make test-claude-settings`, `make test-codex-config`,
   `make test-pi-settings`, and `make test-docs-lifecycle`.
4. Preview the worktree source with `chezmoi diff` and
   `chezmoi apply --dry-run --verbose --exclude=scripts`. After the Phase 1
   forge check passes, apply the config, skill, and managed plugin disable
   together.
5. Check the rendered skill-listing budget in characters, then verify
   `git-spice log short` from an Orca worktree.
6. Run `git diff --check`. When Prateek asks to land, commit on
   `prateek/using-git-spice-skill` through the repo's local landing workflow.

Done when the canonical skill is available to Claude, Codex, and pi, the
Chronosphere duplicate is disabled in Claude, all validation passes, and the
Orca-worktree smoke test succeeds after apply.

## Progress

Source changes for all five phases are prepared. Local probes verified naming,
sync/restack behavior, every hermetic fixture's executable path, the two
experimental command gates, and held-worktree collision recovery. In the
private forge fixture, draft-config updates preserved ready status, bottom-up
submission worked, stale submission refused until restacked, and squash-merge
sync retargeted and updated the surviving change request. Package, settings,
docs, and `ci`, `personal`, and `work` chezmoi checks pass.

A one-run E0/E5 comparative pilot scored no skill 0/2, the previous local
skill 0/2, the Chronosphere skill 1/2, and the replacement 2/2. The pilot
caught real discriminators: `gs` probing, shell-local `$SPICE` state, raw
rebase continuation, and missing editor-suppression flags.

The full acpx comparison ran 112 primary cells (four instruction arms, fourteen
runnable scenarios, and both `agpt` and `aopus`) plus ten targeted replacement
repeats. Both agents independently graded transcript commands and before/after
state. Strict primary scenario passes were 2/28 with no skill, 6/28 with the
previous local skill, 10/28 with the Chronosphere skill, and 21/28 with the
replacement. E3 incorrectly requires `stack submit`: all four replacement runs
used the smaller `downstack submit` scope and still previewed and opened both
draft change requests bottom-up. Counting that equivalent behavior yields
23/28 for the replacement.

The repeats found three skill corrections. Both agents probed `git-spice log`
before initialization in both E1 runs and triggered headless trunk prompting.
`agpt` skipped the remote reference and therefore submit preview in both E4 and
E7 runs, while `aopus` loaded it and previewed. `agpt` also rewrote the stack
instead of asking what ambiguous E13 cleanup meant in both runs. E3 and E7 needed
scope-neutral assertions that accept the smallest command scope covering every
intended branch. Full evidence is in
`~/code/scratch/using-git-spice-rewrite/eval-workspace/acpx-agpt-aopus-2026-09-03/RESULTS.md`.

Those corrections are now implemented. The main workflow checks
`refs/spice/data` before any git-spice command, requires submit previews inline,
and asks before an ambiguous rewrite. E1, E3, E4, E7, and E13 then passed for
both agents: 10/10 post-fix runs and 48/48 graded expectations with no judge
disagreement. The post-fix artifacts are under
`~/code/scratch/using-git-spice-rewrite/eval-workspace/acpx-agpt-aopus-postfix-2026-09-03/`.

The live apply deployed the seven Git defaults, replacement package, generated
plugin, and managed Chronosphere-plugin disable together. A fresh Claude process
in the Orca worktree invoked `review:using-git-spice` from the rendered
`~/.agents/plugins/plugins/review/` tree, ran `git-spice log short`, diagnosed
the untracked current branch without rewriting it, and left the worktree clean.
Only the disruptive manual E8 logged-out auth case remains.

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
