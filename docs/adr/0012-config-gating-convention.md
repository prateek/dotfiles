---
status: accepted
doc_type: adr
created: 2026-06-26
owner: Prateek
related:
  - ../references/chezmoi-architecture.md
  - 0010-machine-type-package-selection.md
  - 0011-private-repo-config-overlays.md
status_detail: "Accepted convention for chezmoi config toggles. The going-forward layered-table model (machines.toml + features.tmpl, no config env vars) is implemented; current guidance is docs/references/chezmoi-architecture.md."
---

# ADR 0012 — Config-gating convention

## Context

Feature toggles in this repo settled into three forms: values derived from
`machine_type`, `env` plus `promptBoolOnce`/`promptChoiceOnce`, and
`env | default`. No doc said when to use each form, so every new toggle needed
a fresh decision. Two sharp edges kept recurring:

- chezmoi errors on a missing `[data]` key, so referencing a brand-new key from a
  template breaks every already-inited machine until it re-inits.
- `default x (promptBoolOnce ...)` evaluates both arms, so the prompt fires even
  when the env var is already set.

The private-overlay work ([ADR 0011](0011-private-repo-config-overlays.md))
exposed the gap. A work-only external had no gating convention to cite. An
audit found three buckets. This ADR names those buckets and does not refactor
flags.

## Decision

chezmoi merges one flat data dict from two layers. Classify toggles by that
split:

- **Render-time / auto-derived**: `.chezmoi.*` (`os`, `arch`, `hostname`, …) and
  `.chezmoidata` static files; recomputed on every `apply`, never prompted.
- **Init-time / declared**: the `[data]` block written by
  `home/.chezmoi.toml.tmpl` at `chezmoi init` and frozen until re-init. Each value
  resolves by precedence: `env DOTFILES_X` → else `prompt*Once` (persisted) → else
  a default.

Apply-time runtime switches (`$DOTFILES_*` read directly in scripts and hooks,
such as `DOTFILES_SKIP_PLIST_HOOKS`, `DOTFILES_RELAUNCH_AFTER_APPLY`, …) are
separate. They are not in `[data]` and are not managed desired state.

An init-time toggle answers two questions: *what sets the value* and *is it worth
a prompt*. The three shapes below fit that chain:

- **Role-derived**: read an already-resolved fact, almost always `.machine_type`
  (e.g. `eq .machine_type "work"`); no toggle of its own. (`machine_type` is itself
  a first-run choice; consumers just read it.) Examples: package groups, work-only
  externals/overlays, the non-work elevation default.
- **First-run choice (prompted)**: `env "DOTFILES_X"`, else `prompt*Once`
  (`promptBoolOnce` / `promptChoiceOnce` / `promptStringOnce`), persisted in state.
  For a preference worth asking once: `machine_type`, `secrets_enabled`,
  `run_install_scripts`, `apply_macos_defaults`, `elevation_method`.
- **Automation override (defaulted)**: `env "DOTFILES_X" | default "<v>"`: the
  same init-time choice minus the prompt, for a flag with a safe default not worth
  asking. No current toggle uses this shape.

Rules:

- `machine_type` is a first-run choice; package consumers re-resolve it
  defensively as
  `env DOTFILES_MACHINE_TYPE > .machine_type > .packages.default_machine_type`
  (see [ADR 0010](0010-machine-type-package-selection.md)). `.chezmoidata/*` is not
  loaded during `chezmoi init`, so `.chezmoi.toml.tmpl` inlines init-time defaults.
- Reading a key bare (e.g. `.machine_type`) is fine once it is
  unconditionally set in `.chezmoi.toml.tmpl`. The hazard is a newly-added key
  referenced before existing machines re-init: chezmoi errors on the missing key.
  During that window, gate on a long-standing key or read with
  `dig "key" <default> .`.
- Do not write `default x (promptBoolOnce ...)`; use an explicit `{{ if not $x }}`
  short-circuit.
