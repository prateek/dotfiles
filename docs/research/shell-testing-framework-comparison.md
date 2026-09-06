---
status: current
doc_type: research
created: 2026-09-05
updated: 2026-09-05
owner: Prateek
related:
  - ../plans/test-suite-rebuild-plan.md
  - ../adr/0022-bats-and-zsh-test-support.md
  - ../adr/0002-zsh-fresh-shell-validator.md
  - ../adr/0005-mise-tool-management.md
status_detail: "Summarized experiment findings and upstream sources for ADR 0022. Disposable comparison code and raw evidence were removed after the decision; production migration is pending."
---

# Shell testing framework comparison

Use this report when revisiting the framework or zsh-support decision. It holds
the decision trail, alternatives, findings, and limitations behind
[ADR 0022](../adr/0022-bats-and-zsh-test-support.md). The
[test refactoring plan](../plans/test-suite-rebuild-plan.md) owns the path forward;
the [tests index](../../tests/README.md) describes the currently runnable suite.

## Decision trail

The earlier plan at `test-suite-rebuild-plan.md` proposed a custom universal
runner and per-test manifests to unify selection. The chosen design gives
discovery and reporting to existing frameworks, with Make composing their suite
commands. This addresses duplicated local/CI selection without making the repo
maintain another execution engine. The Python comparison driver was disposable
experiment tooling and was removed after its findings were recorded here.

The useful-test discussion established the root `AGENTS.md` criteria before
framework selection. The initial spike then exercised ten equivalent cases in
Bats, ShellSpec, and ZUnit across command errors, zsh state, plist merging, and
Git-backed validation. All caught six injected defects and tolerated a private
helper rename. Bats cleaned up the tested setup failure; none rejected a
self-comparison assertion. These observations separated framework ergonomics
from the quality of the behavior being asserted.

The initial recommendation favored ShellSpec's diagnostics and parameter tables.
The broader review added the owner's preference for Bats syntax, maintenance
history, and concrete downstream use. Those factors favored Bats over
ShellSpec's DSL and ZUnit's native zsh convenience. The small timing differences
in this spike did not decide the choice.

The subsequent `testing-in-bash` review expanded the alternatives to TypedDevs
bashunit, bash-unit/bash_unit, shUnit2, and shpec. Their documentation and project
history were assessed; they were not run through the spike. Bashunit remained
the strongest additional candidate, but no tested advantage justified changing
direction. Inspection of `bats-zsh` then showed that its process and output
capture model did not meet the required state, exact-byte, and PTY boundaries.

ADR 0022 therefore selects Bats with small repo-owned zsh scenario support,
native structured-data tests, and thin Make composition. The independent
config-merge work has since landed on `master` as shared plist verification
under [ADR 0021](../adr/0021-shared-plist-verification.md). Production migration and the
real PTY/parent-exit compatibility gate remain pending. The sections below
preserve the observations and limitations used to reach that decision.

## Method and scope

The completed experiment exercised ten equivalent cases in each framework across
four existing public seams:

| Type | What the cases establish |
| --- | --- |
| Command errors | `ohc` explains missing/invalid arguments, exits 2, writes errors to stderr, and starts no Git/Orca work. |
| Native shell state | `ghc` accepts three repository argument forms and changes the caller's directory; invalid input preserves it. |
| Structured/binary output | Plist merging replaces a managed dictionary wholesale, preserves an independent local key, and retains unchanged input bytes. |
| Real Git fixtures | The docs validator accepts valid lifecycle metadata against a Git base and rejects an invalid status with a named diagnostic. |

Each case exercised real repository code in a scratch copy. Checkout tests
substituted external Git/Orca commands; docs fixtures used real Git. Plist fixtures
used standard-library serialization and a literal expected result. Repo-owned
merge, parsing, and validation logic ran unchanged except in deliberate defect runs.

Three serial warm baseline runs were followed by deliberate defects, an internal
rename, hostile Git configuration, and two deliberately weak test controls.
Tool installation is outside the timings; mise selection and fixture setup are
inside. These measurements describe this small local workload, not whole-suite
performance or a statistically significant speed ranking.

