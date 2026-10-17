---
status: active
doc_type: plan
summary: "Generalizes the chezmoi drift banner into one fastfetch-rendered shell banner with cached status rows for chezmoi, brew, mise, and apm"
owner: Prateek
created: 2026-05-13
updated: 2026-08-31
related:
  - chezmoi-drift-banner-plan.md
  - ../../home/dot_config/dotfiles/shell-banner/README.md
  - ../../tests/shell-banner.zsh
status_detail: "Replaces chezmoi-drift-banner-plan.md. Implementation shipped on prateek/banner-fastfetch; see Deviations section at the bottom for what changed during review, and Deferred for the apm row."
---

# Shell Banner Plan

> **Heads-up:** the body below describes the original four-source design
> (chezmoi + brew + mise + apm). **`apm` was deferred during implementation**;
> the source script and lib wiring still ship, but it is not in the
> default `DOTFILES_BANNER_SOURCES` and not in the fastfetch config.
> See the [Deferred](#deferred) section near the bottom for why and what
> needs to change to re-enable it.

## Context

The repo recently shipped `chezmoi-drift` (commit `37124de`, 2026-05-11): a cached shell banner that nags when managed dotfiles drift from chezmoi source state. The shell adapter is careful — it never blocks on `chezmoi`, just reads cache files and kicks a background refresh. It works, but two limits showed up fast:

1. **The renderer is bespoke.** ~480 lines of `lib/cache.sh` plus three ASCII art files (`compact.txt`, `box.txt`, `alert.txt`) plus image badges. Every visual tweak means hand-crafting ANSI. fastfetch already solves this category problem.
2. **Drift is only one signal.** Stale Homebrew packages, outdated mise tools, and out-of-date `apm` agent skill packages are the same class of "you should sync something" reminder, but each has its own ad hoc story (or no story). The user wants one unified banner.

The rework: keep the well-tested cache/lock/signature plumbing, generalize it from one source (`chezmoi`) to four (`chezmoi`, `brew`, `mise`, `apm`), and replace the bespoke renderer with fastfetch driven by a templated `config.jsonc`. fastfetch fires on every interactive non-SSH shell. Each source contributes one row; rows read from tiny pre-rendered cache files so fastfetch invocation stays fast.

## Goals

- One banner on every interactive non-SSH shell, rendered by fastfetch.
- Cache-driven status rows for `chezmoi`, `brew`, `mise`, `apm` — each shows "clean", "outdated N", or "stale/error" without blocking the shell.
- Per-source TTLs (drift checks more often than brew, etc.).
- Background refresh with the existing lock/signature/state-env design.
- fastfetch installed via chezmoi (`packages.toml`).
- Fresh-shell startup remains within current `zsh-fresh-shells bench` envelope.

## Non-goals

- No backwards-compat with `chezmoi-drift` env vars or state dir. The feature shipped two days ago and is single-user; clean rename instead of shims.
- No MAS / cargo / pipx coverage in this pass (gated as future sources).
- Stay silent on SSH-attached shells. Today's adapter exits early when `SSH_TTY` or `SSH_CONNECTION` is set (so the host shell doesn't dump a banner over the wire when you `ssh in`); the fastfetch adapter keeps that gate.

## Design

### Rename and layout

Rename `chezmoi-drift` → `shell-banner` since the scope is no longer drift-only.

```text
home/dot_config/dotfiles/shell-banner/
  README.md
  feature.env.tmpl                         # global + per-source defaults
  fastfetch/
    config.jsonc.tmpl                      # rendered to ~/.config/fastfetch/config.jsonc
  bin/
    executable_refresh                     # multi-source dispatcher
    executable_preview                     # runs fastfetch with our config (debug aid)
    executable_module                      # shim invoked by fastfetch command modules
    sources/
      executable_chezmoi
      executable_brew
      executable_mise
      executable_apm
  lib/
    cache.sh                               # generalized from current chezmoi-drift cache.sh
    sources.sh                             # source registry, per-source helpers
  shell/
    zsh.zsh                                # gates + invokes fastfetch + kicks background refresh

home/dot_config/zsh/extra/shell-banner.zsh # one-line loader (replaces chezmoi-drift.zsh)

home/.chezmoidata/packages.toml            # add `fastfetch` brew to core profile
home/.chezmoiignore                        # update local.env path for new dir
Makefile                                   # rename test target

docs/plans/shell-banner-plan.md            # this plan, status: active
docs/plans/chezmoi-drift-banner-plan.md    # repoint current_guidance at shell-banner
tests/shell-banner.zsh                     # generalized test (replaces chezmoi-drift-banner.zsh)
tests/README.md                            # update entry
```