- Name env vars `DOTFILES_<UPPER_DATA_KEY>` (e.g. `apply_macos_defaults` →
  `DOTFILES_APPLY_MACOS_DEFAULTS`).
- `ci` is a first-class `machine_type`: a normal entry in the `promptChoiceOnce`
  list, selectable interactively or via `env DOTFILES_MACHINE_TYPE` /
  `--promptChoice`. It is the minimal CI/Tart/audit tier; humans rarely pick it.
- Hybrids are allowed: a role can decide whether a prompt fires at all. Elevation is
  `none` off-work and prompts only on `work`.

## Updating a toggle

The layer determines how a toggle changes:

- **Render-time** (`.chezmoi.*`, `.chezmoidata`): edit the data file (or nothing;
  `.chezmoi.*` re-derives) and the change lands on the next `chezmoi apply`, no
  re-init. This is the cheap path, which is why package/role tables live in
  `.chezmoidata`.
- **Init-time** (`[data]`): the value is frozen in the rendered
  `~/.config/chezmoi/chezmoi.toml`. Change it by editing that `[data]` block
  directly, or re-run `chezmoi init` and pass `--prompt` to force a re-answer (or
  clear the config). `prompt*Once` otherwise reuses the stored answer. So keep things
  you expect to change in render-time data and reserve init-time `[data]` for
  set-once identity facts.

`prompt*` and `env` are two ends of the same init-time chain. `prompt*Once` is
the interactive first-run path: a persisted human answer guarded by `stdinIsATTY`
so it never hangs. `env DOTFILES_X` is the non-interactive override. It
short-circuits the prompt, so CI and containers set the value without being asked
(`chezmoi init --promptDefaults` makes every prompt take its default).

## Current toggles in this repo

The init-time data toggles are defined in `home/.chezmoi.toml.tmpl` and
materialized into `[data]`:

| Toggle | Style | Configured by | Default |
| --- | --- | --- | --- |
| `machine_type` | first-run choice | `env DOTFILES_MACHINE_TYPE`, else `promptChoiceOnce` (personal/homelab/work/ci) | `personal` |
| `secrets_enabled` | first-run choice | `env DOTFILES_SECRETS_ENABLED`, else `promptBoolOnce` | `false` |
| `run_install_scripts` | first-run choice | `env DOTFILES_RUN_INSTALL_SCRIPTS`, else `promptBoolOnce` | `true` |
| `apply_macos_defaults` | first-run choice | `env DOTFILES_APPLY_MACOS_DEFAULTS`, else `promptBoolOnce` | `true` |
| `elevation.method` | role-gated prompt (hybrid) | `env DOTFILES_ELEVATION_METHOD`; else on `work` `promptStringOnce`, otherwise `none` | `none` off-work; prompts on `work` |
| `elevation.jamf_policy_id` | conditional first-run | `env DOTFILES_JAMF_POLICY_ID`; else `promptStringOnce` when method is `jamf-self-service` | `""` |

(`dotfiles_dir` and the `xdg_*_dir` keys are `env | default` path plumbing, not
feature gates.)

Role-derived consumers read the resolved `machine_type` and carry no toggle of
their own:

- Package selection: `home/.chezmoitemplates/brewfile.tmpl` and
  `package-cask-enabled.tmpl` take the union of `[packages.groups.*]` for the
  selected type, resolving `env DOTFILES_MACHINE_TYPE > .machine_type >
  .packages.default_machine_type` ([ADR 0010](0010-machine-type-package-selection.md)).
- Apply-time installs keyed on group membership:
  `run_onchange_after_10-brew-bundle` (brew pre-update and the MAS notice on
  `has "dev"`), `run_onchange_after_12-gh-extensions`, and
  `run_onchange_after_15-xcode` (`has "dev-apple"`).
- `home/.chezmoiignore` (~18 gates): app config is skipped unless its cask is in
  the selected groups; license paths are gated on `secrets_enabled`.
- `home/.chezmoiexternal.toml.tmpl`: the `dotfiles-private` overlay clones only on
  `machine_type == work` ([ADR 0011](0011-private-repo-config-overlays.md)); zinit
  clones unconditionally.
