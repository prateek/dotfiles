---
status: archived
doc_type: plan
owner: Prateek
created: 2026-07-04
updated: 2026-09-06
closed: 2026-09-06
related:
  - config-merge-verification-plan.md
  - ../adr/0021-shared-plist-verification.md
  - ../references/chezmoi-architecture.md
  - ../adr/0022-bats-and-zsh-test-support.md
  - ../adr/0002-zsh-fresh-shell-validator.md
  - ../adr/0005-mise-tool-management.md
  - ../research/shell-testing-framework-comparison.md
current_guidance: ../../tests/README.md
status_detail: "Completed and landed. Local validation and remote Linux Shellcheck, macOS behavior/dry-run, and formula-install checks passed on 2026-09-06 for ec9fa8e. Remote receipt: https://github.com/prateek/dotfiles/actions/runs/34018476135. The scoped chezmoi apply and generated-plugin verification passed; optional exact-Claude and VM lanes remain separate."
---

# Test refactoring plan

Build a suite that protects useful behavior and is inexpensive to extend. Use
Bats for shell command tests, small repo-owned zsh scenarios for shell state and
PTY interactions, and native Python or Node runners where they fit the subsystem.
Make composes those runners; each runner owns test discovery.

This plan owns implementation under [ADR 0022](../adr/0022-bats-and-zsh-test-support.md).
Production migration is implemented. The local PTY/process gate passed; its
maintained support and cases now run through discovery. When revisiting the choice, read the
[decision trail and alternatives](../research/shell-testing-framework-comparison.md#decision-trail);
comparison history and summarized findings live there.

## 1. Choose the first slice and preserve its guarantees

Start with the `ghc`/`ohc` command cases. Read their current tests, production
entrypoints, Make targets, and CI invocation. Use the
[useful-test criteria](../../AGENTS.md#validation) to give each existing assertion
a disposition: retain, replace, consolidate, or omit.

Record the public guarantee, independent expected result, plausible defect, and
replacement or omission reason with the migration change. Include tool and
platform prerequisites, live-state effects, and the actual execution lane. Run
the current focused checks and distinguish existing failures from migration
regressions. Repeat this inventory for each later subsystem before editing it.

Shared plist verification landed on `master` in `755c1cd` under
[ADR 0021](../adr/0021-shared-plist-verification.md). Read its
[implementation evidence](config-merge-verification-plan.md) and
[current guidance](../../tests/README.md#plist-merge-verification) before that slice.
Reuse `tests/config_merge/`, which covers every shipped plist modifier, including
Tuna, with independent app ownership and native-type assertions. Preserve its
hyphenated deletion regression, existing Make/CI entrypoints, and format-specific
merge semantics. JSON/TOML consolidation and fixture isolation now use native
discovery; the broader runner migration and its evidence are recorded below.

**Done when:** every assertion in the selected slice has a disposition, every
retained guarantee has an observable seam and independent expectation, and the
baseline result and dependency state are recorded.

## 2. Prove the zsh and process boundary

Use a disposable experiment in an ignored scratch directory with Bats 1.14.0,
bats-support 0.3.0, bats-assert 2.1.0, and an explicitly selected Bash interpreter;
start with the evaluated Bash
5.3.15. Select tools through mise under
[ADR 0005](../adr/0005-mise-tool-management.md), pin helper dependencies, and record
the actual zsh binary and version used by each scenario.

Exercise one real prompt interaction from [plist-hooks.bats](../../tests/bats/hooks/plist-hooks.bats),
one parent-exit case from [sudo-keepalive.bats](../../tests/bats/hooks/sudo-keepalive.bats), and
the byte-sensitive stream behavior in [poll-stream.bats](../../tests/bats/programs/poll-stream.bats).
Begin with ordinary `.zsh` scenario files callable directly by a shell. Extract
only the shared mechanics these cases require.

| Boundary | Required behavior |
| --- | --- |
| Shell state | Perform dependent operations and observations of `PWD`, variables, arrays, and options in the same zsh process. Forward arguments literally and preserve normal zsh semantics. |
| Capture | Propagate status, keep stdout/stderr separate, and capture exact-byte contracts in files. Every Bats `run` call asserts the expected status. |
| Startup | Choose the intended shell and startup mode explicitly. For startup-placement checks, exercise inherited and unset `ZDOTDIR` with the target value cleared. |
| PTY | One zsh process owns terminal creation, interaction, and destruction. Wait for observable readiness with a deadline; retain a transcript on failure. |
| Processes | Preserve the parent relationship under test. Track and reap children; close inherited reporting descriptors where Bats requires it. |
| Isolation | Use temporary home/XDG paths, isolate Git configuration, routing variables, and hooks, and set `DOTFILES_SKIP_LAUNCHCTL_SYNC=1` for synthetic shells. Substitute external executables while exercising real repo code. |

For each representative case, introduce a plausible defect in a scratch copy,
observe failure for the intended reason, and restore the passing version. Check
arguments containing spaces/metacharacters and cleanup after partial setup,
assertion failure, and supported cancellation paths. Observe resource cleanup
before any outer experiment driver removes leftovers.

Keep fresh-shell correctness, `doctor`, `selftest`, and benchmarking in the
single [zsh-fresh-shells.zsh](../../scripts/audit/zsh-fresh-shells.zsh) implementation
required by [ADR 0002](../adr/0002-zsh-fresh-shell-validator.md). That validator
retains real host `/bin/zsh` PTY authority and pinned `zsh-bench`; shared app-hook
support must leave that ownership intact.

**Done when:** each case passes, rejects its deliberate defect, preserves its
shell/process contract, and leaves no owned process, PTY, or fixture behind on
the tested failure paths. If a case requires a new protocol or assertion language,
retain its native harness and simplify the boundary before wider migration.
Record the outcome, promote only useful production tests and support, and remove
the experiment scaffolding and raw output when the question is resolved.

## 3. Establish production discovery and one command path

Promote the useful `ghc`/`ohc` cases and the support they need. Create these
locations as cases require them:

- `tests/bats/<subsystem>/`: shell command cases.
- `tests/scenarios/<subsystem>/`: zsh operations and same-process observations.
- `tests/support/`: fixture isolation, capture, and proven PTY/process mechanics.
- `tests/python/<subsystem>/`: consolidated structured-data cases using native
  discovery; prefer `unittest` unless the subsystem already has a runner.

Keep expected behavior in the cases. Helpers own repetitive mechanics. Existing
subsystem test locations may stay where their native runner expects them,
including the Raycast extension's Node tests. Commit only the cases and support
that belong to the maintained suite.

Implement this command contract with thin Make targets:

| Target | Responsibility |
| --- | --- |
| `test-shell` | Invoke pinned Bats discovery under `tests/bats/`; allow focused filters. |
| `test-python` | Invoke native discovery for consolidated Python cases. |
| `test-ci` | Compose static checks and supported behavior suites without mutating live machine state. |
| `test` | Delegate to `test-ci`, making the default local check match that CI lane. |
| Existing host, benchmark, installation, and Tart targets | Remain explicit operator lanes with their prerequisites. |

Start the behavioral CI lane on macOS. Preserve the Linux shellcheck job and
installation checks; validate on Linux before claiming portable behavior.
Have CI invoke the same suite targets as local development. During migration,
keep the existing focused CI selection in one transitional Make aggregate and
remove CI's duplicate list. Remove each legacy entry as its replacement joins
native discovery.

Ordinary Bats cases enter CI through discovery. Mark exceptions with `host`,
`network`, or `vm` tags and document their reason and manual invocation. Restrict
Python discovery to CI-safe roots. Required suites fail visibly for missing tools
or unexpected empty selection; report expected skips with reasons and distinguish
an entirely skipped suite from verification. Use runner-native selection and a
small selection check where necessary.

**Done when:** the first slice passes locally and in the macOS CI lane using the
same entrypoint; adding an eligible case requires no per-file target or manifest;
manual exclusions, missing tools, empty selection, and deliberate assertion
failure produce the intended visible outcomes.

## 4. Route agents to the implemented workflow

Update guidance in the same changes that introduce or retire commands. Publish
only runnable instructions. Apply `mattpocock:writing-for-agents`: keep durable
policy in one place, put execution details beside their owner, and use
conditional pointers for specialized work.

Update [AGENTS.md](../../AGENTS.md) to retain the concise useful-test contract:
a named guarantee, a plausible defect, resilience to harmless refactoring,
independent expectations, justified omission/replacement, and assertions for
expected failures. Move detailed dotfiles test workflow to
[tests/README.md](../../tests/README.md). Add this conditional pointer:

> When adding, migrating, replacing, or removing tests, read `tests/README.md` for
> framework/seam selection, fixture isolation, execution lanes, and focused checks.

Replace AGENTS' cached CI roster with the index pointer as commands migrate.
Preserve its shell safety, real-PTY, and local Tart rules. The tests index owns
the current command/area map, prerequisites, exclusions, and new-test procedure.
Include one worked Bats example with independent expectations and links to the
actual zsh scenario/support interface. Describe proposed targets as current only
once they are runnable.

Update these skill sources when their affected lanes migrate:

| Source | Required change |
| --- | --- |
| [chezmoi-management](../../.agents/skills/chezmoi-management/SKILL.md) and [app-config](../../.agents/skills/chezmoi-management/references/app-config.md), [workflow](../../.agents/skills/chezmoi-management/references/workflow.md), [packages-and-secrets](../../.agents/skills/chezmoi-management/references/packages-and-secrets.md) | Replace duplicate Make lists with task-specific pointers into the tests index. Preserve render/parse, real merge ownership/security, dry-run, and hook PTY obligations. Preserve the corrected distinction between `test-config-merge` modifier verification and `test-plist-hooks` apply-time hooks. |
| [ChezMoi skill maintenance](../../.agents/skills/chezmoi-management/references/meta-skill-maintenance.md) | Change the new-lane update procedure to maintain the authoritative tests index and relevant pointers. Keep mode-specific triggers and run its bundled `evals/validate.py` after edits. |
| [agent-skill-management](../../.agents/skills/agent-skill-management/SKILL.md) | Route package-schema changes to every distinct validator, renderer, and consumer merge check through the tests index. Remove the stale four/five-script count; preserve temp-root validation, generated-state constraints, and separately identified native CLI checks. |
| [land-changes](../../.agents/skills/land-changes/SKILL.md) | Make Validation Gates read the tests index for changed-area checks, with Make/CI as executable truth. Preserve the existing landing procedure. |
| Other command consumers, including [benchmark-zsh-startup](../../.agents/skills/benchmark-zsh-startup/SKILL.md) and [fork-lifecycle](../../.agents/skills/fork-lifecycle/SKILL.md) | Update pointers when their commands change. Preserve the ADR 0002 authority described in step 2 and the fork reconciler's behavioral checks. |

Update the [chezmoi architecture reference](../references/chezmoi-architecture.md)
alongside the app-config slice: retain the landed shared plist verification
and tests-index routing, and update its command pointers as lanes migrate.
An ordinary preference edit should use the checks that cover its risk.

The shared [testing-philosophy](../../agent-marketplace/packages/core/skills/testing-philosophy/SKILL.md)
already explains deliberate omission. Reconcile its earlier “never whether to
test” wording with that guidance in one narrow edit; keep dotfiles runners and
paths out of the machine-wide skill. Existing
[code-gardening](../../agent-marketplace/packages/core/skills/code-gardening/SKILL.md)
already covers source authority and synchronized validation, so it needs no
content change for this plan. Use the existing vendored `mattpocock:tdd` and
`writing-for-agents` guidance unchanged.

Edit tracked sources under `.agents/` or `home/dot_agents/packages/`, according to
their ownership. Use `agent-skill-management` for package-source changes and its
isolated source/render validation. Any later justified vendor change must follow
its vendoring workflow and record the local delta in `SOURCE.md`.

**Done when:** each affected instruction reaches an existing command or support
contract, all distinct subsystem validation obligations remain reachable, and
validators for changed skills/packages plus docs lifecycle checks pass. Follow
the documented routes for an app-config change, a zsh behavior change, and an
agent-package change to verify the conditional pointers.

## 5. Migrate one subsystem at a time

For each group, repeat the inventory and baseline from step 1, port useful
behavior, prove uncertain replacement assertions with deliberate defects, update
its execution lane and guidance, then retire replaced assertions. For an actual
bug fix, follow `mattpocock:tdd`: one intended failing behavior to green at a time.

| Group | Contracts to preserve |
| --- | --- |
| Config merges, reusing the landed plist verification | Independently specified transformation and ownership, app-owned data, deletion and invalid-input behavior, and unchanged bytes. Preserve each format's merge semantics, including plist top-level replacement. |
| Streams and app hooks | Exact offsets/output, timeouts, prompt behavior, and lifecycle cleanup through the support proven in step 2. |
| Package/install reconciliation | Gating, dependency ordering, no unnecessary work, and failure propagation through external tool boundaries. |
| Agent configuration and other apps | Security, preservation, and launch contracts; evaluate preference snapshots individually against the useful-test criteria. |
| Trace and generated formats | Input/output mappings, private artifact permissions, and meaningful diagnostics using native structured assertions or parsers. |

Discover renderable inputs for cheap format checks where practical. Add a
specialized behavior case when it protects a distinct contract. Use Python for
decoded plist/JSON/TOML assertions where that improves clarity; shell syntax alone
does not determine the runner.

**Done for each group when:** all retained guarantees have passing replacements,
every removed assertion has an accounted-for replacement or omission reason,
and relevant local checks and the affected CI lane pass. If a port obscures
failures or introduces flakes, restore that group's previous entrypoint with its
useful assertions intact and resolve the cause before proceeding.

## 6. Finish selection and close the plan

Account for every remaining test group, including tests the old CI list omitted.
Place each in native discovery, an existing subsystem command, or an explicit
manual lane with a reason. Remove the empty transitional aggregate and retired
entrypoints; update their consumers in Make, CI, skills, and the tests index.

Verify default discovery, manual exclusions, required-suite failure behavior,
and representative harmless implementation changes. Report local macOS,
remote CI, Linux, host-app, and VM evidence separately; record any unexecuted
lane with its limitation. Run the relevant final checks, docs lifecycle
validation, and `git diff --check`.

**Done when:** every retained group has an execution path; every deletion has a
disposition; the zsh/process gate and required local/CI lanes pass; and all agent
instructions describe the implemented workflow. Keep ongoing authoring guidance
in `tests/README.md` and focused support docs. Archive this plan with a
`current_guidance` pointer and update [docs/index.md](../index.md).


## Execution evidence

### First-slice inventory and baseline

On 2026-09-05, at `1c2edd9`, `test-ghc`, `test-plist-hooks`,
`test-sudo-keepalive`, and `test-acpx-poll-stream` passed with a temporary
home/XDG environment and `DOTFILES_SKIP_LAUNCHCTL_SYNC=1`. These are local
macOS results; the new runner has not yet been exercised in remote CI.

The `ghc`/`ohc` slice uses the public autoloaded commands, their status and
streams, the caller's working directory, and the external Git/Orca command
boundaries. Git and Orca are substituted; no remote clone or live Orca mutation
is needed. Every existing assertion is retained in these groups:

| Existing assertion group | Independent expectation and plausible regression | Disposition |
| --- | --- | --- |
| Explicit GitHub URL | SSH clone URL `git@github.com:prateek/w.git` and canonical `GHPATH/prateek/w`; catches malformed normalization or wrong destination. | Retain as a Bats case; also observe the resulting directory in the same zsh process. |
| Missing `ohc` argument | Status 2, usage and help hint on stderr; catches silent success or wrong stream. | Retain as a separate Bats case. |
| `ohc --help` | Documents base branch, agent option and owned repo selector; catches unusable or misleading help. | Retain; do not snapshot the entire help text. |
| Repo selector override | Status 2, diagnostic naming the option, no Git clone; catches accidental work before argument rejection. | Retain and check no Orca mutation. |
| `ohc` worktree creation | SSH URL, canonical path, path-based repo selector, default name, forwarded agent; catches wrong repository selection or lost options. | Retain; add literal argument forwarding with spaces and shell metacharacters. |

The starting compatibility tools are Bats 1.14.0, bats-support 0.3.0,
bats-assert 2.1.0, Bash 5.3.15 selected through an ignored mise path override,
and `/bin/zsh` 5.9. The existing downloaded helper archives are disposable
local dependencies. Gate scaffolding belongs under ignored `build/` and must
be removed after findings and useful production support are retained.


### Compatibility and first production slice

The seven initial Bats compatibility cases passed locally with the selected
tools: real plist-hook acceptance; exact NUL/newline stream chunks and offsets;
sudo parent-exit cleanup; PTY timeout with transcript; SIGTERM cleanup; literal
PTY arguments and status 23; and SIGINT cleanup. Independent scratch mutations
removed the prompt, appended an extra output newline, and kept the sudo loop
alive after parent exit. Each failed for its intended defect.

The gate found two adapter mistakes: `zpty` evaluates command text, requiring
argument quoting, and zsh exit traps can be inherited by command substitutions
and PTY subprocesses. A subshell-depth check alone did not prevent a transcript
race. The promoted PTY support checks its actual owning process ID. Bats
reporting descriptors are closed before zsh execution with a small exec boundary;
command status and streams remain native process results.

The five `ghc`/`ohc` cases now live in `tests/bats/programs/github-checkout.bats`;
`make test-ghc` selects them through `make test-shell`. All original assertion
groups above are retained. Shared fixture, native zsh scenario, and PTY support
are in `tests/support/` and `tests/scenarios/`. Selection tests cover discovery,
empty/all-skipped failure, ordinary versus manual tags, assertion failure, and
missing Bats. These are local results; macOS CI, the remaining subsystem
migration, complete instruction routing, and final selection accounting remain
open. The implementation has not been pushed or committed during this goal.


### Stream migration

All prior `acpx-poll-stream.zsh` assertions are retained in ten Bats cases:
immediate pending data (under one second), growth wakeup, timeout (at least one
second), capped chunks, persisted offsets, missing-file growth, the 8192-byte
default cap, decimal leading-zero values, shrink diagnostics, read failure with
an unchanged offset, and all six invalid-usage inputs. Exact `cmp` comparisons
replace text-plus-byte-count comparisons and add NUL/consecutive-newline coverage.
The growth scenarios wait for a signal at the external `sleep` boundary, then
append after the real poll observes no data. The wrapper preserves the requested
sleep duration, and growth must return in under three seconds. A Python scenario
owns the poll process group, bounds readiness/completion, and terminates and
reaps its child on failure. `make test-acpx-poll-stream`
selects the Bats file, and the old monolithic script is removed.

### Plist-hook inventory

The original `test-plist-hooks` baseline passed before migration. Retain cases
A–E (running/nonrunning/skip/empty/container detection), F–I (empty/missing state,
one preference-cache nudge, optional relaunch), every pre/post dry-run form in
J, both explicit skip branches in K, L–N (accept, decline, stuck-app timeout),
and O–Q (relaunch only successfully quit apps, state cleanup, deduplication).
Expected bundle IDs and command effects come from fixture inputs and the hook
contract, not the hook's implementation. Preserve the real `pre`/`post` CLI and
real PTY prompt; substitute only chezmoi and the absolute macOS app executables.
Group repeated dry-run spellings as data and retain their distinct outcomes.


### Combined-lane integration finding

The first combined run passed docs and the migrated cases, then stalled on the
selection suite's deliberate failure. A standalone one-case reproducer isolated
Bats 1.14.0's optional global timeout from nested-run state: without
`BATS_TEST_TIMEOUT`, the expected failure returned in 0.110 seconds; with a
2-second timeout, the same failure returned after 2.222 seconds and printed a
watchdog `kill` diagnostic. Process inspection showed the watchdog surviving its
test process. The newly introduced default timeout was removed; scenario-owned
PTY/process deadlines remain. Explicit global Bats timeouts need separate
compatibility work before use. This did not change any behavior assertion.


The next combined-lane run passed all 24 discovered shell cases and the 12
native Python methods, then exposed an existing Xcode fixture mismatch. The
unchanged focused target reproduced it: `personal` no longer has the
`apple-development` group, so its rendered script correctly skips. The fixture
now uses `homelab`, which owns that group. The CI skip, absent/noninteractive
failure, forced install/setup/dependency calls, and installed-version reuse
assertions are unchanged. This is a baseline repair, not weakened coverage.

### Sudo lifecycle assertion inventory

The original `test-sudo-keepalive` baseline passed before migration. The public
seams remain `dotfiles_sudo_start`, `dotfiles_sudo_stop`, and
`dotfiles_admin_elevate`, loaded from the real script library with a fake `sudo`.

| Existing group | Retained guarantee and replacement |
| --- | --- |
| Cold and warm repeated start/stop | One cold validation and invalidation; warm credentials survive with neither. Observe helper liveness, reuse, and removal of state in the same Bash scenario. |
| Separate managed scripts | One long-lived chezmoi parent shares a helper across short-lived wrappers; preserve actual ancestry and the original polling interval observation. |
| Parent lookup race | Starting succeeds when ancestor queries fail, with the immediate parent recorded. Replace the private lookup-only assertion with a real start/stop scenario. |
| Stale and absent parent markers | Restart replaces the old process, removes stale state, and preserves warm credentials. |
| Parent exit | The helper process and all state disappear before outer fixture cleanup; preserve the compatibility gate's bounded observation. |
| Jamf, already-admin, and opt-out | Exactly one configured Self Service URL for elevation; no launch for existing admin membership or explicit `none`. |

No credential, lifecycle, or elevation assertion is omitted. Process-owning
scenarios clean up their children on assertion failure; Bats closes inherited
reporting descriptors before executing them.

### Cursor config inventory and baseline

The original Cursor modifier check passed its merge, credential/model/permission
preservation, idempotence, unchanged-byte, empty-input, and CLI-gating assertions,
then failed its Linux headless assertion. Commit `435e0fb` explicitly retired that
pilot and removed its second ignore block. Omit that retired-profile assertion;
retain the current `agent_clis` gate and add its machine-local override case.
Move the decoded JSON cases to native Python discovery, with the marketplace's
required directory/source specified independently of the desired fragment.

The wider baseline also exposed an inactive uv shim under temporary HOME.
Pinning uv 0.11.26 alongside Python makes the CI entrypoint resolve a concrete
executable before fixture isolation. No application template changes are needed.

### Console baseline repairs and native boundary

The console suite now reaches its behavioral checks under the pinned uv runtime.
Its template-key case incorrectly expected the real, now-templated Claude settings
fragment to be plain JSON. It now retains malicious-key rejection, explicitly
checks the real template is refused unchanged, and exercises a valid edit against
an independent plain-JSON fixture with an unrelated key preserved.

The remaining CLI dry-run failure is an external-version prerequisite: installed
Claude has hash `625869b01e0050f260b2980fac248fd9cef9e462612bded4ec9d3d49ff8969a5`,
while the console constants record
`b63136194160791c27cfa7b0403060d85eb0752991625fde8c09f9acacb17c78` (2.1.258).
The real CLI correctly rejects that simulation with V10. Retain the producer
fragment verification and successful render/apply cycle in an explicit host
lane requiring that recorded build. Ordinary tests use an unrecognized fake
executable and assert rejection and unchanged files; they do not certify the
installed producer or rewrite its recorded constants.

### JSON modifier inventory

`test-crit-config`, `test-orca-settings`, and `test-pi-settings` passed in the
baseline sweep. Their replacement uses native Python subprocess discovery.

| Group | Retained guarantees / disposition |
| --- | --- |
| crit merge | Set or retire exactly the three owned launch/notification keys; preserve auth, consent, Unicode, port, and arbitrary local keys; keep stale-command replacement, empty input, no-churn, and CI no-file behavior. |
| acpx rendering | Retain machine-specific adapter selection, model flag and ACP ordering, plugin reachability, filesystem-dependent marketplace path, and empty CI map. Shortcut names identify public commands rather than an arbitrary count. |
| Orca | Preserve repos, worktree metadata, active session, Unicode bytes, and local settings; enforce base plus work/homelab overlays, absolute workspace destination, absent settings recovery, and no-overlay CI behavior. Retain the existing small literal profile examples while consolidating their repeated merge checks. |
| Pi | Preserve provider/model/theme/trust and custom packages; required package dependency order and deduplication; merge vim subkeys while preserving custom modes; replace the statusline unit; empty recovery and idempotence. Preserve renderer schema, no leaked metadata, marketplace autoupdate policy, and enable-state parity with Claude. |

No useful behavior assertions in these groups are omitted. Pi's isolated
launcher remains a separate shell group until its own migration.

### Pi launcher inventory

The baseline Pi launcher case passed. Retain generated settings, executable
statusline and session-directory creation, three isolated environment variables,
package update before launch, `--no-install`, automatic dry-run cleanup, mixed
positional arguments, and help without script-body leakage. Consolidate its
full package/vim preference snapshot into the native Pi modifier tests; here,
check that printed settings equal the materialized file and contain the required
statusline consumer. Add a fake Pi invocation to observe the actual environment
and literal arguments rather than relying only on printed dry-run commands.


### Promoted support and guidance validation

The promoted suite passed 49 ordinary Bats cases, including 13 plist-hook and
8 sudo lifecycle cases, Python selection failure behavior, and PTY partial
setup, timeout, SIGTERM, and SIGINT cleanup. The promoted sudo parent-exit
scenario also rejected a scratch infinite-loop defect, reported the intended
cleanup deadline, and terminated its owned helper before outer teardown. The
resolved compatibility scaffolding and raw output under `build/test-support-gate`
were removed; pinned dependency caches remain disposable.

Cursor, crit/acpx, Orca, and Pi JSON cases passed as 16 native Python methods.
The Pi launcher then passed six Bats cases. Their old shell entrypoints were
retired, and native discovery replaces their transitional CI entries. The seven
five-line plist wrappers contained no assertions; Make now invokes their existing
native app selections directly, preserving the shared plist suite unchanged.

The chezmoi skill validator, package-source validator, isolated plugin rendering
and `--check`, guidance link/anchor audit, and docs lifecycle check (75 docs
against `origin/master`) passed. The app-config, zsh, and agent-package routes
reach the tests index and retain their distinct ownership, PTY, native CLI,
and installation obligations. The narrow machine-wide testing-philosophy edit
now agrees with its existing deliberate-omission guidance.

### Codex and Claude modifier inventory

Both original focused checks passed in the baseline and combined lanes.
Codex retains managed defaults, full pager mapping, marketplace override and
nested sibling preservation, project trust, hook approval/hash state, foreign
and stale plugin tables, package-policy booleans, comments, unchanged bytes,
and empty-file seeding. The small existing default/keymap examples remain
independent literals; package enable expectations come from the input manifests.

Claude retains permission and foreign-marketplace state, owned statusline and
budget application, generated-marker exclusion, work-only plugin suppression,
manifest-driven enable policy, stale/foreign plugins, nested siblings, and
unchanged bytes. Keep independent hook matcher examples for replacement,
retirement, event cleanup, preservation of other events, and intentional removal
of foreign blocks under an owned matcher. Its synthetic managed fragment remains
input data passed through the real rendered modifier. No old assertion group is
omitted.


Codex's four and Claude's six replacement methods passed locally. Their Make
entrypoints now select native discovery, and their transitional CI entries and
old shell files are retired. Shared plist verification also passed after adopting
the Python fixture's temporary HOME/XDG/Git state; its ownership, exact native
types, invalid-input, and unchanged-byte assertions remain intact.

The staged console validator exposed repeated tool activation inside temporary
source copies. Make now selects its pinned runtime once and passes that context
to nested validation; it does not load an ignored `mise.local.toml` from the
staging tree. Direct `make test-ghc` and `make test-cursor-config`, and the full
console suite, passed with this setup.

Git tracing identified the vendor-fixture cleanup race: its initial large commit
launched detached `git maintenance run --auto`, followed by repack, while the
fixture was being removed. Automatic maintenance is now disabled in that
throwaway repository, and cleanup errors propagate. The focused vendor check
passed without leftover-directory diagnostics. No live Git maintenance setting
was changed.

### Small command and render groups

The combined local `make test-ci` completed with exit status zero after the
runtime and cleanup repairs. This is local evidence; remote CI remains open.
The following original focused checks passed before replacement (Finder also
passed in the combined lane).

| Group | Replacement guarantee and disposition |
| --- | --- |
| Cursor launcher | Native zsh loads the real alias and forwards the required model/yolo flags and literal caller arguments. |
| Kanata | Keep the real parser check as an explicit host lane requiring Kanata; ordinary CI does not provision that application. |
| Finder Quick Action | Retain native plist parsing and service recognition, independent Finder/Automator declarations, integer input mode, private Services permissions, and selected paths copied one per line. Exercise the command instead of snapshotting its source. |
| Brew inventory | Preserve official-tap name normalization, paired with independent missing, extra, and dependency examples so an empty report fails. |
| Fork entry editor | Preserve add/remove diagnostics, decoded cask/formula entries, repeated-operation no-churn, and unrelated package groups. |
| Elevation render | Source the rendered script to observe method/default policy, top-level identity, legacy fallback, and missing-value handling. |
| Tartelet settings | Replace implementation-string assertions with real rendered execution against fake external app commands. Preserve typed defaults, credential exclusion, machine gating, and host store selection; observe convergence and relaunch ordering. |
| Tartelet wrapper | Preserve its required Homebrew endpoints, softnet injection, unchanged-file reuse, missing-grant warning, and empty personal render through actual installation and invocation in a temporary tree. |
| Zed | Retain rendering and JSONC parsing. Omit exact extension/font/theme/panel preference snapshots: they duplicate editable preferences and protect no separate behavior or ownership boundary. This does not claim native Zed schema validation. |

The new neutral-host Tartelet settings case failed before execution because
`$f.tart_home` dereferenced a missing optional key; `default` never received it.
The original baseline inherited the current host's store fact and masked this.
Use `dig` for the documented empty-store fallback, then require the same
regression case to pass with no store write and no app launch. This is the only
production behavior correction in this slice. A separate fixture quoting error
in the softnet path substitution was corrected in test support only.

All eight replacement Tartelet cases now pass, including that regression.
The other small groups passed six native Python methods, two ordinary Bats
cases, and the explicit Kanata parser case. Their old entrypoints are retired.

### Agentsview, initialization, and meeting-sync inventory

All four original focused suites passed before migration. Agentsview retains
credential/custom-key/comment preservation, four independently named local Codex
roots, sorted archive sources with the local host excluded, stale host pruning,
empty/no-clone initialization, and exact-byte idempotence. Its comparison with
the separate wiki checkout becomes an explicit host case instead of a silently
optional branch in ordinary CI.

Chezmoi initialization retains persisted and effective pager/machine identity,
exclusion of the retired install profile, and migration of legacy nested Jamf
identity on re-init. The local-ignore case retains every named secret/local
path exclusion and the positive unmanaged marker. Both use native TOML/JSON
assertions and isolated real chezmoi commands.

Gemini meeting sync retains zsh/config parsing, enable marker and generated
defaults, expanded output path, successful status JSON with the fake producer's
run directory, and the missing-producer diagnostic. The real wrapper remains
the seam; a fake producer substitutes the network-dependent importer. No old
assertion group is omitted.

The replacement Agentsview and chezmoi cases passed five native Python methods;
the Gemini wrapper passed three Bats cases. The explicit Agentsview/wiki parity
case passed against the installed separate producer. Old shell harnesses and
their transitional CI entries are removed.

### Convention graph, VM helpers, and mise installer inventory

The four original focused checks passed. Convention routing retains one
nonempty pointer section, pointer syntax/uniqueness/source existence, coverage
of every named convention, transitive reachability from the pointers, missing
link rejection, and the generated Slack source mapping. Native Python replaces
shell text-processing plumbing; the test continues to validate real repo docs.

The install-log scanner retains its clean example and every independent failure
literal and diagnostic across LaunchServices, sealed-system, Spotlight, Dock,
dynamic loader, mise attestation, systemsetup, Universal Access, and Safari.
The macOS postflight cases retain successful named app/system reports, hidden
file drift, pending-hook state, and nonempty chezmoi status. Replace fixed total
counts with consistency between emitted results and summary totals; retain
independent expected failing check IDs. These fixtures do not boot a VM or
certify live preferences.

The mise installer retains the persisted attestation opt-out, runtime default,
config trust, Node and Go before dependent tools, and `mise exec node` for the
remaining install. It executes the real rendered script with a fake mise and
asserts required calls in order. No retained guarantee requires real installs.

These replacements passed one native graph check and nine Bats cases. Their old
shell files and transitional CI entries are retired.

### Trace tooling inventory

The original focused trace suite passed. Retain converter/summary parsing,
secret-name and secret-flag redaction, semantic/major/all-command separation,
independent PID-offset and track-name/layout examples, integer timestamps and
positive durations, and metadata for every complete event. Native Python can
assert these structured outputs directly without shell JSON here-doc plumbing.

Retain the loopback-only viewer URL and idle exit without opening a browser;
real zsh stdout and artifact capture; private run-directory/log/trace/merge
permissions; merged JSON; missing-input diagnostics; command-failure propagation;
and conversion-failure propagation plus both manifest statuses. Preserve the
Tart help's trace opt-in and absence of the retired bootstrap trace variable.
No assertion group is omitted; repeat assertions of the same track relationship
are consolidated. No VM or external browser service is contacted.

The seven native trace methods passed locally, including bounded viewer exit.
The combined local CI lane also completed with status zero after the preceding
small-group migrations. The separate native Claude producer check remains
uncertified, and remote CI has not run.

### Repository index, color archive, and prompt inventory

All three original focused checks passed. The index retains canonical clone
TSV/slug output, exclusion of `.git` file worktrees, and invalid-format status
and diagnostic. Empty real Git repositories suffice: no guarantee reads commit
history, so omit fixture commits.

nvALT retains valid source JSON and native keyed-archive output, independently
named color entries and RGB literals, and exact-byte preservation of a
semantically equal binary archive. Native plist decoding replaces shell glue;
the current independent archive example remains intact.

The Pure prompt retains the four machine/color mappings, including unknown-type
fallback, and same-process local-host display versus Pure's existing host flag.
Observe `zstyle` after sourcing the real render instead of grepping its source.

These replacements passed five Bats cases and one native archive method. Their
old harnesses are removed, and trace tooling now also uses native discovery.

### Existing native storage and iOS suites

Keep the existing native test methods and assertions. Storage covers healthy
and missing mounts, ownership repair, unrelated fstab preservation, unsafe
volume refusal, local data/symlink protection, busy-volume refusal, conflicting
entries and locked-editor recheck, pre-apply ordering, dry-run/option parsing,
both shell startup paths, first init/apply, literal inline/file overrides, and
host/OS gating. Move that already-native file into Python discovery and adopt
shared environment isolation. Its fstab fixture keeps a whitespace-free root
because its literal mount entries use the ordinary unescaped fstab form.

The iOS audit's source-owned native suite remains beside its skill. Make invokes
it with the required Python runner as its own discovery root; do not move these
tests away from the source paths they validate or alter their existing
workflow, rendering, storage, and audit-output assertions. Both suites passed
their original focused entrypoints before changing routing.

The routed storage suite passed all 20 methods with shared isolation, and the
separate required iOS discovery passed all 16 existing methods. The old storage
entrypoint is removed; its cases are discovered under `tests/python/storage/`.

The current discovery lanes passed 82 ordinary Bats cases and 94 native Python
methods (66 consolidated, 12 shared plist, 16 source-owned iOS). Docs lifecycle
validated 75 docs against `origin/master`; focused shellcheck and diff whitespace
checks passed. Comment review removed two redundant module descriptions and
retained test data, directives, and the non-obvious PTY/FIFO boundary comments.
The remaining legacy groups, final command accounting, and remote CI evidence
are still required before this plan can close.

### Docs lifecycle assertion inventory

The original 2,153-line CLI harness passed in the focused and combined lanes.
Preserve its independent fixtures through native unittest methods with isolated
Git repositories; the validator CLI remains the seam, and no production helper
is imported. The migration covers these groups:

| Existing assertions | Replacement and disposition |
| --- | --- |
| Type/status matrix and frontmatter | Retain every accepted combination, seven rejected combinations, and all 31 literal malformed/invalid documents and their diagnostics. Preserve missing/empty fields, dates, successor forms, rationale, duplicate/unsupported keys, and restricted YAML syntax. |
| Roots, index, and links | Retain explicit/custom roots, custom `dev/` acceptance, required index/type/status, positive coverage, missing/misdirected targets, frontmatter-versus-body distinction, fenced-code exclusion, non-Markdown rejection, ignored bytecode, escaped successor paths, and retired `docs/dev` paths. |
| Worktree transitions and locked documents | Retain metadata-only edits, unchanged renames, accepted-ADR and closed-body locks, deletion refusal, missing-base diagnostics, close-with-body-edit refusal, allowed and forbidden type/status transitions, and relative link-target preservation during moves. |
| Linear branch history | Retain branch-created closures, malformed/invalid intermediate commits, moved closures below Git's rename threshold, editing before a later closure, hidden renamed closures in both worktree and commits, intermediate broken links/guidance, newly archived body edits, and unrelated duplicate-body replacement. |
| Merge history | Retain merge-base selection, synthetic review merges, nonlinear side branches, locked content introduced by a non-first parent, bad push merge resolutions, and feature merges of an advanced base. Use real Git objects for every graph. |

Repeated fixture setup and duplicate assertions of the same rule are
consolidated. No distinct rejection, successful transition, or history topology
is omitted. Each expected rejection keeps its named diagnostic, and successful
cases require the validator's success result.

All 36 native methods passed, including every history topology. A diagnostic
audit mapped all old named rejections; the misdirected-index fixture now reuses
the unindexed document's name while preserving its different link-destination
failure. Scratch defects disabling branch traversal or working-tree lock checks
failed for the intended accepted-invalid-change result. Renaming the validator's
private history helper preserved all 36 results. Scratch copies were removed.

`make test-docs-lifecycle` now runs native fixtures and then the checkout check.
`check-docs-lifecycle` is the static-only component; CI runs fixtures once via
Python discovery. The focused command passed and validated 75 docs against
`origin/master`. The old shell harness is retired.

### Claude and Pi statusline inventory

Both original focused suites passed. Preserve physical one-line rendering and
the documented `--logical` JSON seam, model/effort/directory/duration output,
subscription-versus-API billing, weekly-meter threshold, independently worked
context-token calculations, zero/unknown context suppression, and malformed
input handling in both modes. Claude retains current-usage precedence and
escaped-message exclusion when counting compactions; Pi retains its distinct
aggregate-token and `type=compaction` semantics. Preserve the managed Claude
command-path assertion. Native Python owns structured payloads and expectations;
the real POSIX shell scripts still perform every calculation and render.

The formerly optional Dash check becomes an explicit host case requiring an
installed Dash interpreter. It does not certify an unavailable interpreter or
silently disappear inside an otherwise passing ordinary suite.

All eleven native statusline methods passed, and the explicit Dash case passed
against the installed interpreter. The focused Make commands select their
native classes, and both old shell files are removed.

### Package installation hook inventory

The original gh-extension, Brew Bundle, Xcode, and Raycast hook suites passed.
Keep gh's missing-tool and per-extension failure warnings, installed-directory
skip, selected extension install, and empty-list behavior on selected Bash and
macOS system Bash. Supply empty groups as template input instead of deleting
generated shell lines.

Brew Bundle retains default and overridden concurrency, compatibility with
older Homebrew, independent package/trust and machine-gating examples, and
tap-before-bundle ordering. Observe the actual Brewfile handed to fake Homebrew.
Xcode retains no-group gating, noninteractive missing-install refusal, forced
install/select/setup and dependent formula installation, and installed-version
reuse. Decode an independent pin file with real jq; external installers and
administrator commands remain substituted.

Raycast retains its empty CI render, missing npm warning, both first-time builds
and registration hints, unchanged no-op, source edits, asset additions, source
renames, missing installed tree, dependency/build failures without advancing
stamps, successful retry, missing lockfile, and system Bash compatibility.
Build call counts protect avoiding unnecessary rebuilds. This hook was omitted
from the old aggregate; its replacements join ordinary Bats discovery.
No distinct assertion group is omitted.

All 22 replacement Bats cases passed, including real jq pin decoding, both
system-Bash compatibility cases, and Raycast's previous aggregate omission.
The four focused Make targets select these files; their shell harnesses and
the three former legacy aggregate entries are removed.

### Brew adoption, model drift, and wiki clone inventory

The original focused suites passed. Brew adoption retains the native zsh
autoload seam, exact worktree argv and prompt requirements, explicit opt-in
for permission bypass, bounded/normalized branch examples, helper autoloading,
and missing-helper/invalid-branch/existing-branch refusal before invoking the
worktree helper. Real local Git history supplies trunk and branch identities;
the wrapper never edits package contents, so a fixture commit need not contain
a copied package manifest.

Model drift retains the independent matching catalog, cross-tier newer GPT
and Claude examples, exclusion of Gemini Flash when checking Pro, newer Pro,
missing pins, and integration of the real template's public pin extraction
with a matching fake catalog. No live model service is queried.

Wiki cloning retains real local Git transport with filter advertisement,
sparse cones/shared paths, unfetched blobs, clean state, silent checks and
lock-free no-ops, held-lock refusal, alias changes and staging, read-only drift
reports and repair, remote identity across transports, dirty-path preservation,
full-to-sparse conversion and later lazy fetches, active-operation refusal,
widening and fresh full clones, ignored-filter and unreachable-remote refusal,
and every invalid alias/missing-value case. Independent literal blobs replace
random fixture bytes; the guarantee is which objects remain unfetched.
No distinct assertion group is omitted.

All 22 replacements passed (six Brew adoption, five model-drift, eleven wiki
clone cases). Focused targets now select their Bats files, and the three old
harnesses and legacy aggregate entries are removed.

### Remaining renderer and small-harness inventory

Tart's original helper baseline passed. Keep documented lanes/images/resources,
cache and trace switches, removal of `--profile`, all eight argument refusals,
the boot-disk guard before Tart calls, and MAS opt-in forwarding through the
substituted full-lane plumbing. These cases do not boot a VM.

Chezmoi script status retains an isolated real init/apply/status cycle with
installation disabled and externals excluded. The disabled wiki feature must
reach both allowed service stubs and make no unexpected launchctl/Orca calls.
The direct legacy command encountered the known temporary-HOME mise trust
failure; its baseline is being checked with the pinned runtime selected first.

Vendored patches retain the real CLI's applied-state check, nonempty discovery,
upstream path shape, reverse-order restoration to independently recorded
pristine hashes, refusal of the pristine tree, ordered reapplication, and
byte-identical package output. Copy the package tree needed by the CLI rather
than unrelated home files; Git needs a worktree, not a large initial commit.

Brewfile rendering retains every named machine/package and trust expectation,
MAS opt-in examples, independent mise ownership declarations, unknown-type
diagnostics, identical stdout/file output, trailing newline, and leading tap
section. Machine resolution retains all four compositions, absent-type default,
session archive defaults/type/host/alias invariants, local scalar overrides,
whole-list replacement, OS precedence, and unknown-type failure. Native Python
assertions replace shell eval and structured-data here-doc plumbing.

The pinned legacy baselines passed. The replacement full apply then exposed an
ambient-host dependency: Agentsview dereferenced missing `wiki_host_alias`
before `default` could supply an empty string. The focused unregistered-host
modifier test also failed for that missing key. Use `dig` for this optional
feature, preserving the empty-host behavior intended by the existing default.

The corrected Agentsview cases and complete isolated apply/status cycle passed.
The four Tart cases and sixteen native renderer/machine/vendor methods also
passed. Their five focused Make targets now select discovery, their legacy
aggregate entries and old harnesses are removed, and missing chezmoi no longer
silently skips the machine-resolution command.

### Previously omitted defaults, secrets, and keyboard checks

The original macOS-defaults, secret-backed-files, Karabiner/Goku, retired-package,
and fork-reconcile focused baselines all passed. Defaults retains root setup
without an independent sudo probe, the app-restart opt-out, tolerated missing
`mds`, and both Spotlight enable/reindex calls using substituted external tools.
Secrets retains disabled ignore inclusion and no `op` access, enabled ignore
exclusion, literal stub output and authenticated read argv, and the host-local
config override route. These two ordinary replacements join discovery.

Karabiner, retired-package, and fork assertions have been inventoried from their
original harnesses; their migrations are still pending. The installed Goku
baseline is local evidence, not an ordinary CI requirement.

The defaults case and all three secret cases passed. Their focused targets now
select Bats, and both formerly omitted shell harnesses are retired.

### Package-gated configuration inventory

Preserve every independent managed/unmanaged/ignored path example for personal,
CI, work, and homelab, the empty-group ignored set, and unknown-type rejection.
Move these existing literal expectations into a local Python fixture table;
they are not derived from the desired config or used as a runner registry.
Preserve Tuna's named combo groups, misc children, F18 hotkey and decoded queue
action, its executable/symlink/Claude chord/command linkage, and mcporter's
Granola OAuth endpoint and mise ownership declaration. Native parsing replaces
temporary copies and shell here-doc plumbing without dropping assertion groups.

The original focused gate and all five native methods passed. The fixture table
retains all 138 literal path assertions, including the sixteen empty-group
examples. The focused target uses native discovery and the old harness and
legacy aggregate entry are removed.

### Local checkpoint after package-gate migration

The complete `make test-ci` lane exited zero: 135 ordinary Bats cases and 162
native Python methods (134 consolidated, 12 shared plist, 16 source-owned iOS),
plus the remaining legacy suites and three chezmoi dry-runs. The local log is
`/var/folders/_s/mww6d0_x19598mmpsv3z3xp00000gn/T/dotfiles-local-ci-9bfhbeda.log`.
All Bats files and shared Bash support passed shellcheck; literal child-shell
arguments and Bats-owned fixture variables have scoped explanatory directives.
The small poll-writer and wiki fixture cleanup also passed focused reruns.

Current runbooks, references, active plans, and machine guidance now route
retired test paths to their replacement commands; closed historical docs retain
their records. Docs lifecycle passed for all 75 docs against `origin/master`,
and diff whitespace validation passed. Comment review retained only directives
and the explanations needed for fixture/process boundaries.

This remains an intermediate checkpoint. Fork reconciliation, the drift banner,
agent-package tooling, and the skill console still use the transitional
aggregate. Retired-package and Karabiner/native producer lanes, final old-CI
omission accounting, remote CI, and plan closure remain outstanding. No external
Claude producer certification or VM installation is implied by this local run.

### Fork and retired-package migration detail

Both original focused baselines passed. Preserve fork adoption's explicit tap
URL, uninstall-before-install ordering, cask quarantine environment, steady
state, report-only freshness hints, managed-fork retirement, and protection of
unmanaged `-fork` packages. Execute rendered hooks against fake Homebrew to
verify their input handoff and machine gating. The retired hook's cask-only
administrator phase is observed through the real sudo helper's root check;
formula-only and disabled/empty hooks must not enter that phase. Preserve the
retired-name Brewfile conflict and active-fork subtraction while retaining an
unrelated package. No assertion group is omitted; execution replaces generated
shell-source pattern checks.

All nine fork and retirement Bats cases passed, as did shellcheck for their
shared external Homebrew fixture. Their focused targets now use Bats, the old
harnesses are removed, and retirement joins ordinary discovery. The transitional
aggregate now contains only the drift banner, agent-package tooling, and the
skill console.

### Installed producer lane inventory

The original native Claude marketplace validation and Codex `plugin/read`
round-trip passed locally. Keep both installed producers as separate host-tagged
cases with isolated homes and an explicit missing-tool reason. Preserve the
initialize/plugin-read exchange and nonempty skills response; bound the owned
server process and reap it on success or failure.

The original Goku compile passed. Preserve every named mouse overlay, device
scope, ungated base layer, overlay ordering, toggle value/notification, Apple
keyboard, and real-Shift/F18 assertion. Omit only the arbitrary total of 33
manipulators; the named behavior and ordering checks protect the contract.
Compile into a temporary Default-profile fixture using the installed Goku CLI
and require its documented result, valid JSON, and an unchanged input file. Its help confirms
that HOME/XDG select the temporary Karabiner path. This remains an explicit host
lane and does not require a user's live Default profile.

The first isolated producer runs caught fixture assumptions. Codex requires the
renderer's `.agents/plugins` layout for relative plugin sources; the corrected
layout passes. Goku's v0.8.0 release intentionally prints dry-run JSON and exits
1 ([producer source](https://github.com/yqrashawn/GokuRakuJoudo/blob/v0.8.0/src/karabiner_configurator/core.clj#L118-L122)).
The native assertion now requires that exact status and validates JSON and all
named behaviors, replacing the legacy unconditional `|| true`. The Homebrew
receipt and formula identify v0.8.0; that release's `--version` string remains
0.5.7 in its source, so it cannot identify the installed release accurately.

The installed Claude, Codex, and Goku cases passed. Their old harnesses are
retired and focused Make targets select host-tagged Bats cases. The native
console's separate exact-Claude-build gate is still unverified; marketplace
validation does not replace that producer-constant requirement.

### Drift banner migration inventory

The original drift-banner baseline passed. Preserve rendered target paths and
modes, all interactive/terminal/SSH gates, plain and colored cached output,
signature throttling and corrupt timestamp recovery, data-only local and cache
configuration, preview overrides, status scope and umask, configuration
normalization, renderer and TTL invalidation, partial/future cache recovery,
background startup, incomplete/stale/future/reused-PID locks, concurrent refresh
exclusion, clean-state throttle reset, stderr isolation, failed refresh cache
preservation, changed-scope error state, and startup error cooldown. The seams
remain the materialized refresh/preview commands and loader in real zsh/PTYs.
Replace quiet-time probing and racing sleeps with observable completion and
external-status handshakes; retain the 700 ms cached-startup bound. No assertion
group is omitted.

All 20 drift Bats cases passed. The focused target now uses Bats, the old
695-line harness is removed, and ordinary discovery owns the lane. The terminal
checks use shared PTY support with an explicit completion prompt; background
status has a bounded release handshake and cleanup waits for the refresh lock
to disappear. Agent-package tooling and the skill console remain transitional.

### Agent package migration inventory

The original package baseline passed, including its known APM manifest-audit
false-positive warning. Preserve source layout/provenance, JSON inventory and
typed loading policy, package rejection diagnostics, supported/unsupported APM
payloads, curated IDs and multi-skill provenance, stale vendor removal, hooks
ownership and conflict refusal before replacement, other audit failure refusal,
empty dependency cleanup, both marketplace path formats, executable payloads
and mode-only drift, native hooks discovery contracts, runtime skill stub
preservation, hand-authored Claude root protection, context audit, command
preview, install/enable/disable/removal ordering, other-marketplace preservation,
Codex cache refresh, dry-run nonmutation, failure diagnostics, and loading-policy
propagation to Claude/Codex/pi templates. Test the real command-line programs
with temporary package roots and external APM/agent substitutes. Use native
Python for structured fixtures and JSON/TOML assertions; no legacy wrapper or
producer-private helper tests are needed. No assertion group is omitted.

All 18 native package tests passed. The first isolated run caught two fixture
dependencies: curated provenance needs its original Notes field to test note
preservation, and an unrelated dependency-bearing package needs a lockfile when
the final validator checks the whole root. Both fixtures now provide their own
valid inputs. The focused Make target uses discovery and the 872-line shell
harness is removed. Only the skill console remains in the transitional lane.

### Skill console migration inventory

The original console baseline passed with the known unrecognized-Claude-build
warning. Preserve every worked admission table (fit/priority boundary, separators,
greedy misses, stable ties, protected/forced rows, empty/duplicate listings,
UTF-16 caps, model normalization, environment numbers, rank, context rounding,
width/estimator differences, and the prediction witness); frontmatter folding,
all Unicode/grapheme and safe-write examples, real-source byte round-trips,
surgical edits, and scalar refusal/escaping; loader order, derived descriptions,
settings relocation and built-in flags; every capability and V1-V19 rejection;
browser admission and BMP safe-write parity; CLI output/exit/discovery behavior;
and all plan/stage/commit tests, including dirty/hash/symlink guards, template
injection refusal, dependency deletion, partial removal recovery, and concurrent
reference/ownership changes. Keep the unknown-binary CLI refusal ordinary and
the exact installed-build certification separate. Native Python tests exercise
the public console modules and CLI, with Node executing the shipped browser
functions. Replace shell dispatch and optional module guards with native
discovery. A missing required module or Node executable is a failure.

Omit only the duplicate `find`/`rglob` inventory count and browser source-text
word/function counts: nonempty real-source round-trips and browser behavior
against integer cost inputs protect their useful guarantees without requiring a
particular implementation spelling.

All 52 native console tests passed across focused runs: 32 budget/frontmatter/
inventory cases, two validation cases, nine guarded-write cases, two browser
cases, and seven CLI cases. The repository-copy fixture now includes cached
assertion libraries because staged Pi validation runs Bats, and disables Git
automatic maintenance so cleanup cannot race a background repack. The 2003-line
legacy harness and transitional Make aggregate are removed.

The source-owned Raycast Node baseline passed all six cases. Its focused Make
target now selects Node 24.12.0 through mise and joins `test-node`/`test-ci`.
A selection regression exposed Node's automatic passing file-level test for an
empty file. The native TAP reporter now requires a passing registered test from
the per-file summary; it preserves native discovery and reporting and refuses
empty or entirely skipped input. The Bats selection cases retain ordinary
success, missing-file, and assertion-failure witnesses as well.

### Final selection accounting

Every pre-migration focused Make target remains callable. The old workflow's
behavior targets are covered by discovery and the shared static/chezmoi lanes.
The targets absent from that workflow have these dispositions:

| Previously omitted targets | Current execution path or exclusion reason |
| --- | --- |
| `test-ghc`, `test-cursor-cli-alias`, `test-brew-inventory`, `test-repo-index` | Ordinary Bats command/audit discovery. |
| `test-mise-install-script`, `test-raycast-extensions-script`, `test-retired-packages` | Ordinary Bats package/hook discovery with external command substitutes. |
| `test-macos-defaults-script`, `test-secret-backed-files`, `test-sudo-keepalive` | Ordinary Bats discovery with temporary preferences, fake secrets, and controlled privilege commands. |
| `test-chezmoi-local-ignores`, `test-nvalt-colors`, `test-pi-statusline` | Native Python configuration/agent discovery. |
| `test-cmux-plist`, `test-moom-plist`, `test-nvalt-plist`, `test-orbstack-plist`, `test-selected-app-plists`, `test-thaw-plist`, `test-tuna-plist`, `test-voiceink-plist` | The existing shared plist runner discovers their independent app cases. |
| `test-raycast-orca-worktree` | Source-owned Node discovery through `test-node`; no npm package installation is needed. |
| `test-chezmoi-apply` | Three machine-type dry-runs composed by `test-ci`. |
| `test-agent-skill-packages-native`, `test-kanata-config`, `test-karabiner-goku` | Explicit host-tagged Bats lanes requiring installed native producers. |
| `test-zsh-fresh-shells` | Explicit authoritative native zsh validator selftest; host correctness and benchmark commands remain separate. |
| `test-crit-evals` | Explicit paid/network agent evaluations. |
| `test-install-tart-dry-run`, `test-install-tart-smoke`, `test-install-tart-full` | Explicit VM/install operator lanes with image/resource prerequisites. |
| `test-install-tart-warm`, `test-install-tart-warm-bootstrap`, `test-install-tart-warm-refresh`, `test-install-tart-warm-destroy` | Explicit persistent-VM lifecycle operations. |

Additional explicit host cases cover wiki/Agentsview source parity, Dash statusline
compatibility, and the exact Claude console build. Their prerequisites are in
the tests index. No top-level legacy shell harness remains. The final docs pass
caught the archived drift plan's stale `related` link; only that routing metadata
was updated, preserving its historical body as required by document lifecycle.

### Final local integration receipt

On 2026-09-06, `DOCS_LIFECYCLE_BASE=origin/master make test-ci` passed with 167
Bats cases, 232 native Python tests (204 consolidated, 12 shared plist, 16
source-owned iOS), six source-owned Node tests, three chezmoi dry-runs, and
validation of 75 docs. Local output is retained outside the repository at
`/var/folders/_s/mww6d0_x19598mmpsv3z3xp00000gn/T/dotfiles-final-local-ci-c54m9q9e.log`.
Shellcheck passed across 76 scripts/Bats/support files. The chezmoi skill's
bundled validator and every changed skill's frontmatter parser passed. The
changed-area routes for app configuration, zsh, and agent packages reach their
implemented tests and preserve the distinct host/VM obligations.

A final drift-fixture review tightened cleanup for an assertion failure before
the background status command starts. Expected background work now has an
explicit fixture marker; cleanup waits for its start, completion, and lock
removal. All 20 focused drift cases passed again. A disposable deliberate
assertion failure also returned nonzero and showed status completion and lock
removal before outer cleanup. Its files were removed. The earlier fixture left
by Git's automatic-maintenance race was checked for open handles and removed.
Node's todo-only selection was separately observed to fail as intended.

The branch was confirmed to contain fetched `origin/master` at `5f99c0c`.
The owner requested local landing and apply on 2026-09-06 using `land-changes`:
local checks precede a single implementation commit, fast-forward merge, and
master push. Remote workflow evidence follows that push; no PR is required.
The workflow runs on pull requests or master pushes, so remote macOS CI and
Linux/installation job receipts remain unexecuted. The exact native Claude
console build remains uncertified; optional host and VM lanes are distinct from
the local receipt above. Steps 1, 2, 4 and local migration/selection are complete.
Steps 3, 5 and 6 retain their required remote-CI gate. After that passes, close
this plan in a metadata-only change with `current_guidance: ../../tests/README.md`
and move its index entry to history. Do not archive it before that evidence.

### Adversarial review corrections

Two reviewers with no inherited conversation context found three defects. Console
fixture setup now replaces the process environment with its sanitized environment;
an independent two-repository regression first demonstrated a write escaping into
the caller-routed index, then passed with the fix. Existing console write behavior
also passed.

The stream growth fixture no longer uses blocking FIFOs. It preserves actual wait
durations and the original under-three-second growth guarantee. All ten focused
cases passed. In disposable copies, sleeping for the full timeout failed the
timing assertion, and failing to refresh the log size returned a bounded failure
instead of hanging. The mutation fixtures were removed after verification.

Before landing, the latest master workflow exposed two existing CI provisioning
failures: macOS lacked ripgrep, and Ubuntu selected Shellcheck 0.9.0 while local
validation used 0.11.0. The workflow now installs ripgrep/jq explicitly and uses
the repository's mise-pinned Shellcheck 0.11.0 in the Linux job. No lint checks
were disabled and the Linux script discovery remains intact.

The post-review local lane passed 167 Bats cases, 233 Python tests (205
consolidated, 12 shared plist, 16 iOS), six Node tests, and all three chezmoi
dry-runs. Commit-hook validation also exposed a standalone dry-run target using
caller runtime shims after home isolation. That focused target now selects the
same pinned environment as the aggregate before creating temporary homes.

The first post-landing remote run passed Linux Shellcheck and reached all 167
Bats cases. Its sole failure exposed a host-dependent Goku diagnostic in the
CI apply fixture: a local Goku install produced the expected missing-input
warning, while the hosted runner reported the missing executable first. The
fixture now supplies Goku explicitly and rejects any invocation, preserving
the missing-configuration skip assertion without depending on host tools.

The next remote run passed all Bats, Python, and Node cases, then its final
dry-run exposed an optional `wiki_host_alias` lookup in the session-archive
config. The remaining config and sparse-script lookups now use an empty default
when the host is unregistered; the sync producer still refuses an empty alias.
The config regression was observed failing before the fix. Shared dry-runs now
override the hostname to a neutral fixture value, preventing the developer's
registered host layer from masking missing optional data.
