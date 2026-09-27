---
status: active
doc_type: plan
owner: Prateek
created: 2026-09-26
updated: 2026-09-27
related:
  - using-git-spice-skill-plan.md
  - acpx-skill-packaging-plan.md
  - ../runbooks/corp-tls-inspection.md
  - ../references/agent-marketplace.md
  - ../references/mise-tool-management.md
status_detail: "Implemented and committed 2026-09-26, not yet applied: W1, W2, W3 (mise per option A), W4, W5 proposal. Global mise trust roots await a decision; landing-checkout owner and the upstream filings stay open."
---

# Agent friction remediation — plan

## Problem

A 90-day review (2026-06-28 to 2026-09-26) of agent transcripts across all
repos and hosts found a small number of causes behind most tool failures.
The review artifacts are private, under
`~/.local/state/papercut-review/2026-09-26-rev1/` (`report.md`,
`shapes.json`, `classified.jsonl`, `claude-nomatch.jsonl`), with a Claude
Doc summary. The counts below come from that revision.

| Shape | Failures | Cause |
| --- | ---: | --- |
| zsh `nomatch` aborting agent commands | 2,972 | zsh default semantics in non-interactive agent shells |
| Reads of guessed or stale paths | 1,330 | Exploration; 91 use the retired `~/.agents/skills/` layout |
| CLI interface drift (agent-slack, droidcli, git-spice) | 332 | Leaf help unreachable; skills invite invented flags |
| Codex output truncation | 193 | Unbounded `rg`, `write_stdin` polling |
| Codex patch context mismatch | 125 | Stale reads before edits |
| Python TLS on work-mbp | 72 | System-Python `urllib` without the corporate CA |
| Missing Python modules | 52 | Ad hoc `python3` heredocs (`yaml` alone 25) |
| Mise config not trusted | 30 | Landing checkout, fake-HOME tests, new worktrees |
| Git worktree or dirty tree | 23 | Branch owned by another worktree |
| Auth expired or missing | 21 | Five providers, no preflight |

One non-count finding also needs work: the acpx skill still recommends
`--format quiet` against a recorded instruction (crit comment `c_c0d0ba`,
2026-09-09).

## Goals

- Make zsh's glob and `=` parsing bash-compatible in every shell, so agents,
  pasted commands and interactive use agree.
- Fix the instruction defects agents read daily: acpx quiet output,
  agent-slack command forms, git-spice inspection, retired skill paths.
- Close the environment gaps (mise trust, ad hoc Python, TLS) at their root:
  one declared setting per gap, no per-checkout or per-script patches.
- Add the five conventions the data supports, each with its reason.
- Make the review repeatable and periodic.

## Non-goals

- Switching agents to bash. No bash startup files are managed here, so a
  bash agent shell would lose the XDG, `DOTFILES`, mise and PATH setup that
  `.zshenv` and `.zprofile` provide, trading one failure class for another.
- The two hand-pasted review prompts (the multi-lens review team, 63
  typed messages; the acpx PR title and description rewrite, 50). Those
  are being folded into the code-review skill work already in progress.
- Archive sync recovery. The review found the personal host's hourly sync
  skipping on a free-space guard since 2026-09-23 and m4mini silent since
  2026-09-17; that is handled outside this plan.
- A general "path discovery" fix. The 1,330 missing-path reads have no
  single cause; only the retired-layout subset is addressed.
- Product bugs found in transcripts (clonefile worktree jam, acpx
  concurrency backlog, OTLP benchmark validity). Those stay in their own
  threads.
- Cross-harness failure-rate comparisons. Cursor keeps no tool results.

## Workstreams

Each workstream names an owner surface, the change, why that change and not
another, and a check that fails if it did not work.

### W1 · Shell semantics for agent shells (removes ~3,000)

Owner: `home/dot_config/zsh/dot_zshenv.tmpl`, `scripts/audit/zsh-fresh-shells.zsh`,
the machine shell guidance.

