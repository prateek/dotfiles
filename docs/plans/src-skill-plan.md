---
status: active
doc_type: plan
summary: "Rewrite the utils-agent ask skill from scratch as src, against the installed CLI and observed agent failures, with a trigger eval."
owner: Prateek
created: 2026-10-20
updated: 2026-10-20
related:
  - ../../agent-marketplace/src/utils-agent/skills/src/SKILL.md
  - ../../home/dot_agents/docs/engineering.md
  - ../runbooks/corp-tls-inspection.md
status_detail: "Landed 2026-10-20; open checks are in GHOST_OF_COMMITS_PAST.md, and the Cursor GPT case waits on the Cursor marketplace path."
---

# Src skill (formerly ask)

The `ask` skill tells agents how to read version-matched dependency source and
docs. Agents use it constantly, and the skill text is wrong in ways that cause
repeat failures. Its name also collides with other `ask`-prefixed skills in
every harness's picker. This plan rewrites the skill from scratch, settles its
name and triggers, and fixes the places that point at it. The `ask` CLI itself
stays as it is; only the skill is renamed.

## Evidence

Sources: the agentsview store on work-mbp (sessions 2026-06-21 to 2026-10-20),
`ask --help` for the installed CLI, a throwaway `ASK_HOME` reproduction, and
upstream `pleaseai/ask` at `main` (Rust port, #119).

| Measure | Value |
| --- | --- |
| Top-level sessions that ran `ask` | 56 |
| Sessions that loaded the skill | 49 |
| Sessions that ran `ask` without loading the skill | 12 |
| Shell calls to `ask` | about 170 (Claude almost all, Cursor a few, Codex none) |

Agents run `ask src` almost exclusively and `ask docs` occasionally. Nobody
used `install`, `add`, `skills install`, `fetch`, `search`, or `cache` beyond
reading `--help`. Prateek usually invokes the skill explicitly, often with a
GitHub URL ("/utils-agent:ask https://github.com/…") or a request for "latest
trunk".

Agentsview stopped storing Bash result text around 2026-09-25. Failure counts
before then come from the store; later ones come from session exports, so the
tallies below are lower bounds.

### Failure modes

1. **Bare `owner/repo` goes to npm.** A spec without a colon parses as an npm
   name (`spec.rs` `parse_spec`, empty ecosystem resolves to npm), so
   `ask src stablyai/orca` prints `npm registry returned 404`. Our skill and
   upstream's both document bare `owner/repo` as GitHub on `main`. Agents hit
   this at least 8 times, often twice in one session.
2. **Commit SHAs never fetch on work-mbp.** The fetcher runs
   `git clone --branch <ref>`, then `v<ref>`, which cannot take a SHA. It then
   falls back to a tarball download. Reproduced 2026-10-20; every SHA attempt
   in history failed (nix repos, vial-qmk, tinycast).
3. **The tarball fallback is dead on work-mbp.** `ureq`'s bundled roots reject
   the PANW interception CA with `invalid peer certificate: UnknownIssuer`, and
   `NODE_EXTRA_CA_CERTS` has no effect. Any clone failure is therefore fatal,
   including the intermittent `Is a directory (os error 21)` seen on bats-core,
   kubernetes, and agentsview v0.45.0.
4. **Branch refs go stale silently.** The checkout is keyed by ref name and
   never refreshed, and there is no `--refresh`. `@main` served a two-month-old
   crit snapshot on 2026-09-03. Agents worked around it with `rm -rf` on the
   cache entry. Our skill says mutable refs are fine "because they do not
   persist changes", which misleads. `ask` records no commit SHA for an entry:
   `.ask-hash` holds a content hash, and its mtime is the fetch time.
5. **Discarded stderr becomes an empty path.** Agents copy the
   `$(ask src …)` idiom with `2>/dev/null`. A failed fetch then yields `""`, and
   the next `rg` or `ls` runs on nothing. At least 8 occurrences.
6. **No URL-to-spec guidance.** The skill never says how to turn a pasted
   GitHub URL into a spec, which is the most common way Prateek invokes it.

### Documentation drift

- The skill omits `ask fetch`, `ask search`, and `--json`, which all exist.
- It names `~/.ask` as the store. Our mise config sets
  `ASK_HOME=$XDG_CACHE_HOME/ask`, so the store is `~/.cache/ask`.
- `references/cache.md` describes an `npm/` store and a `gc` that keys off
  `.ask/resolved.json`. npm specs now resolve to the package's GitHub repo at a
  tag and land under `github/`. `references/declarative-workflow.md` says
  `install` no longer writes `resolved.json`, which would leave `gc` without
  roots. Not run; unverified.
- The references cite TypeScript internals (`ensureCheckout`, zod schemas)
  from before the Rust port.
- The npm package is 0.4.9 while the binary reports `ask 0.4.8`.
- `ask src --help` says "one or more specs", but its usage takes one `<SPEC>`.

### Provenance

Our skill is authored in this repo (rewritten in a529ccae from an earlier copy
of upstream's). Upstream ships its own `skills/ask` plus a Claude plugin with a
WebFetch hook. Upstream's skill carries the same bare-spec error and is broader
than our usage. The WebFetch hook cannot help here: the work laptop allows only
managed hooks and policy denies WebFetch.

Upstream activity, checked 2026-10-20 through the GitHub API:

| Measure | Value |
| --- | --- |
| Commits, April / May / June / July 2026 | 141 / 6 / 3 / 11 |
| Last commit | 2026-07-08 |
| Contributors | one maintainer, plus bots |
| Stars / forks / open issues | 0 / 1 / 12 |
| Changes to `skills/ask/SKILL.md` | 3, the last on 2026-07-02 |

The project was built in a burst in April, ported to Rust in early July, and
has been quiet since.

### Refs, ecosystems, and forges

From upstream source (`ensure_checkout.rs`, `sources/github.rs`):

- **No ref means trunk, if trunk is `main` or `master`.** A bare
  `github:owner/repo` tries `main`, `vmain`, then `master`, and caches the
  result under the key `main` whichever branch it found. A repo whose default
  branch has another name (`develop`, `trunk`) fails to fetch.
- **Package ecosystems:** `npm`, `pypi`, `pub`, and `maven`. Each resolves the
  package to its GitHub repo at a tag. npm alone reads the project lockfile;
  the others default to `latest`. The installed binary refuses `go:` and
  `crates:` with "Supported ecosystems: npm, pypi, pub, maven"; the README's
  longer alias list applies to the registry only. On work-mbp, `maven:` and
  `pub:` lookups fail with `UnknownIssuer` while `pypi:` resolves (probed
  2026-10-20 with `--no-fetch`).
- **Forges and VCS:** GitHub over git only. The store has a host segment, but
  nothing else is implemented.

Demand outside GitHub is close to nil. Across all sessions, agents ran one
GitLab clone, against 131 GitHub clones. 45 of those GitHub clones were shallow
reads, mostly the work-laptop fallback.

### Name collisions

Three installed plugin skills start with `ask`: `utils-agent:ask`,
`core:ask-questions-if-underspecified`, and `mattpocock:ask-matt`. Typing
`/ask` in any picker lists all three, so explicit invocation, which is how
Prateek usually reaches this skill, needs a toggle every time. No installed
skill name starts with `src` or `source`. Sourcegraph's CLI is installed as
`src` (`sourcegraph/src-cli` in the package groups) and appears in the
`skills-searcher` skill as `src search`.

## Goals

- An agent following the skill writes a spec that resolves on the first try.
- An agent on work-mbp knows which fetches cannot work and goes straight to a
  fallback that works.
- A branch read is never staler than the age threshold: past it, the agent
  checks upstream and refetches only if the branch moved.
- Prateek can invoke the skill without disambiguating it. Claude Code loads it
  unprompted for dependency-source questions; Codex and Cursor list it.
- The skill covers what we use and points at `--help` for the rest.

## Non-goals

- Replacing or shadowing the `ask` command on `PATH`. A helper script inside
  the skill is in scope.
- A managed cache or tool for non-GitHub forges; the skill gives a clone recipe.
- Filing upstream issues or PRs against `pleaseai/ask`.
- Evicting cache entries on age alone.
- Automatic-trigger testing in Codex or Cursor. Codex process starts are
  killed by Cortex on work-mbp, and Cursor's headless CLI has no trigger
  harness.
- Fixing the corporate TLS interception or the codeload block.

## Decisions

Accepted, from Prateek on 2026-10-20:

- **Ours alone.** No vendored upstream skill and no hybrid. Upstream's skill
  teaches the bare-spec error, and upstream has been quiet since July.
- **Rewrite from scratch.** The skill and its references are rewritten, not
  patched.
- **Rename the skill to `src`.** It becomes `utils-agent:src`. The CLI stays
  `ask`: renaming the binary would collide with Sourcegraph's `src` on `PATH`
  and would need a wrapper, which is a non-goal.
- **Freshness:** "we don't have to evict on age, we have to check new updates
  based on age." Proposed means: deliverable 1's freshness helper, with a
  24-hour threshold.
- **No upstream issues.**
- **Follow the authoring standards below.**

## Authoring standards

The skill follows `mattpocock-skills:writing-for-agents` (with its
`SKILL-MECHANICS.md`) and poteto-mode's skill-authoring and eval playbooks
(`pstack/skills/poteto-mode/playbooks/authoring-a-skill.md` and `eval.md`).
This repo's `agent-skill-management` skill owns the marketplace mechanics.
These are the rules that change this skill's design:

- **The description is a context pointer.** It stays loaded every turn, so it
  front-loads the leading word and carries one trigger per branch: a
  dependency's source or docs at a version or ref, and a pasted repo URL.
  Synonyms of one branch collapse into one trigger.
- **The environment is the source of truth.** `ask <cmd> --help` owns
  subcommands and flags. The skill caches only what `--help` cannot tell an
  agent: bare names are npm, refs never refresh, the work laptop's dead fetch
  paths, and the stderr trap.
- **Prompt the positive.** Write "use `github:owner/repo`, adding `@ref` when
  the version matters" rather than "don't use bare `owner/repo`". A
  prohibition stays only as a guardrail with its positive target beside it.
- **Steps end on completion criteria.** The fetch step is done when the agent
  holds a non-empty checkout path at the ref it meant to read.
- **Subtract before adding.** Delete the old skill directory and all three
  references first, then write the new skill. A reference returns only for
  material some branches need and the body cannot hold.
- **Encode lessons in structure where possible.** The bare-spec mistake could
  only be caught structurally by a wrapper, which is out of scope. Per the
  principle's fallback, the instruction gets prominence plus one example of the
  failure. The trigger check, by contrast, is structural: a script with a
  nonzero exit.
- **Prove it works on the real artifact.** Acceptance runs the installed skill
  and the real CLI. No self-report counts.

## Proposal

Deliverables 1 to 3 land as one change. Deliverable 2 can land first on its
own, since the generalized runner keeps acpx's lane working.

### 1. Rewrite the skill from scratch as `src`

Steps:

1. Read `agent-skill-management`, `writing-for-agents`, poteto-mode's
   skill-authoring playbook, and Cursor's `create-skill` (the playbook's first
   step).
2. Delete `agent-marketplace/src/utils-agent/skills/ask/`.
3. Write `agent-marketplace/src/utils-agent/skills/src/SKILL.md`, using
   the outline below.
4. Write the freshness helper, `skills/src/scripts/fresh`, described below.
5. Bump the `utils-agent` version in `agent-marketplace/marketplace.toml`, as
   `agent-skill-management` requires for changed published content.

`SKILL.md` outline:

- **Frontmatter:** `name: src`, a model-facing description written per the
  standards above, and `allowed-tools: Bash(ask:*)`.
- **Spec:** repos are `github:owner/repo`, with `@ref` added when the version
  matters. Packages are `npm:`, `pypi:`, `pub:`, or `maven:`, and a bare name
  is npm. Include one failure example: `ask src stablyai/orca` returns an npm
  404.
- **URLs:** `https://github.com/<o>/<r>` becomes `github:<o>/<r>`. In
  `…/tree/<rest>` or `…/blob/<rest>`, the ref is the longest leading part of
  `<rest>` that names a branch or tag, because refs can contain slashes. Try
  candidates from longest to shortest with
  `gh api 'repos/<o>/<r>/commits/<candidate>' --jq .sha`; the first success is
  the ref.
- **Refs:** omit the ref to read trunk. That works when trunk is `main` or
  `master`; otherwise pass the branch from
  `gh api repos/<o>/<r> --jq .default_branch`. Prefer a release tag when the
  question is about a version. Read trunk and other branches through the
  freshness helper.
- **Fetch:** capture the path with stderr visible. Done when the path is
  non-empty.

  ```bash
  src=$(ask src github:owner/repo@v1.2.3) || exit 1
  [ -n "$src" ] || { echo "ask returned no path" >&2; exit 1; }
  ```

- **Freshness:** read a branch through the helper below, which prints the
  checkout path. Tags and SHAs go straight to `ask src`; they never change.
- **Without `ask`:** one heading for every case `ask` can't serve. That covers
  other forges and VCS (GitLab, Codeberg, sourcehut, self-hosted git,
  Mercurial). It also covers the work laptop, where TLS interception makes the
  tarball fallback, SHA refs, and `maven:`/`pub:` lookups fail; the signals
  are `invalid peer certificate: UnknownIssuer` in stderr, or a SHA ref. The
  recipes, all verified on work-mbp:

  ```bash
  # A few files from GitHub at any ref, SHA included
  gh api -H 'Accept: application/vnd.github.raw+json' \
    'repos/<o>/<r>/contents/<path>?ref=<ref>'

  # A whole tree at a branch or tag (any git forge; SSH on the work laptop)
  git clone --depth 1 --branch <ref> <url> "$dir"

  # A whole tree at a SHA
  git init -q "$dir" && git -C "$dir" remote add origin <url> &&
    git -C "$dir" fetch -q --depth 1 origin <sha> &&
    git -C "$dir" checkout -q FETCH_HEAD
  ```

  `$dir` is a fresh `mktemp -d` scratch directory. Mercurial uses
  `hg clone -r <ref>`.
- **Docs:** one line saying `ask docs` prints candidate doc directories for the
  same spec. Point at `ask <cmd> --help` for everything else.

#### Freshness helper

`scripts/fresh <github-spec>` takes a `github:owner/repo[@branch]` spec and
prints one checkout path, with errors on stderr. It encodes the rule as a
script because agents fumble multi-step recipes, and date parsing differs
between macOS and the Linux devbox. Write it in POSIX shell.

1. Without a cache entry (`ask src --no-fetch` fails), fetch with `ask src`
   and print the path.
2. With an entry younger than the threshold (default 24 hours, override with
   `SRC_FRESH_MAX_AGE` in seconds), print the cached path. The fetch time is
   the mtime of the entry's `.ask-hash`.
3. With an older entry, read the branch head's commit date with
   `gh api 'repos/<o>/<r>/commits/<branch>' --jq .commit.committer.date`. A
   spec with no ref uses the repo's default branch. If the head is newer than
   the fetch time, delete the entry and refetch. Otherwise `touch` the
   `.ask-hash`, so the next check waits a full threshold, and print the cached
   path.
4. If `gh` fails, print the cached path and warn on stderr that freshness is
   unchecked.

Known gap: a commit pushed after the fetch but carrying an older committer
date, such as a fast-forward of an old branch, reads as no update. The helper
accepts that gap rather than storing SHAs inside `ask`'s store, which verifies
entries and quarantines tampered ones. The `touch` in step 3 also needs that
check: confirm `ask` still serves the entry after its `.ask-hash` mtime
changes.

The age check was prototyped on 2026-10-20 against the cached
`github:rclone/rclone@master` entry, comparing `.ask-hash` mtime with the head
commit date.

Acceptance:

- `just check` in `agent-marketplace` passes, the built artifact carries the
  bumped version, and `chezmoi apply` installs it.
- The behavior check below passes.
- The helper, run against real cached branches on work-mbp: a young entry
  prints its path with no network call; an entry backdated with `touch -t` on
  a branch that has moved since is deleted and refetched; a backdated entry on
  an unchanged branch is kept and its mtime refreshed; and `ask` still serves
  an entry after the `touch`.
- On work-mbp, these commands behave as the skill says:

  ```bash
  ask src github:tomasz-tomczyk/crit@main      # resolves
  ask src tomasz-tomczyk/crit                  # npm 404, as documented
  ask src github:openai/codex@rust-v0.163.0    # resolves
  ```

#### Behavior check

This follows poteto-mode's eval playbook. Prateek authors nothing here; the
implementer runs it.

1. **Rubric**, held back from candidates. A run passes when the agent:
   uses a spec form that resolves on the first fetch; keeps stderr and checks
   for an empty path; on a failure signal, goes straight to the matching
   recipe instead of retrying `ask`; reads at the ref the request implies;
   and reports which ref it read.
2. **Environment.** A sanitized project directory under `~/.local/state`
   (the work laptop's policy blocks reads under `./build`), with a
   project-shaped name and no eval vocabulary in any path or prompt. The
   installed skill is the only `src` guidance present.
3. **Prompts.** One organic request per case, written the way Prateek types:

   | Case | Passing behavior |
   | --- | --- |
   | A GitHub URL with a tag | `ask src github:…@<tag>` |
   | A `tree/` URL whose branch contains a slash | resolves the full branch name, then fetches it |
   | "Latest trunk of a repo" | reads through `scripts/fresh` with no ref |
   | A SHA, on work-mbp | the raw `gh api` read or the SHA fetch recipe |
   | A GitLab repo URL | the clone recipe into a scratch directory |

4. **Candidates.** Per prompt, two fresh candidates in parallel on different
   families: a native Claude subagent and GPT through the `agpt` route
   (cursor-agent; codex is off-limits on work-mbp).
5. **Judge.** One blinded judge on a third family (Gemini through `agemini`),
   seeing outputs by sanitized label with the rubric. If no third family is
   routable, record that deviation.
6. **Transcripts over reports.** Grade the commands each candidate ran from
   its transcript or acpx log, never its own summary.
7. **Read every output** and compare with the judge. Pass means every
   candidate passes every case, and the implementer's read agrees with the
   judge.

### 2. Trigger eval

The acpx trigger lane can't be reused as is. `trigger_eval.py` hardcodes
`utils-agent:acpx` and `utils-agent:acpx-cli`, `run_trigger_evals.sh` checks
for those two skills, `setup_fixture.sh` builds an acpx tree, and the runner
returns 0 even when cases fail.

Proposed: generalize it once.

- Move the runner to `agent-marketplace/scripts/trigger-eval/`, taking the
  target skill, its sibling skills, a fixture script, and a cases file as
  arguments. It exits nonzero when any case misses.
- Keep acpx's cases and fixture under its `evals/` and point its wrapper at
  the shared runner, so its lane still passes unchanged.
- Add `skills/src/evals/trigger-evals.json` and `setup_fixture.sh`. The
  fixture is a small project with an npm lockfile. Cases come from real
  requests in agentsview. Positive cases cover a pasted GitHub URL, "read X's
  source", "how does library Y handle Z internally", "latest trunk of R", and
  reading a GitLab project's source. Negative cases cover web search
  (`search`), "ask me questions first"
  (`core:ask-questions-if-underspecified`), Sourcegraph code search
  (`src search`), and a question about a file the user supplied.
- Tune the description until the runner passes.

Acceptance: the runner exits 0 for `src` at three runs per case after install,
and exits nonzero when a case is flipped deliberately. acpx's lane still
passes through the shared runner. Typing `/src` in Claude Code lists one
skill, and Codex and Cursor list `src` after `chezmoi apply`.

### 3. Fix the pointers

- `home/dot_agents/docs/engineering.md`: name the `src` skill and show the
  `github:` form in the "settle third-party APIs" bullet.
- `home/dot_config/karabiner.edn.tmpl`: the header names the `ask` skill and
  `ask src github:yqrashawn/GokuRakuJoudo@master`. Name the `src` skill and use
  a tag, or note that a branch may be stale.
- `.agents/skills/agent-skill-management/references/third-party-imports.md`:
  names `utils-agent:ask`.
- `home/dot_config/mise/conf.d/clis.toml.tmpl`: the `npm:@pleaseai/ask`
  comment calls it the "ask skill".
- Research and ADR docs that cite `ask src` commands record what was read.
  Leave them.

Acceptance: this command prints nothing. Before the change it prints the
Karabiner, mise, and third-party-imports lines.

```bash
rg -n --hidden -e 'utils-agent:ask\b' -e '\bask skill\b' -e 'the `ask` skill' \
  -g '!.git/**' -g '!docs/research/**' -g '!docs/adr/**' -g '!docs/plans/**' \
  -g '!docs/inventory.md' -g '!agent-marketplace/vendor/**' .
```

`chezmoi diff` shows only the expected target changes.

## Progress

### 2026-10-20: implemented on `prateek/ask-v-src`

- **Deliverable 1.** `skills/ask/` deleted; `skills/src/` holds `SKILL.md`,
  `scripts/fresh`, and `evals/`, under `agent-marketplace/src/utils-agent/`
  after master's reorganization by origin (a11e5082). `utils-agent` is 1.19.0
  in `marketplace.toml`, one minor above master's 1.18.1. `just check` passes (114 tests).
- **Freshness helper.** `tests/test_src_fresh.py` covers fetch-on-miss, a
  young entry served with no GitHub call, refetch on a moved branch, keep and
  restamp on an unchanged one, the unreachable-GitHub warning, and the guard
  that refuses to delete outside the spec's store directory. On work-mbp
  against real entries: young `go-git@main` served with no `gh` call;
  backdated `go-git@main` (head 2026-10-16) kept and restamped; backdated
  `rclone@master` (head 2026-10-20) deleted and refetched; `ask` kept serving
  an entry after its `.ask-hash` was touched.
- **Deliverable 2.** The runner moved to
  `agent-marketplace/scripts/trigger-eval/`, takes `--skill`, and exits 1 on a
  miss (`tests/test_trigger_eval.py`). acpx's wrapper calls it with
  `--sibling acpx-cli`; through it, acpx's lane scored 15/19 and exited 1.
  All four misses went straight to the native Agent tool, skipping the model
  resolution the acpx skill requires first. The acpx description now says to
  load the skill before spawning that subagent, and the farm-out case was
  relabeled false (no model named; native is the endorsed outcome). One clean
  three-run round then scored 18/19; later rounds scored 17/19 and 15/19,
  with misses flipping to a first `Bash` read. Those later rounds were
  disturbed by an expired Vertex credential and by another session's apply
  replacing the test install, so the acpx improvement is unproven. The `src` lane passed 14/14 at three runs per case on
  `claude-opus-5-5`. Two earlier rounds failed 12/14. The lockfile clause in
  the description fixed the zod case. The rclone design-scoping case was
  replaced, because its first call correctly reads the engineering
  conventions; `evals/README.md` records why.
- **Deliverable 3.** The pointer search prints nothing. `chezmoi diff` on the
  three managed targets shows only the intended lines.
- **Behavior check.** Five organic prompts, each run by a `claude -p`
  candidate and a GPT-5.6 Sol candidate through the `agpt` Cursor route. The
  judge ran on Fable, not Gemini: committing a Gemini routing selection was
  blocked by the session's permission classifier, so this is the plan's
  recorded deviation. Two harness defects voided earlier rounds and were
  fixed: candidates inherited the prompt list on stdin, and Cursor sent
  permission requests that `--non-interactive-permissions deny` refused. The
  requests come from the user's own `~/.config/cursor/cli-config.json`
  (`approvalMode: allowlist`, allow list `Shell(ls)`), which `cursor-acp`
  copies into each route since bb2365a2 (2026-10-19). Nothing in this branch
  changed it; another session hit the same request at 16:06.
  Result: 9 of 10 runs pass every rubric item, and the judge agreed with the
  implementer's read. Every run used the right fetch first: the tag via
  `ask src`, the slash branch resolved through `gh api` and read with
  `fresh`, trunk through `fresh` with no ref, the SHA via raw `gh api` or the
  SHA fetch recipe, and GitLab via a shallow clone into a scratch directory.
  The failure is the GPT slash-branch run. Twice it told the user the `src`
  skill was unavailable without opening the `SKILL.md` path in its prompt,
  and it ran no commands. Cursor's skill list never contains `src`: dotfiles
  registers the `prateek-local` marketplace in `~/.cursor/cli-config.json`,
  but cursor-agent and `cursor-acp` read `~/.config/cursor/cli-config.json`,
  which has no marketplaces, and `~/.cursor/plugins` holds no prateek-local
  plugins. That is a Cursor activation bug outside this plan. The plan's
  every-case bar is unmet for that one run.
- **`src` at five runs** (2026-10-20, after master's reorganization): 13/14;
  the goku case's first call flipped to `Bash` in all five runs.
- **Landed** as one commit on master; the remaining checks are in
  `GHOST_OF_COMMITS_PAST.md`.
- **Open.** The skill is materialized into `~/.agents/plugins` and installed
  for Claude from this worktree. Applies from other sessions restored master's
  `ask` three times during measurement, and will keep doing so until this
  branch lands. Codex was not reconciled, because
  starting `codex` on work-mbp trips the Cortex kill. Landing and the
  follow-up agentsview measurement remain.
