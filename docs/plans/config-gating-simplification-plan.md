---
status: accepted
doc_type: plan
owner: Prateek
created: 2026-06-26
related:
  - ../adr/0012-config-gating-convention.md
  - ../adr/0010-machine-type-package-selection.md
  - ../references/chezmoi-architecture.md
status_detail: "Accepted direction (layered table, no config env vars); implementation pending."
---

# Config-Gating Simplification Plan

## Context

[ADR 0012](../adr/0012-config-gating-convention.md) reduced the three styles to
two timing choices: render-time and init-time. A 3-model review chose one identity
prompt and one behavior table. Two adversarial passes tightened the design: drop
the magic per-flag env vars, and let the table compose attributes beyond
`machine_type` (OS, host, flavor). This plan uses that design.

## Target

- **A: one identity prompt.** `machine_type` is the only first-run prompt. CI/Tart
  select a type non-interactively with `chezmoi init --apply --promptChoice
  'Machine type=work'` (the flag keys on the prompt text, not the field name). No
  env var. `--promptDefaults` only takes the `personal` default; it cannot pick
  another type.
- **B: one layered table.** `home/.chezmoidata/machines.toml` declares behavior in
  layers. `home/.chezmoitemplates/features.tmpl` merges the applicable layers into
  one feature set (later layers win). Precedence, low to high:
  `defaults` < `os.<os>` < `type.<machine_type>` < `host.<hostname>` <
  host-local `[data].machines_local`.
- **No config env vars.** chezmoi populates prompts non-interactively with
  `--promptChoice 'Machine type=<type>'`, so no `DOTFILES_*` config var is needed.
  Those vars were the undocumented surface. Per-machine exceptions live in an
  explicit host-local `[data].machines_local` block. Apply-time runtime switches
  like `DOTFILES_SKIP_*` stay in their separate layer.

Result: `[data]` holds identity only (`machine_type`, paths, `jamf_policy_id`).
One table composes behavior from attributes. The only override knob is a
documented host-local `[data].machines_local` block.

## Why this shape

- **Env vars.** chezmoi selects a type non-interactively with
  `chezmoi init --apply --promptChoice 'Machine type=work'` (the flag keys on the
  prompt text; verified on chezmoi v2.70.3), so CI/Tart need no env var.
  `--promptDefaults` only takes the `personal` default, and piping on stdin does not
  reach `promptChoiceOnce` — neither selects a non-default type, so use
  `--promptChoice`. Standalone renders (`render-brewfile`) pass `.machine_type`
  through a temp `--config` `[data]` block, replacing the old `DOTFILES_MACHINE_TYPE`
  env. A one-off machine difference belongs in that machine's own config
  (`[data].machines_local`). The table plus `machines_local` is the registry.
- **Richer attributes than `machine_type`.** A single enum cannot express "Linux
  homelab flavor" or "Windows gaming rig". Layering handles those cases: add an
  `[os.windows]` or `[host.gaming-rig]` (or a new `[type.*]`) layer and it
  composes, avoiding a combinatorial enum and per-file `eq` ladders.
  `machine_type` stays the primary role axis. `.chezmoi.os` and
  `.chezmoi.hostname` are auto-derived and need no prompt.

## Code examples

The layered table (`home/.chezmoidata/machines.toml`, new):

```toml
[machines.defaults]
groups = ["base"]
run_install_scripts = true
apply_macos_defaults = true
secrets_enabled = false          # enable per machine via [data].machines_local
private_overlay = false
elevation = "none"

[machines.type.work]
groups = ["base", "dev", "dev-apple"]
private_overlay = true
elevation = "jamf-self-service"

[machines.type.personal]
groups = ["base", "dev", "dev-apple", "personal-apps"]

[machines.type.homelab]          # same as personal today
groups = ["base", "dev", "dev-apple", "personal-apps"]

[machines.type.ci]
groups = ["base"]
run_install_scripts = false
apply_macos_defaults = false

# richer attributes compose as layers — no new enum, no scattered conditionals:
[machines.os.windows]
apply_macos_defaults = false

[machines.host.gaming-rig]       # a specific Windows box
groups = ["base", "games"]
```

The resolver (`home/.chezmoitemplates/features.tmpl`, new) merges the layers (later
layers win) and emits JSON. Consumers `fromJson` it into native bools with one
include:

```
{{- /* layers low→high: defaults < os.<os> < type.<machine_type> < host.<hostname>
       < host-local [data].machines_local.
       usage: {{- $f := includeTemplate "features.tmpl" . | fromJson -}} */ -}}
{{- $mt := coalesce (dig "machine_type" "" .) "personal" -}}
{{- $M := .machines -}}
{{- if not (hasKey $M.type $mt) -}}{{- fail (printf "unknown machine_type %q (add a [machines.type.%s] layer)" $mt $mt) -}}{{- end -}}
{{- $f := deepCopy (dig "defaults" dict $M) -}}
{{- $f = mergeOverwrite $f (deepCopy (dig "os"   .chezmoi.os       dict $M)) -}}
{{- $f = mergeOverwrite $f (deepCopy (dig "type" $mt               dict $M)) -}}
{{- $f = mergeOverwrite $f (deepCopy (dig "host" .chezmoi.hostname dict $M)) -}}
{{- $f = mergeOverwrite $f (deepCopy (dig "machines_local" dict .)) -}}
{{- $f | toJson -}}
```

Layer order decides scalars: the last layer that sets a key wins. A list like
`groups` is replaced by the highest layer that sets it. Keep feature values flat —
scalars and lists, no nested tables — so merging stays simple last-writer-wins. An
unknown `machine_type` matches no `type` layer and the resolver `fail`s loud — that is the typo guard, matching today's fail-on-unknown package
templates and the bogus-type test. `--promptChoice` does not validate its value
(see below), so the resolver is where a bad type is caught.

`ci` is a first-class `machine_type`: a `type.ci` layer in the table and an entry in
the prompt list. Select it non-interactively with
`chezmoi init --apply --promptChoice 'Machine type=ci'`. `--promptChoice` accepts any
value without checking the list, so `ci` needs no special handling; it is listed for
completeness and interactive use. The old env-only treatment was the artifact. The
interactive default stays `personal`; humans do not pick `ci`.

`home/.chezmoi.toml.tmpl` holds identity only. Call `promptChoiceOnce` unguarded: it
prompts interactively, takes `--promptChoice 'Machine type=<type>'`
non-interactively, and errors clearly (it does not hang) when a non-interactive run
gives no answer. Do not wrap it in a `stdinIsATTY` else-branch that defaults to
`personal` — that forces `personal` on every non-interactive run and blocks
`--promptChoice` selection:

```
{{- $machineType := promptChoiceOnce . "machine_type" "Machine type" (list "personal" "homelab" "work" "ci") "personal" -}}
[data]
machine_type = {{ $machineType | quote }}
```

Per-machine exceptions use an explicit, documented host-local block:

```toml
# ~/.config/chezmoi/chezmoi.toml   (host-local, chezmoi-ignored)
[data.machines_local]
secrets_enabled = true
```

Consumers resolve once, then branch on native bools:

```
# .chezmoiexternal.toml.tmpl
{{- $f := includeTemplate "features.tmpl" . | fromJson -}}
{{- if $f.private_overlay }}
[".local/share/dotfiles/private"]
  type = "git-repo"
  url = "git@github.com:prateek/dotfiles-private.git"
{{- end }}

# run_onchange_after_*.sh.tmpl — render-time gate (fixes the frozen-at-init bug)
{{- $f := includeTemplate "features.tmpl" . | fromJson -}}
{{- if $f.run_install_scripts }} ... {{- end }}

# brewfile.tmpl / package-cask-enabled.tmpl  (the latter passes .root)
{{- $f := includeTemplate "features.tmpl" . | fromJson -}}
{{- range $f.groups }} ... {{- end }}
```

Non-interactive type selection (the flag keys on the prompt text):

```sh
chezmoi init --apply --promptChoice 'Machine type=work'   # any type, incl. ci
chezmoi init --apply --promptDefaults                     # personal default only
```

## Changes

- Add `home/.chezmoidata/machines.toml` (layered) and
  `home/.chezmoitemplates/features.tmpl` (resolver).
- `home/.chezmoi.toml.tmpl`: keep only `machine_type` (+ paths,
  `jamf_policy_id`) among prompts and `[data]` keys. Remove all per-flag
  `DOTFILES_*` reads.
- `home/.chezmoidata/packages.toml`: move `[packages.machine_types.*]` groups into
  `machines.toml` (`type.*` layers); keep `[packages.groups.*]`.
- `scripts/packages/render-brewfile`: pass the machine type via a temp `--config`
  `[data]` block (`execute-template` reads it reliably), replacing the
  `DOTFILES_MACHINE_TYPE` env; CI/Tart full applies use
  `chezmoi init --apply --promptChoice 'Machine type=<type>'`.
