---
status: accepted
doc_type: adr
created: 2026-07-03
updated: 2026-07-04
owner: Prateek
related:
  - ../plans/downstream-fork-plan.md
  - 0001-downstream-fork-architecture.md
  - 0014-tartelet-self-hosted-runners.md
  - ../../.agents/skills/fork-lifecycle/SKILL.md
status_detail: "Supersedes ADR 0001. The Amendment below is the current operating shape; the pre-amendment Decision records how it started."
---

# ADR 0015 — Downstream forks as thin assembly repos

> **The [Amendment](#amendment-2026-07-04--fleet-monorepo) below revises the
> Decision.** The core stands: thin assembly repos, the Go engine,
> deterministic assembly, brew install. What changed: the fleet moved into one
> monorepo that is also the tap, the workflow split into three jobs so
> untrusted upstream code never shares a runner with credentials, CI stopped
> reading 1Password, and the dotfiles lifecycle became manual. Read the
> amendment as the current design; it flags each section it supersedes.

Supersedes [ADR 0001](0001-downstream-fork-architecture.md) (clone-as-base
fork repos with `Fork-Patch:` commit trailers, Mergify-gated sync PRs, and a
three-workflow cruise-control loop).

## Context

The goal narrowed. ADR 0001 designed a general-purpose fork factory; what
Prateek actually runs day to day is **upstream + his own open PRs, plus an
occasional local-only patch**, as installed macOS apps and CLIs. Every
divergence from upstream is expected to be temporary: it either merges
upstream or gets dropped. The design target is therefore near-zero
maintenance while the PRs are open, and automatic self-destruction when
they land.

ADR 0001's clone-as-base model spent most of its complexity budget on
problems that only exist because the fork repo vendors upstream's tree:
scaffolding/namespace collisions, force-push discipline, sync branches with
PR ceremony and Mergify, patch-trailer bookkeeping, repo size. None of that
serves the narrowed goal.

## Decision

A fork repo is a **thin assembly repo**. It contains intent, not upstream
code:

- `.fork/fork.toml` — pinned upstream sha, tracked upstream PR numbers (or
  an author to auto-discover), build/smoke commands, release kind.
- `patches/*.patch` — local-only changes as `git format-patch` files.
- `rerere/` — committed conflict resolutions, replayed on later syncs.
- `.fork/engine/` — a vendored Go sync engine.
- One workflow, `fork.yml`, that assembles, resolves, builds, releases, and
  publishes to the tap.

The assembled tree (upstream at the pinned sha + still-open PR heads +
patches) exists only in the CI workspace and as release artifacts. The PR
branch on upstream is the source of truth for a PR's content; a merged or
closed PR drops out of the assembly automatically, and a patch file that
upstream absorbs is deleted by the engine. When the tracked PR set and the
patch directory are both empty, the fork retires itself.

### The engine

`forkengine` (Go, vendored into each fork) is a state machine with a
functional core and an effects shell, emitting one of four results:
`no_op`, `synced`, `conflict`, `retire`. Design points:

- **Deterministic assemblies.** Merge commits use fixed identity and the
  upstream head's dates, so re-assembling the same inputs on any machine
  yields byte-identical trees and a stable lock (`.fork/lock.json`).
  Releases are content-gated: a run that reproduces the previous state
  pushes and publishes nothing.
- **Pause/resume conflicts.** On conflict the engine leaves the merge in
  place, writes a resolver prompt, and exits; `--resume` continues after
  files are resolved and staged. The same flow serves Claude in CI and any
  agent locally. Resolutions are harvested into `rerere/` (pre/postimages
  only) and replay on later syncs.
- **Paranoid by test.** txtar/testscript scenarios pin the failure modes:
  double starts, stale locks, resolver misbehavior (committing, aborting),
  patches deleted mid-pause, corrupt state files, junk never shipping,
  malformed patches failing loudly.
- **Forge access via CLI, REST as fallback.** On GitHub the engine shells
  out to `gh`. On a non-GitHub forge it speaks the Gitea-shaped REST API
  directly; `fgj` was evaluated as a `gh` drop-in and rejected after live
  command drift.

### No PR ceremony in fork repos

The single workflow's step order is the green-before-release gate:
assemble → resolve → build → smoke → push manifest → release → tap bump.
No branch protection, no Mergify, no sync PRs, no per-fork PATs. The
workflow's own pushes use `GITHUB_TOKEN`. Unresolvable conflicts become a
`needs-human` issue and nothing ships.

### Install path: one brew path

Machines install forks exclusively through `prateek/homebrew-tap` as
`<tool>-fork` formulae/casks that fork CI regenerates per release. The
dotfiles toggle is the `forks` package group in `packages.toml`
(`{ name, kind, replaces }`); the Brewfile render subtracts each `replaces`
from the official groups, and an apply-time reconciler
(`scripts/packages/reconcile-fork-installs`) performs the official↔fork
swap that `brew bundle` alone cannot, snapshotting brew state once per run.

### Lifecycle through labeled issues, merged by AI review

Fork CI and the setup skill talk to dotfiles by filing `fork-lifecycle`
issues carrying a fenced JSON payload. Dotfiles automation
(`fork-lifecycle.yml`) is the single writer of the forks group: it edits
`packages.toml` via a table-scoped script and opens a PR. A second
workflow auto-merges that PR only if it passes a **replay gate**: the diff
touches exactly `packages.toml`, re-running the entry script from the
issue payload reproduces the diff byte-for-byte, and a tool-less Claude
review returns an approve verdict. Anything else waits for a human.

### Auth: one app, one vault, rulesets for history

- One GitHub App (`prateek-fork-automation`) installed on `prateek/dotfiles`
  and `prateek/homebrew-tap` only; workflows mint per-run tokens downscoped
  to the single permission each step needs. Fork repos never join the
  installation.
- One 1Password vault (`gh-prateek-fork-automation`) distributes the app
  credentials and the Claude subscription token; each repo's only GitHub
  secret is the read-only service-account token. Rotation is a 1P edit.
- The "automation can never destroy history" guarantee comes from
  **rulesets** on dotfiles `master` and tap `main` (PRs + required checks,
  no force-push/deletion), not from splitting the app. An app split was
  considered and rejected: both halves would still hold contents-write
  somewhere, so rulesets are the effective control either way.
- Credential confinement inside `fork.yml`: 1P values surface as step
  outputs consumed per step, never job env — the build step executes
  upstream code and must see no credentials; the resolver step gets only
  its own token.

### Testing on a real local forge

The E2E harness runs Forgejo (v15) plus a host-mode `forgejo-runner` in
Docker, with real PRs, issues triggers, releases, and Actions executing
the same shell-only `fork.yml` that ships to GitHub (GitHub-only steps are
gated on the server URL). Gitea/Forgejo is the only local forge family
that runs GitHub-Actions-syntax workflows. A residual list that only real
GitHub can prove (app-token minting, `GITHUB_TOKEN` semantics, hosted
runners, brew installs from real release URLs) was exercised against a
throwaway testbed fork before production use.

## Consequences

### Positive

- Fork repos are a few KB of intent; setup is template rendering plus one
  secret. Retirement is automatic and leaves dotfiles clean.
- Deterministic assembly makes every sync idempotent and auditable: the
  lock file names the exact inputs, releases exist only for real changes.
- The blast radius of any single credential is one permission on one repo
  for one hour; history-destructive operations are structurally blocked.
- The whole loop — including the Claude resolver and the AI-gated
  lifecycle merge — is reproducible locally without touching GitHub.

### Negative

- Assembled trees are not versioned anywhere except releases; if upstream
  vanishes, only released artifacts survive. Accepted for daily-driver use.
- The daily rebuild depends on upstream availability and 1Password at run
  time; an outage fails a cron tick and the next tick retries.
- Fork app builds are ad-hoc signed, installed with `--no-quarantine`;
  entitlement-heavy apps may need a personal Developer ID.

## Revisit criteria

- A fork needs long-lived divergence that will never upstream → this model
  fights you; reconsider a real fork repo for that project.
- Upstream PR churn makes daily Claude resolution costly → revisit rerere
  coverage or sync cadence.
- GitHub Apps or rulesets change semantics → re-audit the auth section.

## Amendment (2026-07-04) — fleet monorepo

Before any fork but ghost-pepper shipped, four things changed. The thin-
assembly core is unchanged; this section is the current design and supersedes
the Decision sections it names.

### One monorepo, which is also the tap (supersedes "Install path: one brew path")

All forks live in one public repo, `prateek/forks`: a shared `engine/`, a
per-tool `<tool>/` directory (manifest, patches, rerere, and a `src` gitlink),
`Formula/` and `Casks/` at the root, and one rendered workflow per tool.
Provisioning is one-time instead of per-fork: one repo to watch, one set of
secrets, one adopt surface. The repo is its own Homebrew tap
(`brew tap prateek/forks https://github.com/prateek/forks`), so the cross-repo
tap machinery is gone — `publish` commits the formula/cask into the same repo
with `GITHUB_TOKEN`. Package tokens become `prateek/forks/<tool>-fork`;
`prateek/homebrew-tap` keeps only its non-fork packages.

### Per-fork source via an `assembled` branch + submodule (new; solves the durability negative)

Each tool's `src` is a submodule pointing at the plain GitHub fork of that
upstream under `prateek/<upstream>` — the same fork where the PR branches are
developed. After build and smoke, `publish` pushes the assembled commit to that
fork's `assembled` branch plus a permanent `assembled-<tag>` tag, and records
it as the `<tool>/src` gitlink in the sync commit. This makes every release's
source bit-exact and durable (the earlier "assembled trees survive only as
releases" negative no longer holds) and lets an operator
`git submodule update --init <tool>/src` to hack on the real tree. Rejected:
vendoring `src/` as a subtree (reintroduces the ADR 0001 tree-in-repo problems)
and pointing the submodule at the monorepo itself.

### Three-job workflow (supersedes "No PR ceremony": the single job becomes three)

The workflow is `resolve → build → publish`, plus a `lifecycle` job, chained by
tar artifacts. The invariant: **untrusted upstream code never shares a runner
with credentials.**

- `resolve` (hosted ubuntu, `contents: read`, Claude token only) assembles and
  runs the sonnet-5 conflict loop; it compiles nothing (Go engine + git, textual
  conflict resolution).
- `build` (`@RUNS_ON@`, **zero secrets**, no checkout) runs upstream BUILD/SMOKE
  and uploads the asset. This is the only place upstream code executes.
- `publish` (hosted ubuntu, GitHub App key) takes git/manifest state from
  `resolve` and the `build` asset as an **opaque payload**: a compromised build
  can at most corrupt the binary it could already corrupt by miscompiling. It
  pushes `assembled`, commits the manifest and gitlink, releases, and commits
  the tap.
- `lifecycle` files the `needs-human` issue on conflict and, on retire, writes
  the `<tool>/.fork/retired` marker, files a self-issue, and disables the
  workflow.

Multi-runner isolation is a GitHub property; a single-host forge cannot
replicate it, so the local harness verifies the engine and the real-GitHub E2E
verifies the three-job workflow.

### Auth: GitHub secrets, no 1P in CI (supersedes "Auth: one app, one vault")

CI never talks to 1Password. The vault (`gh-prateek-fork-automation`) is the
at-rest source; the `fork-ops` skill copies values into three GitHub secrets at
creation/rotation time (`op read` piped to `gh secret set`), and runners see
only those: `CLAUDE_CODE_OAUTH_TOKEN` on `resolve`, `FORK_APP_ID` +
`FORK_APP_PRIVATE_KEY` on `publish`. The `prateek-fork-automation` app is
trimmed to **contents-only** and installed **only on the `prateek/<upstream>`
forks** (not the monorepo), so its sole job is the `assembled` push; everything
monorepo-local uses `GITHUB_TOKEN`. Tokens are never embedded in remote URLs
(`http.extraHeader`). Removing the 1P load action also means a 1Password outage
can no longer fail a cron tick.

### Generalized patch sources (extends "The engine")

`fork.toml` carries two sources beyond upstream PRs and local patches:
`[branches]` (internal work on the upstream fork, merged after PRs, dropped when
upstream absorbs them) and `[[patches.remote]]` (curl-able patches pinned by
`{url, sha256}`, a mismatch failing loudly). Both flow through the same
conflict/rerere/lock machinery.

### Dotfiles lifecycle is manual (supersedes "Lifecycle through labeled issues")

The `fork-lifecycle.yml` / `fork-lifecycle-review.yml` automation and the
replay-gated AI auto-merge are removed; the forks side holds no dotfiles
credentials. Retirement is pull-based: the fork files a self-issue, and
`packages.toml` edits are ordinary human/agent PRs made with the repo-local
`fork-lifecycle` skill (wrapping `scripts/packages/fork-lifecycle-entry`). The
shelved automation remains in git history for a future auto-merge design.

### Resolver containment (extends "Credential confinement")

A prompt-injected resolver is bounded two ways: a narrow git allowlist (no
`push`/`fetch`/`config`/`remote`), and the engine's `--resume` contract, which
snapshots `.git/config` and the index at pause and, on resume, restores config,
strips planted hooks, and hard-resets any change outside the conflicted file
set. All engine git calls run with `core.hooksPath`/`core.fsmonitor` neutered.
The residual foothold is exfiltration of the resolver's own Claude token, and
nothing else.

### Threat model

Validated by a no-context adversarial review of the rendered workflow
(workflow-attack and correctness lenses); confirmed findings are fixed, the
residuals below are accepted.

- **Trust boundary:** upstream code runs only in the secrets-free `build` job
  (`permissions: {}`); `publish` runs only our shell and treats the build asset
  as opaque. The build and publish jobs share the artifact backend, so the
  state tar `publish` extracts is integrity-checked against a sha `resolve`
  emits as a job output (which `build` cannot rewrite) — a poisoned state tree
  fails the gate before anything is pushed.
- **No `pull_request` triggers, ever:** a public repo with self-hosted runners
  must never run untrusted PR-triggered workflows; `<tool>.yml` is
  cron/dispatch only.
- **No 1P in CI:** runners hold only per-job GitHub secrets; the app key never
  reaches the jobs that touch upstream code or resolver output.
- **Blast radius:** dotfiles is structurally out of reach (no fleet credential
  can touch it). The tap lives in `prateek/forks`, so a compromised monorepo
  workflow could alter formulae — accepted for a personal fleet, with every
  formula commit a watched-repo notification. A stolen app key reaches only
  contents on the public upstream forks (including `assembled`).
- **Tartelet minis, LAN exposure accepted (ADR 0014):** macOS builds run on the
  homelab minis from day 0. Tart guests NAT onto the homelab LAN, so upstream
  build code executes with LAN reachability. Softnet isolation was not verified;
  the exposure is **explicitly accepted** for this personal fleet rather than
  gating the rollout. The Tartelet runner-registration app (Administration RW on
  the served repo) is a separate credential held only in the mini keychain,
  never referenced by any workflow, and must never merge with
  `prateek-fork-automation`.