- `home/dot_config/grm/config.toml.tmpl` and
  `home/dot_config/zsh/lib/prompt.zsh.tmpl` branch on `machine_type`.

Other gates:

- `run_install_scripts` gates the nine apply-time `run_*` scripts (homebrew,
  core-tools, brew-bundle, gh-extensions, xcode, mise-install, raycast-extensions,
  hammerspoon, macos-defaults); macos-defaults also requires `apply_macos_defaults`.
- Mac App Store entries render only under `DOTFILES_INSTALL_MAS_APPS=true` (or
  `render-brewfile --include-mas`).

Apply-time runtime switches read directly via `env`/`$DOTFILES_*` in scripts and
hooks. They are never stored in `[data]` and are not managed desired state:

- Plist apply hooks: `DOTFILES_SKIP_PLIST_HOOKS`, `DOTFILES_RELAUNCH_AFTER_APPLY`.
- App and registration refresh: `DOTFILES_SKIP_APP_RESTART`,
  `DOTFILES_SKIP_LSREGISTER`, `DOTFILES_SKIP_SPOTLIGHT_REINDEX`, `DOTFILES_SKIP_LAUNCHCTL_SYNC`.
- Homebrew tuning: `DOTFILES_HOMEBREW_BUNDLE_JOBS`,
  `DOTFILES_HOMEBREW_DOWNLOAD_CONCURRENCY`.
- Xcode: `DOTFILES_INSTALL_XCODE` forces the Apple-ID Xcode download on a
  non-interactive apply (the `15-xcode` script otherwise check&sets by presence).
- Drift banner: the `DOTFILES_CHEZMOI_DRIFT_*` family.
- Tart/VM validation: the `DOTFILES_TART_*` family; tracing via `DOTFILES_TRACE*`.
- Elevation secret: `DOTFILES_SUDO_PASSWORD` (never stored).

## Prior art (chezmoi community)