## Findings

| Observation | Bats 1.14.0 | ShellSpec 0.28.1 | ZUnit 0.8.2 |
| --- | --- | --- | --- |
| Ten behavior cases | Pass | Pass | Pass |
| Six deliberate defects | All caught | All caught | All caught |
| Harmless private-helper rename | All pass | All pass | All pass |
| Hostile Git hook with shared isolation | All pass | All pass | All pass |
| Hostile Git hook without shared isolation | Setup fails | Setup fails | Setup fails |
| Fixture cleanup after that setup failure | No leftovers | Two leftovers | Two leftovers |
| Captured failed command with no assertion | Passes silently | Nonzero exit with warning | Nonzero exit with warning |
| Self-comparison assertion | Passes | Passes | Passes |

All assertion failures in the six mutation runs cleaned up their fixture roots.
The two-leftover observations concern failure during setup. The experiment driver
recorded those directories and removed them afterward; the framework hooks alone
did not clean them up. A shared fixture lifetime must account for partial setup
if adopting ShellSpec or ZUnit.

The identity-only merge mutation illustrates why idempotence is insufficient:
the unchanged-byte case still passes, while the independently specified
transformation fails in all three frameworks.

## Authoring and diagnostics

**Bats** uses familiar shell assertions with optional assertion libraries. The
spike used pinned bats-support and bats-assert. Its parameterized checkout cases
used `bats_test_function`; the actual zsh directory change required a subprocess
probe. `run --separate-stderr` makes channel assertions possible, but the tested
`assert_success` output does not automatically include captured stderr. A shared
failure hook would improve that diagnostic. See the
[Bats execution and hook documentation](https://bats-core.readthedocs.io/en/stable/writing-tests.html).

**ShellSpec** made the three repository arguments a small `Parameters` table.
The spec runs under the same zsh executable as the other lanes; `When call` can invoke the public autoloaded
command in that shell. The reports include expected/actual values and source
lines, and they show multiple failed expectations. Its execution modes need
care: `run command` respects a program's shebang, whereas `run script` chooses
the spec's shell. Use command execution when the executable's launch behavior is
the seam. These modes and parameter syntax are documented in the
[ShellSpec reference](https://github.com/shellspec/shellspec/tree/0.28.1).

**ZUnit** permits direct zsh assertions about the caller's directory. Its
released `run` helper combines stdout and stderr, so equivalent error-channel
checks need explicit redirection and file reads. The spike repeated the three
argument cases to retain a separately reported result for each. Its TAP failures
give an assertion message but less command/source context than the other two.
For example, the byte-change failure reports a numeric exit mismatch rather than
the `cmp` output. The evaluated release is
[v0.8.2](https://github.com/zunit-zsh/zunit/releases/tag/v0.8.2), with Revolver
v0.2.3; this comparison does not evaluate unreleased ZUnit changes.

The assertionless control exposes a reporting subtlety: released ZUnit prints a
TAP `ok` entry with a warning but exits nonzero. Consumers must honor the process
exit status. All three accept a tautological self-comparison; none can enforce
the root `AGENTS.md` useful-test criteria by syntax alone.

## Community and maintenance

Checked through the GitHub API on 2026-09-05. Contributor counts are cumulative
accounts returned by the contributors endpoint, including bots, not a count of
active maintainers. Stars indicate interest, not installed usage or quality.

| Project | Stars / contributors | Latest published release | Latest default-branch commit |
| --- | --- | --- | --- |
| [Bats](https://github.com/bats-core/bats-core) | 6,248 / 135 | [1.14.0, 2026-07-21](https://github.com/bats-core/bats-core/releases/tag/v1.14.0) | [2026-09-05](https://github.com/bats-core/bats-core/commit/ddfefa0f62be), merged empty-suite behavior improvement |
| [ShellSpec](https://github.com/shellspec/shellspec) | 1,396 / 17 | [0.28.1, 2021-01-11](https://github.com/shellspec/shellspec/releases/tag/0.28.1) | [2024-09-12](https://github.com/shellspec/shellspec/commit/f2d13f991885), initialization fix |
| [ZUnit](https://github.com/zunit-zsh/zunit) | 226 / 4 | [0.8.2, 2018-01-04](https://github.com/zunit-zsh/zunit/releases/tag/v0.8.2) | [2020-06-25](https://github.com/zunit-zsh/zunit/commit/b86c006f62db), installation documentation |

The queried endpoints were `/repos/<owner>/<repo>`, `releases/latest`,
`commits?per_page=4`, and paginated `contributors?per_page=100`. ZUnit is not
archived and its repository `pushed_at` is recent, but that timestamp does not
establish recent work on its default branch. Old releases alone do not establish
abandonment; the combination of release history, default-branch activity, and
community size raises the maintenance risk for a new adoption here.

Bats also has concrete downstream use: [rbenv's test entrypoint](https://github.com/rbenv/rbenv/blob/master/test/run)
executes Bats, and [Podman's system-test guide](https://github.com/podman-container-tools/podman/blob/main/test/system/README.md)
documents its Bats suite. Podman's [process helper](https://github.com/podman-container-tools/podman/blob/main/test/system/helpers.bash)
handles timeouts, cleanup, and Bats file descriptors, providing a relevant example
for this repo's process-heavy cases. This is evidence of practical adoption, not
a comprehensive census. The [bats-core organization](https://github.com/bats-core)
also maintains supporting assertion and file libraries. Taken together, these
signals favor Bats for long-term maintenance.

## Additional comparison: testing-in-bash

The owner also requested consideration of
[dodie/testing-in-bash](https://github.com/dodie/testing-in-bash), inspected at
commit `51c2475a1d06` on 2026-09-05. Its examples and evaluation categories are
useful, but individual framework ratings need version checks. The repository's
latest change is from August 2025 while its
[Bats installer](https://github.com/dodie/testing-in-bash/blob/51c2475a1d06/example-bats/install.sh)
still selects Bats 1.1.0.

Three current Bats facts change the interpretation of its feature matrix:

- File and suite lifecycle hooks are supported: `setup_file`, `teardown_file`,
  `setup_suite`, and `teardown_suite`.
- `bats_test_function` registers separately reported cases from data, as exercised
  in this repo's spike. It is more manual than a dedicated data-provider API.
- The historical complaint that `run` suppresses a function's `set -e` is addressed
  by the tested 1.14.0 release. That release explicitly calls out the behavioral
  change; upgrades still require checking the production command's option context.

Sources: [current hooks and test registration](https://bats-core.readthedocs.io/en/stable/writing-tests.html)
and [Bats 1.14.0 release notes](https://github.com/bats-core/bats-core/releases/tag/v1.14.0).
The older maintenance warning also needs to be read alongside the current release
and contribution evidence above.

The comparison's isolation rating concerns shell variables, functions, aliases,
and options between tests. It does not establish isolation of files, inherited
Git configuration, processes, or PTYs. Keep our explicit fixture boundaries.
Its assertion/reporting concerns reinforce using bats-assert where useful and
checking actual failure messages. A framework's support for mocks does not
justify replacing repo-owned behavior with mocks.

The additional candidates were reviewed through upstream documentation and
GitHub metadata, not executed against the repo's spike. Counts below use the
same cumulative-contributor definition as the main table.

| Additional candidate | Stars / contributors | Release and maintenance evidence | Fit for this repo |
| --- | --- | --- | --- |
| [TypedDevs/bashunit](https://github.com/TypedDevs/bashunit) | 424 / 47 | [0.50.1, 2026-08-22](https://github.com/TypedDevs/bashunit/releases/tag/0.50.1); default branch updated the same day | Strongest additional candidate for an authoring comparison: ordinary Bash test functions, built-in assertions, and data providers. Still a Bash framework, so zsh state needs a separate scenario. |
| [bash-unit/bash_unit](https://github.com/bash-unit/bash_unit) | 635 / 26 | [2.3.3, 2025-08-28](https://github.com/bash-unit/bash_unit/releases/tag/v2.3.3); default branch updated 2026-02-11 | A distinct project with ordinary Bash tests, assertion helpers, TAP, and randomized case order. Reasonable alternative, but no demonstrated advantage over Bats for our zsh/process cases. |
| [shUnit2](https://github.com/kward/shunit2) | 1,737 / 21 | [2.1.8, 2020-03-29](https://github.com/kward/shunit2/releases/tag/v2.1.8); default branch updated 2026-03-15 | Mature cross-shell option, but its documented zsh mode requires `shwordsplit`, which changes normal zsh expansion behavior. That is a poor default for tests of our native shell behavior. |
| [shpec](https://github.com/rylnd/shpec) | 386 / 11 | No GitHub latest-release record; default branch last changed 2019-02-19 | Its BDD-style syntax and maintenance history provide little reason to expand this repo's shortlist. Absence of a GitHub release record is not proof that no tags exist. |

The [shUnit2 zsh requirements](https://github.com/kward/shunit2#zsh) are a concrete
example of why advertised shell support alone is insufficient: the test runner
must preserve the shell semantics relevant to the behavior being tested.

TypedDevs bashunit deserves particular attention if built-in assertions and
reporting would materially reduce test code. Its
[agent guidance](https://bashunit.com/ai-agents) documents an option to fail tests
with no recognized assertions, but also several ways tests can pass for the wrong
reason: `assert_equals` normalizes tabs/newlines, and missing snapshots can be
recorded without failing. Exact contracts need exact assertions and intentional
snapshot policy. Assertion counts alone cannot establish useful coverage.

Bats remains the recommendation because it has passed our local behavioral
comparison and has stronger downstream adoption evidence. This source expands
the credible alternatives, particularly bashunit, without resolving the remaining
PTY and parent-exit questions. A further framework comparison should reuse those
same useful cases and deliberate defects instead of scoring feature counts.

## Python's role

The disposable Python driver prepared pinned tools and scratch copies, injected
defects, ran the comparison matrix, and recorded timings and fixture leftovers.
It was removed with the completed experiment. Bats can discover and run shell
tests directly; the planned suite uses a small Make target and mise.

Python also serialized and decoded the plist fixtures. Its plist/JSON support
remains useful for structured assertions in focused tests. That use does not
require a shared Python runner for the shell suite.

## Fit for existing zsh and other edge cases

The first two rows below are supported by the executed spike. The remaining
rows combine inspection of existing repo tests with framework documentation;
they have not been migrated or validated under Bats in this experiment.

| Existing behavior | Fit and boundary |
| --- | --- |
| CLI errors and filesystem effects | Good fit. Invoke the real command, check status and output channels, and inspect independent filesystem effects. |
| Autoloaded zsh commands changing caller state | Good fit with a zsh scenario. Invoke the public command and observe `PWD`, variables, arrays, or options inside the same zsh process. Bats itself executes Bash. The experiment's zsh probe preserved the command's status and reported its resulting directory. |
| Interactive startup, ZLE, widgets and keymaps | Keep the real `zsh/zpty` seam in [zsh-fresh-shells.zsh](../../scripts/audit/zsh-fresh-shells.zsh). Bats may dispatch a scenario and report its result. A noninteractive `zsh -f` probe cannot establish these behaviors. |
| PTY prompts in [plist-hooks.bats](../../tests/bats/hooks/plist-hooks.bats) | Keep PTY creation, reads, writes, and destruction in one owning zsh process. The existing harness documents a command-substitution bookkeeping problem. Native zsh test syntax alone does not solve PTY ownership. |
| Streaming bytes in [poll-stream.bats](../../tests/bats/programs/poll-stream.bats) | Capture output in files and compare exact bytes or decode explicitly. Shell output variables are unsuitable for binary data and exact trailing-newline contracts. Keep the real append/offset/timeout behavior. |
| Parent death and background cleanup in [sudo-keepalive.bats](../../tests/bats/hooks/sudo-keepalive.bats) | Preserve the intended process ancestry. Own readiness, bounded waits, and kill/wait cleanup in the scenario. A wrapper that changes the tested parent relationship can change the behavior under test. |
| Parallel tests and host state | Isolate Git configuration, home/config roots, ports, and process state first. Cases using live apps, launchctl, or a VM need a deliberate separate lane or serialization. Framework parallelism does not provide those boundaries. |
| macOS system Bash versus the tested Bash | Select the test interpreter explicitly. The spike used Bash 5.3.15; Bats documents different failure handling for `[[ ]]` and `(( ))` on Bash 3.2. Pinning Bats alone does not pin Bash. |

Bats documents that [`run` executes in a subshell](https://bats-core.readthedocs.io/en/stable/writing-tests.html#run-test-other-commands),
so caller-state observations must happen inside the invoked scenario. Its
[background-process guidance](https://bats-core.readthedocs.io/en/stable/writing-tests.html#file-descriptor-3-read-this-if-bats-hangs)
also requires closing inherited FD 3 for long-lived children to avoid hangs.
Use the documented `bats_pipe` behavior when capturing pipelines, or keep the
pipeline inside the scenario with intentional status handling.
The [Bats gotchas](https://bats-core.readthedocs.io/en/stable/gotchas.html)
cover the Bash-version behavior and additional inherited-descriptor cases.

Prefer a short, readable `.zsh` scenario when state observation needs several
steps. Large nested `zsh -c` strings and generic shell adapters would erase the
authoring benefit. Native zsh assertions remain more convenient for dense tests
of shell state, but the command, file, and process boundaries inspected here do
not justify adopting ZUnit alongside Bats.

The [plan's compatibility gate](../plans/test-suite-rebuild-plan.md#2-prove-the-zsh-and-process-boundary)
covers the remaining PTY and parent-exit experiments and their cleanup.

## Existing zsh adapters and a possible local helper

[targendaz2/bats-zsh](https://github.com/targendaz2/bats-zsh) is an existing Bats
extension. It supplies `zsource`, `zrun`, and `zset`. Checked on 2026-09-05, its
latest published release is [1.2.1 from 2023-05-28](https://github.com/targendaz2/bats-zsh/releases/tag/v1.2.1),
with four stars and two historical contributor accounts. The latest default-branch
commits are February 2026 CI dependency updates. Its maintenance/adoption evidence
is much narrower than Bats core's.

Inspection of the released
[wrapper](https://github.com/targendaz2/bats-zsh/blob/v1.2.1/src/zsh_wrapper.sh)
and [zrun helper](https://github.com/targendaz2/bats-zsh/blob/v1.2.1/src/zrun.bash)
shows the following limits:

- Each invocation starts another zsh and sources the registered files. Mutations
  from one invocation do not carry into the next; a multi-step state scenario
  must still execute within one call.
- The wrapper captures output with command substitution and emits it with
  `echo`. That changes trailing-newline behavior and adds an extra subshell,
  making it unsuitable as the capture layer for our exact-byte and PTY cases.
- There is no PTY lifecycle in this wrapper. It does not provide interactive
  ZLE testing, bounded prompt waits, or parent-exit process cleanup.
- Released `zsource` also requires sourced files to be executable. Our autoload
  scenarios should follow the actual `fpath`/autoload behavior instead.

These are source-inspection findings, not results from running the plugin here.
Unreleased `main` also loads overrides of Bats `run` and Bash `source`; the
[run override](https://github.com/targendaz2/bats-zsh/blob/10170ae2c99d/src/overrides/run.bash)
forwards only its first argument. Do not treat unreleased behavior as part of
1.2.1, or assume such overrides preserve the current Bats API.

No comparable zsh testing adapter was found for TypedDevs bashunit or
bash-unit/bash_unit in the upstream docs, upstream issue/PR searches, and GitHub
repository name/description searches. This is a bounded search, not proof that
none exists. TypedDevs' documented
[zsh integration](https://bashunit.com/installation#shell-completion) is command
completion; the test runner still requires Bash.

A local helper is feasible without modifying any framework. The experiment used
a seven-line zsh scenario to autoload the real command, invoke it, report `PWD`,
and propagate its status. Extract shared mechanics only as the next PTY/process
cases demonstrate duplication:

| Responsibility | Proposed owner |
| --- | --- |
| Test discovery, filtering, assertions, reporting | Bats and its existing assertion libraries |
| Selected zsh binary, fixture paths, home/ZDOTDIR isolation, argument forwarding | A small Bash helper loaded by Bats, if the common setup warrants one |
| Public autoload calls and observations of `PWD`, arrays, options or hooks | A zsh scenario; perform all dependent steps in one process |
| Login startup and ZLE interaction | Preserve the existing ADR 0002 validator. Adapt its PTY mechanisms for other test scenarios only where needed; run rendered startup fixtures |
| Raw stdout/stderr, transcripts, and process completion evidence | Files owned by the test fixture; preserve bytes until an assertion intentionally decodes them |

Zsh's built-in [zsh/zpty module](https://zsh.sourceforge.io/Doc/Release/Zsh-Modules.html#The-zsh_002fzpty-Module)
already provides terminal creation and read/write primitives. The local work is
to give those operations clear ownership, bounded waits, useful failure
transcripts, and cleanup, while preserving the shell modes and process ancestry
being tested. Clean noninteractive probes and interactive startup scenarios need
explicitly different launch behavior.

The scenario files can be invoked by either bashunit project as well. Only the
small framework-facing assertion/capture call would change. No Python runner,
state-serialization protocol, persistent cross-test zsh server, or framework fork
is needed for the proposed design. Avoid overriding framework `run`/`source` and
avoid translating Bash assertions into zsh source strings.

Before promoting shared helpers, prove that they preserve arguments with spaces
and metacharacters, command failure status, and output channels. Exercise the
real PTY and parent-exit scenarios with deliberate defects and verify their
resources are cleaned up on failure. Those checks protect the adapter's useful
contracts; tests that merely assert which helper calls which would add little.
The plan chooses this approach. The helper interface remains a proposal, and no
shared adapter has been implemented.

## Keeping tests useful

The framework choice does not replace the root `AGENTS.md` criteria. The spike
showed that every framework accepts self-comparison assertions. Bats also accepts
an unchecked `run false`, so tests that capture output should explicitly assert
the expected status, either with `run -0` / `run -2` or an immediate status
assertion. Then assert the caller-visible behavior with independently specified
expectations. If success is the whole contract, a direct command can suffice.

Prefer the transformation-plus-preservation case that rejects a no-op merge,
the invalid-argument case that prevents external work, and the parent-exit case
that detects a leaked helper. Skip internal function rosters, source-text checks,
and mirrored desired configuration that protect no distinct behavior. Keep
mutation checks as evidence that valuable tests detect plausible defects, not as
an invitation to grow a permanent custom mutation framework for this repo.

## Evidence and limits

The completed run on 2026-09-05 covered 42 framework executions and 204 case
executions against source commit `dd8b29f3831aedb25bd6d836d1ed3639e9e32256`.
Before cleanup, the recorded hashes of all four production entrypoints matched
that checkout, and recorded statuses, case counts, and fixture leftovers matched
the experiment's expectations. The environment was macOS 26.4.1 on arm64, Python
3.14.6, Bash 5.3.15, and zsh 5.9.1. Framework versions appear in the findings
table; support libraries were bats-support 0.3.0, bats-assert 2.1.0, and Revolver
0.2.3.

This report retains the summarized observations and upstream sources. The
comparison code, lockfile, fixtures, negative controls, and raw evidence were
discarded after the decision. The repository no longer includes a runnable
reproduction of that experiment; new compatibility work follows the plan.

Validation is local macOS only. The spike does not establish Linux/remote-CI
compatibility, full-suite performance, installed-app correctness, template-render
coverage, real network cloning, or PTY startup behavior. The Python entrypoints
were invoked with the selected interpreter, so their `uv` launchers were outside
the tested seam. No production implementation or existing test suite was changed.