What `nomatch` does. In zsh, an unquoted word containing `*`, `?` or `[`
is a filename pattern. With `nomatch` set, a pattern that matches no file
aborts the whole command before it runs; `2>/dev/null` cannot hide it
because expansion happens first. Bash passes the unmatched word through
literally. Of the 2,972 rows (2,849 Claude, 123 Codex), 1,300 are grep
`--include=*.go`-style arguments, so grep never ran; 1,305 more are guarded
existence probes such as `ls ~/.acpx/logs/* 2>/dev/null`, which still print
the error (though the rest of the command list runs); and 68 are `?` in a
URL read as a wildcard.

Why our config is not the cause. Both harnesses run non-interactive zsh,
which never reads `.zshrc`:

| Harness | Invocation (verified) | Startup files read |
| --- | --- | --- |
| Claude Code | `/bin/zsh -c source ~/.claude/shell-snapshots/<snapshot>` | `.zshenv` only; the snapshot carries functions and aliases, no `setopt` state |
| Codex | `/bin/zsh -lc <cmd>` (11,804 calls) and `-c` (983) | `.zshenv`, `.zprofile`, `.zlogin` |

`nomatch`, no word splitting of `$var` (30 rows), and `=word` expansion are
zsh *defaults*. Making the interactive config more bash-like would change
nothing for agents. The harnesses assume POSIX-sh parsing because the
models were trained on bash; the divergence is zsh's, not ours.

Options considered:

1. **`emulate sh` for agent shells.** One line, flips about 80 options to
   POSIX behaviour. Too broad: it also sets `ksharrays` (0-indexed arrays),
   drops `extendedglob` and `multios`, and changes `posixbuiltins`, which
   can break zsh functions the harness snapshot or `.zprofile` define.
2. **Curated options for agent shells only.** Gate the three options on
   harness markers in `.zshenv`. Works, but adds a marker dependency (the
   Codex one is unverified) and leaves interactive zsh diverging from what
   every agent, script and pasted command expects.
3. **Global change, interactive too (proposed).** Make the shell
   bash-compatible for the two parse-time behaviours everywhere, with no
   gate: `unsetopt nomatch` and `unsetopt equals` in `.zshenv`, so every
   zsh (interactive, `-c`, `-lc`) agrees. What you give up interactively:
   `nomatch`'s typo guard (`rm *.tmp` with no match errors instead of
   handing `rm` a literal `*.tmp`, which then fails on its own), and `=cmd`
   expanding to a command's path. Nothing in the managed zsh config relies
   on either (checked: no `=cmd` use, no `nomatch` tests).

   One bash difference is left alone on purpose: word splitting. zsh's
   default is that an unquoted variable expands to one word. In bash,
   `CMD="ls -d /tmp"; $CMD` runs `ls` with two arguments. In zsh, `$CMD` is
   one word, so it looks for a program literally named `ls -d /tmp` and
   fails. In the window that is 30 raw `command not found: <words with
   spaces>` results, of which 8 are confirmed failures (all Claude, mostly
   `K="kubectl --context … -n …"; $K …` and `P="python3 promq.py"; $P …`);
   the rest are probes or quoted text. zsh has a switch for bash behaviour
   (`shwordsplit`), but turning it on globally changes how every line of
   zsh code on the machine treats variables, including zinit and each
   plugin it loads, which were written assuming a variable stays one word.
   Under the switch, `dir="/tmp/has space"; mkdir -p $dir` creates two
   directories instead of one, and the same happens inside any plugin that
   holds a path or a message in a variable. That is a large surface to
   re-test for 8 failures, so the plan leaves the zsh behaviour and adds a
   quoting note in step 4 (use an array: `K=(kubectl --context x); "${K[@]}"`,
   or a function). Revisit if the count grows after W1 lands.
4. **bash as the agent shell.** Rejected under Non-goals.