### Runtime state

```text
${XDG_STATE_HOME:-~/.local/state}/dotfiles/shell-banner/
  sources/
    chezmoi/
      state.env
      module.txt           # plain row, e.g. "drift   3 files differ"
      module.ansi          # ANSI-colored row
      status.txt           # raw check output for diagnostics
      updated_at
      last_error
      refresh.lock/
    brew/{...same shape}
    mise/{...}
    apm/{...}
  refresh.lock/            # global dispatch lock (one refresh process at a time)
  last_shown               # epoch of last fastfetch invocation, for telemetry
```

The old `${XDG_STATE_HOME}/dotfiles/chezmoi-drift/` becomes orphaned local state. README adds a one-liner note for operators to delete it; we don't ship a migration script.

### Source registry

Each source is a tiny zsh script under `bin/sources/` that exits 0 and writes a fresh `state.env` + `module.{txt,ansi}` for its slot. Contract:

```text
bin/sources/<name> --root <feature-root> --state-dir <state-dir>
```

Per-source check commands:

Each source produces both an **outdated count** and a **managed total** so the row can render `4 / 137 outdated` instead of just `4 outdated`.

| Source  | Outdated check                                                                                   | Managed-total check                                  |
|---------|--------------------------------------------------------------------------------------------------|------------------------------------------------------|
| chezmoi | `chezmoi --no-tty --no-pager --color=false --refresh-externals=never status [--exclude=scripts]` | `chezmoi managed --include=files,symlinks,executables \| wc -l` |
| brew    | `brew outdated --formula --quiet` + `brew outdated --cask --quiet`                               | `brew list --formula -1 \| wc -l` + `brew list --cask -1 \| wc -l` |
| mise    | `mise outdated 2>/dev/null`                                                                      | `mise ls --installed --no-header \| wc -l`           |
| apm     | `apm outdated` (probe `--format json` first; fall back to parsing the table)                     | `apm deps list` row count                            |

The managed-total commands are cheap (filesystem-only or already-cached lockfile reads) so they run inline in the same source script and get cached alongside the outdated count.

Signature per source = `cksum` of the canonicalized check output (same trick as today). `state.env` carries: `CACHE_VERSION=1`, `STATUS_COUNT`, `SIGNATURE`, `UPDATED_AT`, `NEXT_REFRESH_AFTER`, `RESULT (ok|error)`, plus the per-source params used (so an env-var change invalidates cache).

If a check command is missing (`brew` not installed, `apm` not on PATH), the source writes `RESULT=disabled` with a friendly module row like `brew    not installed` and skips re-running until the binary appears. Cheap probe via `whence -p`.

### Refresh dispatcher (`bin/refresh`)

Reuses today's lock pattern (mkdir lock dir, `owner.pid`, `owner.token`, mtime grace, max-age GC). Walks the enabled-sources list. For each:

1. Take the per-source lock; skip if already held + young.
2. If `--if-stale` and the source's `state.env` is fresh (updated_at + per-source TTL > now), exit 0 for that source.
3. Run `bin/sources/<name>`.
4. Release lock.

Per-source refresh runs sequentially (cheap, simple). The shell adapter calls `refresh --if-stale &!` so wall-clock cost stays in the background.

Per-source defaults (overridable in `feature.env`):

| Source  | TTL     | Rationale                                          |
|---------|---------|----------------------------------------------------|
| chezmoi | 3600s   | unchanged from today                               |
| brew    | 86400s  | `brew outdated` hits network; daily is plenty      |
| mise    | 43200s  | `mise outdated` hits network for some backends     |
| apm     | 43200s  | `apm outdated` consults remote refs                |

### fastfetch config

`~/.config/fastfetch/config.jsonc` rendered from `fastfetch/config.jsonc.tmpl`. A couple of small decisions worth being explicit about:

- **No `$schema` line.** The fastfetch wiki suggests pointing it at `…/raw/dev/doc/json_schema.json`, but `dev` is a moving target — pinning the user's editor LSP to whatever's on `dev` today silently rots. fastfetch itself doesn't need the field at runtime. If we want editor autocomplete later, the right move is to pin the schema URL to the same fastfetch version we install via brew (e.g., `…/raw/2.62.1/doc/json_schema.json`) and bump it deliberately. Easier to just leave it off.
- **`logo: none`.** A logo widens the banner and pushes our four status rows further right. Keeping it off means the rows align flush-left where the eye expects them. Adding a small dotfiles glyph is a future-pass thing if we want it.
- **Built-in modules kept narrow.** `os / host / kernel / uptime / shell` is enough to know "what machine am I on" without paying for `gpu`, `disk`, `localip`, etc. — those are the modules that make `fastfetch` slow on some setups.

Roughly:

```jsonc
{
  "logo": { "type": "none", "padding": { "top": 0, "right": 0 } },
  "display": { "separator": "  " },
  "modules": [
    "title",
    "separator",
    "os",
    "host",
    "kernel",
    "uptime",
    "shell",
    "break",
    {
      "type": "command",
      "key": "chezmoi",
      "shell": "{{ .chezmoi.homeDir }}/.config/dotfiles/shell-banner/bin/module",
      "param": "chezmoi"
    },
    {
      "type": "command",
      "key": "   brew",
      "shell": "{{ .chezmoi.homeDir }}/.config/dotfiles/shell-banner/bin/module",
      "param": "brew"
    },
    {
      "type": "command",
      "key": "   mise",
      "shell": "{{ .chezmoi.homeDir }}/.config/dotfiles/shell-banner/bin/module",
      "param": "mise"
    },
    {
      "type": "command",
      "key": "    apm",
      "shell": "{{ .chezmoi.homeDir }}/.config/dotfiles/shell-banner/bin/module",
      "param": "apm"
    },
    "break"
  ]
}
```

The `bin/module <name>` shim:

- Reads `${state}/sources/<name>/state.env`.
- If missing or `RESULT=error`, prints `? unavailable`.
- If `RESULT=disabled`, prints disabled-reason from module file.
- Otherwise prints `module.ansi` (or `module.txt` if `NO_COLOR` set or `--color=never` etc.).

This keeps fastfetch invocation to N tiny `cat`-equivalent calls (one per source). All four sources always render a row — even when clean, so the banner has a consistent shape:

```text
   drift  ──────────────────────────────
 chezmoi   0 / 1255 drifted  · checked 09:42
    brew   4 / 425 outdated  · checked 09:42
    mise   0 / 15 outdated   · checked 09:42
     apm   apm not configured
```

(Sigils are Nerd Font glyphs — `` for outdated/drifted, `` for clean, `` for error/disabled. Colors are 24-bit RGB so the amber/green/red render true on libghostty.)

The `count / total` shape gives the number a denominator so a row like `4 outdated` can't quietly become misleading after a tap shrinks. Total is whatever each source naturally enumerates — managed files for chezmoi, installed formulae+casks for brew, installed tools for mise, deps in `apm.lock.yaml` for apm.

### Shell adapter (`shell/zsh.zsh`)

Behavior on every new interactive shell:

1. Gate: interactive, stdout TTY, `TERM != dumb`, no SSH, feature enabled.
2. Load `feature.env` + optional `local.env` for overrides.
3. If `fastfetch` not on PATH: print a tiny one-line `dotfiles drift` fallback only when chezmoi cache shows drift (so fresh installs don't get a silent void). Otherwise stay quiet.
4. Run `fastfetch --config ~/.config/fastfetch/config.jsonc`.
5. Background `bin/refresh --if-stale &!`.

No precmd hook, no foreground checks, no signature-based dedup (per the user's "every shell, always" choice). The previous dedup state files (`last_shown`, `last_shown_signature`) are dropped.

### Configuration surface

`feature.env.tmpl`:

```sh
: "${DOTFILES_BANNER_ENABLED:=1}"
: "${DOTFILES_BANNER_SOURCES:=chezmoi,brew,mise,apm}"

: "${DOTFILES_BANNER_CHEZMOI_ENABLED:=1}"
: "${DOTFILES_BANNER_CHEZMOI_SCOPE:=files}"
: "${DOTFILES_BANNER_CHEZMOI_REFRESH_TTL_SECONDS:=3600}"

: "${DOTFILES_BANNER_BREW_ENABLED:=1}"
: "${DOTFILES_BANNER_BREW_REFRESH_TTL_SECONDS:=86400}"

: "${DOTFILES_BANNER_MISE_ENABLED:=1}"
: "${DOTFILES_BANNER_MISE_REFRESH_TTL_SECONDS:=43200}"

: "${DOTFILES_BANNER_APM_ENABLED:=1}"
: "${DOTFILES_BANNER_APM_REFRESH_TTL_SECONDS:=43200}"
```

`local.env` keeps the same simple `KEY=value` overlay rules as today's `drift_load_local_config` (relocated and renamed `banner_load_local_config`).

### Packaging

Add to `home/.chezmoidata/packages.toml`:

- `core.brews`: `{ name = "fastfetch" }`
- `full.brews`: `{ name = "fastfetch" }` (profiles don't auto-merge in this repo; both must list it)

### Tests

Rename `tests/chezmoi-drift-banner.zsh` → `tests/shell-banner.zsh`. Generalize the harness:

- Stub each underlying CLI via a `fake-bin/` prepended to `PATH`: `fake-bin/chezmoi`, `fake-bin/brew`, `fake-bin/mise`, `fake-bin/apm`. Each fake reads scenario from an env var (e.g. `FAKE_BREW_OUTDATED="formula1\nformula2"`).
- Per-source scenarios: `clean`, `outdated N`, `error`, `disabled (binary missing)`.
- Refresh: lock contention, stale lock GC, `--if-stale` no-op, env-var change invalidates cache.
- Adapter: no fastfetch on PATH → fallback path; fastfetch on PATH → invokes once, kicks background refresh.
- Module shim: each `bin/module <name>` returns the right text for each `RESULT`.

Add Makefile target `test-shell-banner`. Drop `test-chezmoi-drift-banner`. Update `tests/README.md`.

### Migration / cleanup

- Delete `home/dot_config/dotfiles/chezmoi-drift/` source tree.
- Delete `home/dot_config/zsh/extra/chezmoi-drift.zsh`.
- Update `home/.chezmoiignore` line 8 to point at the new local.env path.
- Repoint `docs/plans/chezmoi-drift-banner-plan.md` at this plan and the shell-banner source. It is already `archived`, so its body stays frozen and only frontmatter moves.
- Add a one-line operator note in the new README: `rm -rf "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/chezmoi-drift"` to discard orphaned state.
- Update `.github/workflows/install-smoke.yml` line that references the drift test target name.

## Critical files to modify or create

Modify:

- `home/.chezmoidata/packages.toml` — add `fastfetch` to `core.brews` and `full.brews`.
- `home/.chezmoiignore` — swap `local.env` path.
- `Makefile` — rename `test-chezmoi-drift-banner` → `test-shell-banner`, update path.
- `.github/workflows/install-smoke.yml` — match new target name.
- `docs/plans/chezmoi-drift-banner-plan.md` — repoint `current_guidance` and `related`.
- `docs/index.md` — swap the drift rows for shell-banner and add this plan.
- `tests/README.md` — update test entry.

Create:

- `home/dot_config/dotfiles/shell-banner/README.md`
- `home/dot_config/dotfiles/shell-banner/feature.env.tmpl`
- `home/dot_config/dotfiles/shell-banner/fastfetch/config.jsonc.tmpl`
- `home/dot_config/dotfiles/shell-banner/bin/executable_refresh`
- `home/dot_config/dotfiles/shell-banner/bin/executable_preview`
- `home/dot_config/dotfiles/shell-banner/bin/executable_module`
- `home/dot_config/dotfiles/shell-banner/bin/sources/executable_chezmoi`
- `home/dot_config/dotfiles/shell-banner/bin/sources/executable_brew`
- `home/dot_config/dotfiles/shell-banner/bin/sources/executable_mise`
- `home/dot_config/dotfiles/shell-banner/bin/sources/executable_apm`
- `home/dot_config/dotfiles/shell-banner/lib/cache.sh`
- `home/dot_config/dotfiles/shell-banner/lib/sources.sh`
- `home/dot_config/dotfiles/shell-banner/shell/zsh.zsh`
- `home/dot_config/zsh/extra/shell-banner.zsh`
- `tests/shell-banner.zsh`

Delete:

- `home/dot_config/dotfiles/chezmoi-drift/` (entire tree)
- `home/dot_config/zsh/extra/chezmoi-drift.zsh`
- `tests/chezmoi-drift-banner.zsh`

## Code reused from today

- Locking + GC: lines 73–128 of `home/dot_config/dotfiles/chezmoi-drift/bin/executable_refresh` (mkdir lock, `owner.pid`/`owner.token`/`started_at`, mtime grace, stale-rename + delete) — generalized per-source.
- State env loader/writer + uint/token validators: `drift_load_state`, `drift_write_state_env`, `drift_is_uint`, `drift_is_token` from `lib/cache.sh` — renamed `banner_*` and parameterized on source name.
- Local-env overlay: `drift_load_local_config` from `lib/cache.sh` — renamed and parameterized on prefix.
- Test harness scaffolding: `assert_*`, `chezmoi apply --include=files` rendering pattern, `mktemp -d` lifecycle from `tests/chezmoi-drift-banner.zsh` lines 1–80.

## Verification

Run from the repo root before handoff:

```sh
# Render the new feature into a scratch home + sanity-check the artifacts.
chezmoi --source "$PWD/home" apply --dry-run --verbose --include=scripts
chezmoi --source "$PWD/home" apply --dry-run --verbose --include=files \
  "$HOME/.config/dotfiles/shell-banner" \
  "$HOME/.config/zsh/extra/shell-banner.zsh" \
  "$HOME/.config/fastfetch/config.jsonc"

# Generalized regression coverage.
just test-shell tests/bats/hooks/shell-banner.bats

# Startup-time sanity (must not regress vs current baseline).
scripts/audit/zsh-fresh-shells.zsh verify --dotfiles-root "$PWD"
scripts/audit/zsh-fresh-shells.zsh bench  --dotfiles-root "$PWD"

# Live smoke once the source tree is rendered to $HOME:
#   - First shell: fastfetch should print system info + 4 source rows (some may say "? unavailable" until refresh runs).
#   - Background `refresh --if-stale` should populate caches; second shell shows real counts.
DOTFILES_BANNER_ENABLED=1 zsh -i -c true

# Diff guard for whitespace/CRLF surprises in the templated config.
git diff --check
```

Mirror CI locally by inspecting `.github/workflows/install-smoke.yml` after the rename to confirm the new make target is wired in.

## Risks / open questions

- **fastfetch startup cost.** Every new interactive shell now spawns `fastfetch`, which is wall-clock cost the user can feel. Measured on this M-series Mac with the brewed `fastfetch 2.62.1`:
  - `fastfetch --logo none` with stock modules only: ~40–50 ms wall.
  - With our four `command` modules wired in (each forks `/bin/sh -c` then exec's a zsh shim that reads a cached row): full render lands around **~90 ms median, with occasional spikes to 200 ms** under load. The `command` modules dominate the surplus.
  - That's a few cache windows above the original "sub-1 ms per row" guess. Cheap mitigations if the cost ever bites: switch the `bin/module` shebang from `zsh` to `sh` and use `cat` directly (avoids the zsh startup per row), or concatenate all four rows into a single cache file so fastfetch only needs one `command` module.
  - The async fallback (run fastfetch in `precmd` after the first prompt paints) is left as a contingency. It contradicts "every interactive shell, always" because the very first prompt comes up before the banner, so we'd only reach for it if the synchronous cost actually shows up in the bench. The `zsh-fresh-shells bench` script is the gate.
- **`apm outdated` shape.** Verified via the [Microsoft APM CLI reference](https://microsoft.github.io/apm/reference/cli-commands/) that `apm outdated` exists today and emits a `Package | Current | Latest | Status | Source` table with status values `up-to-date | outdated | unknown`. The repo's `apm` is shimmed via mise (`pipx:apm-cli`) but no version is currently pinned on this machine — whichever version installs at apply time wins. The docs show a `-f, --format [text|json|sarif|markdown]` flag pattern in adjacent subcommands; the source script probes `apm outdated --format json` first and falls back to text-table parsing if that flag is unsupported. A more conservative fallback (count lines whose status column is `outdated`) is what ships in the first cut.
- **Profile inheritance.** `core` and `full` are defined as separate blocks, so `fastfetch` is added to both. If the brewfile renderer ends up unioning them later, we deduplicate then.
- **Live-state cleanup.** Old `${XDG_STATE_HOME}/dotfiles/chezmoi-drift/` is left in place; documented as a one-liner in the new README rather than scripted, since machine-local state is not chezmoi's responsibility.

## Deferred

- **apm row.** The source script and lib wiring exist and are tested,
  but `apm` is excluded from `DOTFILES_BANNER_SOURCES` by default and
  has no `command` module in the fastfetch config. Reason: this
  machine's apm setup keeps lockfiles per-package under
  `~/.agents/packages/<name>/apm.lock.yaml` (six packages today), not
  a single root lockfile, so the single-`apm outdated`-from-$HOME
  shape the script was written around always reports "no lockfile."
  Re-enabling means iterating each `~/.agents/packages/*/apm.lock.yaml`,
  running `apm outdated` per-package, parsing the trailing
  `[!] N outdated dependency found` summary line, and summing. Cost
  is ~6 sequential network round-trips per refresh; per-source TTL
  (12h) amortizes. Not worth the complexity for the first cut.

## Deviations from plan as shipped

A handful of details changed during implementation review:

- **`feature.env` and `config.jsonc` are not templates.** Both files were initially `*.tmpl` so chezmoi would render them through Go templates. Neither file actually used any template directives, so the suffix was dropped and they ship as static files. (A dangerous fallback in `banner_load_config` that would have sourced `feature.env.tmpl` as zsh was also removed.)
- **fastfetch config lives at the conventional path.** `home/dot_config/fastfetch/config.jsonc` rather than `home/dot_config/dotfiles/shell-banner/fastfetch/config.jsonc.tmpl`. Bare `fastfetch` invocations now pick up our config without needing `--config`.
- **fastfetch fallback was simplified.** Plan said the adapter would print a tiny drift line from cache when fastfetch is missing. Reality: it prints a single one-liner (`shell-banner: fastfetch not installed yet (run `brew install fastfetch`)`). The cache-replay path was a lot of code to handle a one-shell-per-machine scenario.
- **Source-script runner.** `lib/source_runner.sh` was added during refactor — wraps the four `bin/sources/*` scripts so they each shrink to a single check function plus an entry call. Cuts ~240 LOC of duplication that the original plan didn't anticipate.
- **chezmoi managed include.** Plan listed `--include=files,symlinks,executables`; `executables` is not a valid chezmoi entry type. Shipped with `--include=files,symlinks` (executable bits ride along on `files`).
- **brew check.** Plan listed two outdated calls (`--formula` + `--cask`) and two list calls; reality is one each (`brew outdated --quiet` and `brew list -1`).
- **apm probe.** Plan didn't account for the `apm` binary often being a mise shim with no version pinned. Shipped script probes `apm --version` first and downgrades to `disabled (apm not configured)` if that fails, so machines that don't actually use apm don't get a permanent error row.
- **`display.key.width: 8` in the fastfetch config.** Plan example included it; reality is fastfetch implements it with a CSI cursor escape (`\e[8G`) that pollutes any captured output. Dropped — keys are hand-padded to width 8 and align fine without it.
- **Adapter subshell.** The shell adapter (`shell/zsh.zsh`) runs the entire flow inside a subshell so the helper functions and config variables don't pollute the user's interactive shell. The original sketch did a more elaborate save-and-restore dance for `banner_*` functions — replaced by the subshell wrap.

## Rebase onto current trunk

The October 2026 rebase keeps trunk's Just/Bats CI entrypoints and the removal
of Makefile and the old plist zsh harness. The shell-banner regression scenario
is discovered through `tests/bats/hooks/shell-banner.bats`. Its chezmoi render
uses an empty config, a CI machine override, and a temporary destination.
See [the test index](../../tests/README.md) for the retired drift assertions,
retained behavior checks, and restored blocked-refresh and cache-repair tests.
Freshness now requires both rendered rows to be readable; a timestamp alone
cannot suppress repair when `module.txt` or `module.ansi` is missing.

## Adversarial review corrections

The deployed old loader and known feature files are explicitly retired through
`.chezmoiremove`; local overrides remain on disk. Mise probes and its current,
installed denominator now run from home with a new cache scope token. Rendering
loads the same local configuration as refresh and honors XDG/feature-root paths.
Disabled sources render as disabled, and no enabled sources is a successful
no-op. A kernel advisory guard serializes directory-lock inspection, recovery,
and release while retaining the existing ten-minute check age cap.

The focused Bats config, upgrade, and lock suites cover these corrections in
addition to the cache-repair and blocked-refresh checks. See the
[test index](../../tests/README.md) for the combined command.