Surveyed chezmoi's docs and CLI plus ~27 popular dotfiles repos (including
[twpayne/dotfiles](https://github.com/twpayne/dotfiles), the author's own).

- chezmoi enforces only the render-time vs init-time split; every source lands in
  one flat dict, so a template cannot tell whether `.foo` was auto-derived,
  prompted, or env-overridden
  ([templating](https://www.chezmoi.io/user-guide/templating/)).
- chezmoi has no built-in machine "type/class". The official primitive is
  `promptChoiceOnce` into a `[data]` key; most repos instead branch on
  `.chezmoi.os` / `.chezmoi.hostname` plus a few `[data]` booleans
  ([machine differences](https://www.chezmoi.io/user-guide/manage-machine-to-machine-differences/)).
- The widely-copied reference pattern (twpayne) computes a few feature flags once
  in `.chezmoi.toml.tmpl`: auto-detect what it can (`env "CODESPACES"`, username),
  hostname-map known hosts, `prompt*Once` for the rest behind a `stdinIsATTY`
  guard, safe defaults when non-interactive, then branches on those flat flags
  everywhere (notably inverted `.chezmoiignore`, since chezmoi installs by
  default). Our single `machine_type` enum is supported but less common; the field
  leans toward auto-derived facts plus booleans.
- The same hazards appear in the community: `default x (prompt …)` evaluates
  both arms, and chezmoi defaults to `missingkey=error`.

Idioms worth adopting if this grows: a `stdinIsATTY`/CI guard on prompts;
auto-deriving facts (`.chezmoi.os`, `hostnamectl chassis`) instead of asking;
`.chezmoidata` tables keyed by role (a `home`/`work` column); and the macOS
`scutil --get LocalHostName` hostname workaround.

## Going forward (simplified model)

A 3-model review (gemini-3.1-pro, gpt-5.5-extra-high,
claude-opus-4-8-thinking-xhigh) converged on (A) one identity prompt and (B) a
single behavior table. Two adversarial passes then removed the per-flag env vars
and made the table compose richer attributes than `machine_type`. Migration and
testing live in
[the simplification plan](../plans/config-gating-simplification-plan.md).

- **A: one identity prompt.** `machine_type` stays the only first-run prompt; every
  other toggle becomes table-derived. No config env var: CI/Tart select a type with
  `chezmoi init --apply --promptChoice 'Machine type=work'` (the flag keys on the
  prompt text; `--promptDefaults` only takes the `personal` default). This also fixes
  a bug: `run_install_scripts` / `apply_macos_defaults` are frozen at init yet gate
  apply-time scripts; table reads make them render-time.
- **B: one layered table.** `home/.chezmoidata/machines.toml` declares behavior in
  layers; `home/.chezmoitemplates/features.tmpl` merges the applicable layers (later
  layers win) into one feature set, emitted as JSON so consumers `fromJson` it into
  native bools with one include. Precedence, low → high: `defaults` < `os.<os>` <
  `type.<machine_type>` < `host.<hostname>` < host-local `[data].machines_local`.
  Today only the `type` layer is populated (folding in
  `[packages.machine_types.*]`); the `os`/`host` layers exist for when a Linux
  homelab flavor or a Windows box needs them, with no new enum and no per-file `eq`
  ladders.

Rules new changes follow under this model:

- `[data]` is identity only: `machine_type`, paths, `jamf_policy_id`. No behavior
  toggles in `[data]`.
- Add or change behavior by editing a layer in `machines.toml`. It is render-time,
  so it lands on the next `apply` with no re-init. A new role is a `type.*` layer; a
  richer attribute (OS, host, flavor) is an `os.*` / `host.*` layer.
- Read behavior through the resolver (one `includeTemplate "features.tmpl" .`),
  never a bare `.key` or a scattered `eq .machine_type "work"`.
- The resolver `fail`s on an unknown `machine_type` (it matches no `type` layer).
  `--promptChoice` does not validate its value, so the resolver is the typo guard —
  keep the package templates' fail-on-unknown behavior.
- No config env vars. `machine_type` is answered interactively, or non-interactively
  with `--promptChoice 'Machine type=<type>'` (keyed on the prompt text);
  per-machine exceptions use a documented host-local `[data].machines_local` block
  (chezmoi-ignored), merged last by the resolver. Apply-time runtime switches
  (`DOTFILES_SKIP_*`) remain a separate layer, never in the table.
- `ci` is a normal `machine_type`: a `type.ci` layer and a prompt-list entry,
  selected by `--promptChoice 'Machine type=ci'`. `--promptChoice` does not check the
  list, so `ci` needs no special handling; the old env-only treatment was the
  artifact. The interactive default stays `personal`.
- Prompt only for identity. Call `promptChoiceOnce` unguarded so `--promptChoice
  'Machine type=<type>'` can select non-interactively; a `stdinIsATTY` else-branch
  would force `personal` and block that. The unguarded call errors clearly (it does
  not hang) when a non-interactive run gives no answer. Auto-derive OS/host.

## Consequences

- New toggles have a rule. The missing-key and both-arms `default` footguns are
  written down.
- The audit found two non-conforming flags, now fixed here: `apply_macos_defaults`'s
  env var is renamed to `DOTFILES_APPLY_MACOS_DEFAULTS`, and `ci` joins the
  `machine_type` prompt list as a first-class type. Every other flag already conformed.
- Xcode is no longer a config toggle: `run_onchange_after_15-xcode` check&sets it by
  presence (installs the pinned version when absent, on an interactive apply or with
  `DOTFILES_INSTALL_XCODE=true`).
- `home/.chezmoi.toml.tmpl`'s header docstring and
  `docs/references/chezmoi-architecture.md` point here.

## Alternatives considered

- A prose section in `docs/references/chezmoi-architecture.md` (the initial path).
  Rejected: a standalone decision record is easier to find.
  The architecture reference now links here instead of carrying the prose.
- Leave it undocumented and decide per-toggle. Rejected: that is the status quo
  that let the footguns recur.