Steps:

1. Replace `setopt nomatch` and its comment block at `dot_zshrc:10-28` with
   `unsetopt nomatch equals` in `$ZDOTDIR/.zshenv`, next to the exports, so
   it reaches every zsh startup path. Not `nullglob`: it deletes arguments
   silently. Keep a two-line comment: bash-compatible parsing because agents
   and pasted bash commands run in this shell.
2. Extend `scripts/audit/zsh-fresh-shells.zsh verify` with the same cases in
   all three lanes it drives (PTY login shell, `zsh -c`, `zsh -lc`):
   `grep -rn x --include=*.go .` exits 1 with grep's own output;
   `ls /nope/* 2>/dev/null; echo ok` prints only `ok`;
   `echo =foo` prints `=foo`; `ls *.log(N)` still expands to nothing (the
   zsh optional-glob idiom keeps working).
3. Run the fresh-shell benchmark lane once: an option change in `.zshenv`
   should not move startup time, and the audit proves it.
4. One paragraph in the shell guidance for what remains: quote a pattern
   meant for a tool (`--include='*.go'`) so bash users get the same result,
   quote URLs, and quote `$var` that holds a whole command (zsh does not
   split it).

Acceptance: the audit cases pass on this host in all lanes; after apply, the
next 14 days of transcripts show fewer than 20 `no matches found` rows,
against about 300 per week in August and September, and the count of
`(eval):N: command not found: <multi-word>` rows does not rise.

### W2 · Instruction defects agents read daily

Owner: `agent-marketplace/` (use the `agent-skill-management` skill), then
republish and apply.

1. acpx: delete the `--format quiet` sentence at
   `packages/utils-agent/skills/acpx/SKILL.md:117`; state that `--format
   text` is the default and that quiet output must not be used. Check: the
   only remaining `format quiet` in the authored skill and in
   `~/.agents/plugins/plugins/utils-agent/skills/acpx/` after apply is that
   prohibition.
2. agent-slack (upstream dependency `stablyai/agent-slack/skills/agent-slack`,
   so a local patch): add a command card with the five real synopses
   (`message get <target>`, `message list <target>`, `search messages
   <query>`, `user get <user>`, `channel list`) and reword "lookup users" to
   "get users". Add a package check that runs each synopsis's help and fails
   on an unknown option. The review first claimed that leaf `--help` prints
   the root help in 0.10.2; that was a zsh word-splitting artifact in the
   review's own probe, and leaf help works.
3. git-spice: add to `packages/review/skills/using-git-spice/SKILL.md` that
   `branch info` does not exist and that a branch's base comes from
   `git-spice log short` or `log long`. Checked on 0.26.1 and 0.31.2.
4. Retired paths: replace hardcoded `~/.agents/skills/<name>/` in
   `experimental/skills/mcporter-skillifier/SKILL.md:22`,
   `experimental/skills/repo-guideline-site/SKILL.md:138`, and
   `ios/skills/ios-audit/references/migration-from-ios-flow-audit.md` with
   paths relative to the skill's printed base directory. Add a
   `validate-agent-packages` rule rejecting `~/.agents/skills/` outside the
   documented stub note. Check: the rule passes on the tree and fails on a
   planted reference.

Acceptance beyond the per-item checks: on work-mbp, agent-slack CLI-drift
failures per call fall below 1% (from 3.5–6%), and `git-spice branch info`
stops appearing.

### W3 · Environment gaps, fixed at the root

Each of these was first drafted as a local patch. The versions below change
one declared setting each, so the fix holds for every checkout, script and
runtime on the machine.

**Mise trust (30 rows).** Mise trusts config files one path at a time, so
every new worktree, temporary checkout and copied config starts untrusted.
Today that is patched per checkout: `orca.yaml:15-16` runs `mise trust`
twice in the Orca setup hook, `scripts/chezmoi/test-apply-dry-run.sh:32`
exports `MISE_TRUSTED_CONFIG_PATHS`, and the landing flow does neither.