- Migrate every direct reader before dropping any key (`rg` confirms completion).
  Known today:
  `.run_install_scripts` (`run_once_before_00-homebrew`, `05-core-tools`, the
  `run_onchange_after_*` install scripts); `.secrets_enabled` (`.chezmoiignore`,
  `run_onchange_after_90-verify`, the Moom/Alfred/BetterTouchTool license
  templates); `.packages.machine_types` groups (`brewfile.tmpl`,
  `package-cask-enabled.tmpl`, `run_onchange_after_10/12/15`); `.machine_type`
  branches (`.chezmoiexternal.toml.tmpl`, `grm/config.toml.tmpl`,
  `prompt.zsh.tmpl`, elevation).
- Update [ADR 0010](../adr/0010-machine-type-package-selection.md), the
  `chezmoi-management` skill, and the tests that encode today's shape:
  `tests/brew-bundle-script.zsh` (its `--override-data` keys
  `run_install_scripts` / `apply_macos_defaults` / `secrets_enabled` become
  `machines.toml`-backed reads), `tests/package-gated-configs.zsh` (the unknown-type
  case still asserts a non-zero exit), and `tests/chezmoi-config.zsh` (it selects via
  `DOTFILES_MACHINE_TYPE` and asserts the `[data]` keys persist — rework it for
  `--promptChoice` and the slimmed `[data]`).

## Migration

- New consumers read `machines.toml` at render time and resolve `machine_type` from
  `[data]` (default `personal`). They work on already-inited machines without
  re-init.
- Move per-machine operational opt-outs from prompted `[data]` keys to
  `[data].machines_local`. Audit each machine's current `[data]` for non-default
  values and express them in `machines_local` (or as a `type`/`host` layer) before
  dropping the keys. Do not preserve the old per-flag env vars.
- Dropping prompts means `chezmoi init` no longer asks for them. That is intended.

## Testing plan

- `make test-docs-lifecycle`; `make test-agent-skill-packages` /
  `test-claude-settings` / `test-codex-config` if skill refs change.
- chezmoi dry-run for `ci` / `personal` / `homelab` / `work`
  (`scripts/chezmoi/test-apply-dry-run.sh`, with `MISE_TRUSTED_CONFIG_PATHS`).
- `scripts/packages/render-brewfile --machine-type {ci,personal,work}`: package
  selection should stay unchanged after the fold into `type.*` layers.
- `chezmoi execute-template` resolver matrix for `features.tmpl`:
  - layer precedence: a flag set in `defaults`, `os`, `type`, `host`, and
    `machines_local` resolves to the highest layer; `groups` is replaced by the
    highest layer that sets it.
  - `machine_type`: resolves from `[data]` (set by `--promptChoice 'Machine
    type=<type>'` or a temp `--config`); an empty `[data]` (un-inited) resolves via
    the `personal` default; an unknown type `fail`s loud. `--promptChoice` keys on
    the prompt text and does not validate its value, so feed a bogus type and confirm
    the resolver rejects it. Isolate any real-`init` test with temp
    `--config`/`--persistent-state`/`--source`; `HOME` alone does not isolate it when
    `XDG_CONFIG_HOME` is set.
  - host/os layers apply for a matching `.chezmoi.hostname` / `.chezmoi.os`.
  - `machines_local` overrides everything (e.g. `secrets_enabled = true`).
  - `secrets_enabled` stays `false` from the table; verify that a secret/license
    template does not fail with empty `op://` refs unless `machines_local` enables
    it.
- Update `tests/brew-bundle-script.zsh` + `tests/package-gated-configs.zsh` to the
  layered shape; add a shape test for every `type.*` resolving a complete feature
  set.
- Optional: a Tart lane for a full apply.

## Rollout order

1. Add `machines.toml` + `features.tmpl` (additive; nothing reads them yet).
2. Use `rg` to find every direct reader, then switch them to the resolver in
   clusters, validating each via dry-run: first the package groups +
   `run_install_scripts` + `apply_macos_defaults` (these also get the render-time
   bug fix), then `secrets_enabled`, zinit, the private overlay, and elevation.
3. Remove the old `[data]` keys, prompts, and per-flag `DOTFILES_*` reads last.
4. Update ADR 0010, the `chezmoi-management` skill, and the evals/tests.

## Risks

- The `packages.toml` / skill / eval surface changes. Mitigate with the shape test
  and same-change eval updates.
- One table couples packages with behavior; a typo can affect many renders. The
  shape test plus a render of every type contain the blast radius.
- Layer precedence must be visible. Document the order at the top of
  `machines.toml` and `features.tmpl` so readers can see which layer won.
