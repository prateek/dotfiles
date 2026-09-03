# Crit Conventions (Skill-like)

## Purpose

Machine-specific notes for `crit`, the inline review tool. General crit
mechanics live in the vendored `crit` and `crit-cli` skills; this file covers
only what is true because of *this* setup and would be wrong to send upstream.

## Where the review opens

`open_cmd` in `~/.crit.config.json` points at `~/.local/bin/crit-open`, which
puts the review in a browser tab inside the current Orca worktree instead of
the OS default browser. The default handler here is the managed enterprise
browser, so an unredirected review lands in the wrong app.

- The opener reuses this worktree's existing Crit tab, so repeated rounds
  re-navigate one tab rather than stacking a new one per round.
- Outside an Orca worktree, or with the Orca runtime down, it exits non-zero and
  crit falls back to the default browser. That fallback is deliberate: never
  make the opener swallow an error, or a dead runtime means no review at all.
- `notify_on_round_ready` is on, so a finished round announces itself instead of
  stealing focus.
- Both keys are global-only by crit's design; a project `.crit.config.json`
  cannot set them. They are managed by
  `home/modify_private_dot_crit.config.json.tmpl` and only on machines that have
  the Orca cask and are not the headless Linux profile.

## Stacked branches

**crit has no git-spice awareness.** It resolves the base from `origin/HEAD` and
a merge-base, so on a stacked branch it diffs against trunk and shows the whole
stack instead of the layer under review. Nothing in crit reads git-spice state.

Resolve the parent yourself and pass it:

```bash
base=$(git cat-file -p "refs/spice/data:branches/$(git branch --show-current)" | jq -r .base.name)
crit --base-branch "$base"
```

Branches git-spice does not track have no `refs/spice/data:branches/<name>`
entry, and the command fails; fall back to bare `crit` there.

For a PR review, `--scope layer` (the default) shows only that layer and
`--scope full-stack` shows the whole stack. `--scope` is ignored with `--range`,
where an explicit `base..head` is the only control.

State the base you are diffing against when you hand over a review URL. Getting
this wrong is the single most common reason a crit review shows changes the
reviewer did not expect.

## Local deltas to the vendored skills

The `crit` and `crit-cli` skills in the `review` package carry local edits kept
as upstream-shaped git patches under
`home/dot_agents/packages/review/patches/<skill>/`. They are re-applied
automatically during re-vendor by `apply-vendor-patches` and verified in CI by
`make test-vendor-skill-patches`.

Each patch is written against upstream paths so the same file opens as a pull
request without editing. When one lands upstream, delete it rather than
carrying it.

## Behavioural evals

`home/dot_agents/packages/review/evals/` holds four cases, one per failure mode
this setup was built to stop: comment visibility, diff scope, review target, and
CLI shape. They are synthetic — a throwaway repo and an invented PR number — so
nothing from a work repo is in them.

`make test-crit-evals` runs them with the report kept local. It is on-demand,
not per-PR: it costs tokens and needs network. Run it after re-vendoring or
after changing the crit skills.

`claude plugin eval` is currently gated behind early access, so the target skips
with a message rather than failing. The cases are written and ready for the day
it opens up.

## Version skew to expect

The binary tracks Homebrew stable; the skills track upstream `main` through apm.
They can disagree. Trust the binary's `--help` over the skill text, and fix the
skill with a patch when they diverge.