Proposed root fix, not applied: declare trusted roots once with mise's
`settings.trusted_config_paths`. Tested with an empty trust store on mise
2026.4.5 and 2026.9.14: it trusts every config under a listed root, expands
`~`, follows symlinked roots, and leaves other paths untrusted, from either
`~/.config/mise/config.toml` or `conf.d/`. (An earlier draft said `conf.d/`
was ignored; that came from a probe that also set `MISE_GLOBAL_CONFIG_FILE`,
which disables `conf.d`.) Two findings stopped it:

- It would trust the vendored `apm_modules/raintree-technology/apple-hig-skills/mise.toml`
  in every dotfiles worktree, which `orca.yaml` deliberately leaves untrusted.
  That config pins `bun` and `node` and defines tasks. `ignored_config_paths`
  does not accept globs, so there is no way to carve `apm_modules` out.
- It covers few of the 30 rows. Nested worktree configs (7) are already
  fixed by `6f40725`. Fake-HOME tests (6) expand `~` to the fake home, and the
  landing checkout (1) lives in `$TMPDIR`, so neither matches. Roughly 4 rows
  would change.

What shipped instead (option A): `orca.yaml` keeps its per-worktree trust,
and the fresh-shell audit's synthetic home sets `MISE_TRUSTED_CONFIG_PATHS`
to the checkout and the real mise config directory, matching
`scripts/chezmoi/test-apply-dry-run.sh:32`. That repaired the audit's
documented usage (run from the repo root), which failed before this change.
The landing flow that creates `$TMPDIR/dotfiles-land-orca-*/checkout` is not
authored in this checkout (the 2026-09-26 session read
`build/orca-shortcuts/landing.json`); locating it remains open.

Check: `zsh-fresh-shells.zsh verify` passes when launched from inside the
checkout; a fresh landing run completes with no `not trusted` error once its
owner is found.

**Ad hoc Python (52 rows, 25 of them `yaml`).** Agents run `python3 -
<<'PY'` heredocs against the system interpreter and import packages it does
not have. `python-and-uv.md:70` already forbids inline `python3 -c` and says
to promote logic to a PEP 723 script; heredocs are the same pattern and are
not named, so agents (this review's own included) keep using them.

Root fix: extend the convention so a heredoc with third-party imports runs
as `uv run --with <pkgs> python - <<'PY'`, with the one-liner form written
out in `python-and-uv.md` next to the existing `python3 -c` rule.
Alternatives rejected: shadowing `python3` with a uv-managed interpreter
that has a "toolbelt" preinstalled (changes what tests run against; hides
the dependency instead of declaring it); a harness hook that blocks
non-uv heredocs (deferred; revisit only if the rule alone does not move
the count).

Check: `No module named` rows in agent transcripts fall by half over the
next 30 days of covered sessions.

**Work-mbp TLS (72 rows).** The corporate proxy re-signs TLS. The runbook
already exports the corporate roots for Node via `NODE_EXTRA_CA_CERTS`,
which is additive. Python, curl built on OpenSSL, and most other
non-Apple stacks read `SSL_CERT_FILE`, which *replaces* the trust store, so
pointing it at the narrow corporate bundle would break every public site.

Root fix: extend the existing `run_after_19-corp-ca-bundle.sh` hook to emit
a second, full bundle: Apple's current public roots, exported from
`/System/Library/Keychains/SystemRootCertificates.keychain`, followed by the
same self-signed admin roots. Not `/etc/ssl/cert.pem`: that is LibreSSL's 2021
list, it still carries the since-distrusted TrustCor and E-Tugra roots, and
Apple's curl honors `SSL_CERT_FILE`, so it would have regressed curl. Export `SSL_CERT_FILE` and `REQUESTS_CA_BUNDLE` to it from the same
`.zshenv` block, gated by the existing `tls_inspection` flag. Shells only:
the GUI domain keeps `NODE_EXTRA_CA_CERTS` alone. One mechanism and one flag for
every shell runtime. Alternatives rejected:
`truststore` injection (needs code in each script; misses curl and uv) and
`SSL_CERT_FILE` on the narrow bundle (breaks public TLS).

Check: `python3 -c 'import urllib.request;print(urllib.request.urlopen("https://api.github.com/").status)'`
prints 200 from an agent shell on work-mbp; the existing
`test_corp_tls_trust.py` suite asserts the full bundle contains the system
roots and only self-signed corporate roots beyond them.

### W4 · Conventions, one per failure shape

Each item states the evidence, the proposed rule, and why that rule rather
than a tool change. Owner: the machine `AGENTS.md` or the matching
`~/.agents/docs/*.md` topic.

**W4.1 · Leaf help after a usage error.** Evidence: 332 CLI-drift rows;
agents retried with a second invented flag more often than they read the
command's own help. Rule: after any usage error, read that command's help
before retrying; never guess a second flag. Why a rule: the CLIs are not ours;
the command cards in W2 fix the top three, and the rule covers the long
tail of 94 rows across `golangci-lint`, `gog`, `gh`, `orca` and local
scripts.

**W4.2 · Bounded output.** Evidence: 193 Codex truncations, 66 from
polling long processes with repeated `write_stdin`, 46 from unbounded
`rg`; each truncation loses the middle of the output and usually triggers a
rerun. Rule: bound every command's output (`rg -l`, `--max-count`,
`| head`, or redirect to a file and read the tail), and poll long processes
by tailing a log, not by reading their stdin. Why a rule: the harness cap is
fixed; the agent chooses the command.

**W4.3 · Re-read before editing.** Evidence: 125 Codex `apply_patch`
context mismatches, concentrated in sessions where a formatter, a test run
or another agent changed the file after the last read. Rule: re-read the
target region immediately before a patch whenever anything else may have
touched the file. Why a rule: the patch tool is correct to refuse; the
stale read is the defect.

**W4.4 · Recover authorized authentication.** Evidence: 21 rows across
five providers; `gcloud` could not prompt in a non-interactive shell and
m4mini `gh` returned 401 seven times over ten days. On an authorized task,
check credentials and supported second factors available in the session or
Devland before asking. Use an interactive path when a CLI cannot prompt,
then verify signed-in state. Ask for inaccessible factors, human hardware or
biometrics, or a decision outside the task. A repeated 401 after one
diagnostic retry is a blocker, not a reason to loop. Run `gh auth status` on
m4mini once. The four `cursor-agent` login rows are covered by this rule;
acpx's per-machine route declarations already decide whether a cursor-backed
shortcut exists on a host.

**W4.5 · Worktree ownership.** Evidence: 14 rows of `is already used by
worktree`, mostly `git checkout master` inside a monorepo worktree, plus 9
dirty-tree refusals. Rule: run `git worktree list` before checking out a
branch; work in the worktree that owns it or use `git -C <owner>`. Why a
rule: git is right to refuse; the fix is knowing the layout, which the
worktree convention already describes.

Acceptance: each target shape halves over the next 30 days of covered
sessions.

### W5 · Periodic session review, and complete data to review

Two independent items.

1. **A generic proposal for periodic review of agent sessions.** Not tied
   to the issues above. A `docs/plans/` proposal that says: on a cadence
   (completed-session retros, weekly incremental review, and monthly
   historical sweep as proposed defaults), take a snapshot of the local
   AgentsView store and archive, look for repeated failure modes and for
   optimizations the sessions make visible (wasted retries, slow steps,
   repeated manual prompts), and turn what recurs into fixes with acceptance
   checks. The
   proposal covers the snapshot procedure (copy-on-write clone of
   `sessions.db`, recorded max message timestamp), which scripts are kept
   and where (`scripts/audit/`), where reports live (private state, not the
   repo), and how each run re-checks the previous run's fixes. This
   review's tooling and its two regex corrections (`Exit code N` without a
   colon; the `(eval):` prefix for zsh errors) are the starting inputs, not
   the scope.
2. **Ask AgentsView to retain tool results for every harness.** Cursor
   sessions carry 95,837 tool calls in the window and zero retained
   results, so a third of the machine's sessions are invisible to any
   review. File the upstream request, with the parser evidence, once
   Prateek approves the filing.

Acceptance: the proposal is accepted, a bounded backfill produces a
coverage-aware report with checkpointed evidence, and a later enabled
schedule produces its first incremental report. The upstream request is
filed and linked from the proposal after approval.

## Sequencing

1. W1 and W2.1 first: smallest changes, largest effect, no external owner.
2. W2.2–2.4 as one agent-marketplace batch.
3. W3 as three independent changes; the TLS one needs work-host access.
4. W4 in a single conventions PR.
5. W5 whenever; the proposal is independent of the fixes.

## Risks

- Turning off `nomatch` everywhere means `rm *.tmp` with no match passes a
  literal `*.tmp` to `rm`, which fails on its own; the typo guard moves
  from the shell to the command. `unsetopt equals` only matters to
  someone who types `=cmd` on purpose.
- Word splitting stays zsh-style, so a pasted bash idiom like
  `CMD="a b"; $CMD` still fails (8 confirmed failures in the window). W1
  step 4's quoting rule covers it; revisit `shwordsplit` if the count grows
  after W1 lands.
- `trusted_config_paths` trusts every future repo under the listed roots.
  The roots are Prateek-owned by construction; do not add `~/code/github.com`
  wholesale.
- The agent-slack patch drifts from upstream on every bump. Keep the card
  in a patch file under the package's `patches/` so the reconciler reports
  conflicts.
- Coverage-based acceptance checks (W1 to W4) depend on archive sync
  working and on the periodic review existing; without them, silence can
  be missing data.

## Validation

- `just test-docs-lifecycle` for this doc.
- `scripts/audit/zsh-fresh-shells.zsh verify` after W1.
- `just check` in `agent-marketplace/` after W2, then
  `chezmoi apply --dry-run --verbose --exclude=scripts`.
- `just test-python -p test_corp_tls_trust.py` after the W3 TLS change.

## Pending host verification: work TLS

The W3 TLS change could not be exercised on a TLS-inspecting host. The first
agent working on work-mbp (`tls_inspection = true`) after this change is
applied there must verify it before relying on it, and record the result here.

1. Confirm the bundle exists and starts with public roots:
   `grep -c 'BEGIN CERTIFICATE' ~/.config/certs/corp-ca-bundle-full.pem`
   should exceed the count in `~/.config/certs/corp-ca-bundle.pem` by about
   150, and `echo $SSL_CERT_FILE` in a new shell should name the full bundle.
2. From a new agent shell, each of these must succeed:
   - `python3 -c 'import urllib.request; print(urllib.request.urlopen("https://api.github.com/").status)'`
   - the same against an internal HTTPS endpoint, such as the Buildkite API
     that produced the 72 certificate failures
   - `curl -sI https://example.com` and `curl -sI` against the internal endpoint
   - a `uv` fetch, for example `uv run --no-project --with pyyaml python -c 'import yaml'`
     from an empty directory with the uv cache cleared for that package
   - `git ls-remote https://github.com/prateek/dotfiles`
3. If anything fails with a certificate error, roll back by deleting
   `~/.config/certs/corp-ca-bundle-full.pem`; new shells stop exporting the
   variables because the export requires the file to be readable. Then report
   which client failed and whether it passes with the variables unset.

## Open questions

- What creates the `dotfiles-land-orca-*` checkout (W3, mise).
- Where droidcli's agent guidance lives; it is outside this repo.
