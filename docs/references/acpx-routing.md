---
status: current
doc_type: reference
summary: "Machine model discovery, agent-selected capability shortcuts, native delegation, access policy, and cache diagnostics."
created: 2026-09-22
updated: 2026-10-19
related:
  - ../research/cursor-acp-model-selection.md
  - ../adr/0056-agent-selected-model-routing.md
  - ../../agent-marketplace/packages/utils-agent/skills/acpx/SKILL.md
---

# acpx model routing

The acpx skill's calling agent selects models from the machine's harness
catalogs and prefers a compatible native subagent. The routing helper validates
and caches those choices. External acpx execution uses guarded commands that
check the cached selection before starting an adapter.
[ADR 0056](../adr/0056-agent-selected-model-routing.md) replaces apply-time pins.

## Shortcut meaning

`agpt`, `aopus`, `afable`, and `agemini` select the strongest eligible model in
the named family. Their `p` counterparts select the most recent model in the
next lower capability tier. A lower version number is not necessarily less
intelligent; picker order and price are not capability rankings. No committed
model list or tier ranking determines these choices.

Unsuffixed names use the selected model's harness default thinking. Each `x`
advances one supported level above that default, retaining the same model.
The helper orders advertised supported levels using the effort vocabulary in
`acpx_models.toml`; unsupported increments reject. `agptw` aliases `pgpt`.
When the default is known, external launch sets it explicitly to avoid inheriting
an unrelated parent effort. Unknown defaults stay unknown: an unsuffixed external
launch may use the harness default, but modifiers require sourced default evidence.

The calling agent compares descriptions, capability metadata, and upgrade
information across eligible harnesses. It can consult current producer guidance
or [Artificial Analysis](https://artificialanalysis.ai) when needed. It records
a brief decision and evidence sources alongside the exact advertised candidate
IDs. Unresolved rankings and unavailable lower tiers reject explicitly.
The helper validates candidate membership and structural evidence; semantic
selection quality remains the calling agent's responsibility.

## Machine and access policy

`agent_clis` in [machines.toml](../../home/.chezmoidata/machines.toml) is the
single eligibility declaration. [Harness contracts](../../home/.chezmoidata/acpx_harnesses.toml)
map each selected agent to catalog and launch adapters. Installed executables
outside that list do not become eligible. There is no separate `acpx_routes`
allowlist or family-specific route ordering. Adding a selected agent without
an adapter contract makes no unsupported catalog claims.

Claude uses the existing Vertex route on work machines and subscription access
elsewhere. Cursor is included only where `cursor-agent` is selected. Pi queries
its authenticated model runtime and reports whether its actual credential uses
subscription access. Omp's OpenAI subscription provider (`openai-codex`) is
separated from its metered `openai` API provider.

Omp's Anthropic subscription classification remains incomplete. Its model JSON
does not expose the selected credential source, and its runtime can fall back
from OAuth to API credentials. The Anthropic route therefore still requires
`--allow-paid`, even for an OAuth-only account. Use the eligible Claude or Pi
subscription route when available. An Omp-only machine needs a producer-supported
credential-source query and an OAuth-only execution control before this route
can safely enter the default pool.

Included subscription/employer access and matching local inference are eligible
by default. API-only candidates, including OpenRouter, require explicit
`--allow-paid`. Stronger paid-only models do not displace included models by
default. Even in paid mode, equivalent models should use included access first.
The helper requires the same access mode for discovery, commit, inspection, and
execution; a paid-mode cache cannot silently serve a default request.
Catalog access does not prove inference entitlement, remaining quota, or that an
account has disabled subscription overage billing.

Local models preserve family: an unrelated open model cannot replace GPT or
Claude. Existing provider configuration and credentials remain externally owned.

## Discovery and execution

- Codex introspects its ACP catalog without sending a prompt. Descriptions are
  preserved, and the producer model cache under the active `CODEX_HOME` supplements per-model default
  thinking and capability notices. Default/priority picker placement is evidence
  about UI preference, not intelligence. Launch uses `CODEX_CONFIG` and clears
  ambient API/backend overrides. Credential metadata distinguishes ChatGPT
  subscription access from stored API keys; external launch rechecks that source.
- Claude uses the adapter's installed SDK for concrete model IDs, descriptions,
  aliases, and supported effort. Missing default effort can be established by
  the calling agent from version-matched configuration/docs and recorded with
  sources. Launch pins both the exact ID and its backing alias, preserves Vertex
  settings on work, and clears ambient API credentials for subscription routes.
  SDK account metadata distinguishes subscriptions, active API keys, and Vertex
  without recording account identity. External launch rechecks that access source
  in acpx's task directory with the adapter's user, project, and local settings.
- Cursor retains unqualified default variants, explicit effort variants,
  descriptions, and default markers. Existing generated plugin roots are passed
  through `--add-dir`; absent directories are omitted. Launch runs through
  `~/.agents/bin/cursor-acp` ([source](../../scripts/acpx/cursor-acp)), which
  marks `clientCapabilities._meta.parameterizedModelPicker` on `initialize`;
  without it Cursor serves the requested model but snaps thinking to its
  default. Each route gets its own `CURSOR_CONFIG_DIR` under
  `${XDG_STATE_HOME:-~/.local/state}/dotfiles/acpx/cursor/`; discovery lists
  models there too, so default markers describe the directory a launch uses.
  The shim refreshes the user's `cli-config.json` settings into it on every
  launch, leaves the model keys Cursor rewrites alone, and never copies
  `acp-config.json`, so a pick saved by another ACP client cannot override
  `--model`. Cursor's `session/new` reports the saved pick rather than the
  served model; the served model and thinking are in
  `acp-sessions/<id>/store.db`. Reports record a launch-contract version, so a
  selection cached before this change is re-made rather than executed.
  Evidence: [Cursor ACP model selection](../research/cursor-acp-model-selection.md).
- Omp refreshes its model catalog once per discovery and splits rows by configured
  provider contracts. Exact provider IDs are validated before candidates qualify.
- Pi's helper uses its installed `ModelRuntime`, read-only credential storage,
  and actual subscription classification. It reads cached catalogs with network
  refresh disabled and disables Pi telemetry. Its installed runtime supplies
  supported/default thinking. Pi has no installed ACP adapter, so these candidates
  require compatible native delegation.
- Gemini introspects `gemini --acp` where available. Discovery disables telemetry
  and traces and requires usage statistics already disabled in user settings.
  The included route requires an `oauth-personal` login and clears API-key
  overrides; metered Gemini providers remain available through paid API routes.
  Launch repeats the authentication/privacy checks and rejects conflicting
  workspace or system settings, including system defaults and untrusted workspace
  overrides, even where normal precedence would ignore the conflicting value.
  Missing advertised effort control rejects modifiers. A parent's model flag
  does not establish its native subagents' models.

Native capability is checked in the calling session, separately from machine
catalog discovery. The selected native tool must honor the exact model, effective
thinking, access source, and permissions. A fresh child with a task packet may be
needed when context inheritance prevents model overrides. Otherwise the skill
uses external acpx for the same request. Native-only selections without a matching
child fail clearly. Acpx session/flow requests remain external.
For native catalog choices the helper also checks eligible external catalogs for
the same model and effective thinking, recording `external_route` and
`external_model` when one exists. An included choice never gains a paid external
fallback. Missing default evidence prevents cross-harness thinking equivalence.

The [skill](../../agent-marketplace/packages/utils-agent/skills/acpx/SKILL.md)
owns invocation and write-authority rules; its
[selection reference](../../agent-marketplace/packages/utils-agent/skills/acpx/references/model-selection.md)
owns the calling agent's refresh procedure and selection JSON format.

## Cache and ownership

`chezmoi apply` runs `acpx-routing setup`, installing stable guarded entries in
`~/.acpx/config.json`. It does not discover models or launch inference to choose
them. Custom agents, credentials, and unrelated settings survive. Generated-name
ownership lives in `~/.acpx/routing-managed.json`; setup migrates ownership from
older routing reports. Name collisions, malformed configuration, and symlink
outputs reject before publication.

`refresh` saves a catalog snapshot to `~/.acpx/catalogs.json` without replacing
the last successful selection. The calling agent writes a selection file and
`commit` validates it against the snapshot before atomically saving
`~/.acpx/routing.json`. Cache identity includes machine, selected agents, provider
contracts, and shortcut rules. A configuration change immediately invalidates
both fresh and stale selections. Files created by the helper are private.

The TTL is 24 hours from discovery. A failed refresh preserves the successful
report. A partial catalog failure also blocks replacing a previously selected
model from the failed route; the same model from another route remains eligible.
After a temporary refresh failure, `show <shortcut> --allow-stale` can
return a selection up to seven days old, reporting its age. The skill must report
that age and preserve the flag in the guarded external command. Revoked access,
ambiguous new evidence, and model-launch failures do not authorize stale fallback,
model substitution, or paid access. Standalone shell commands consume the cache;
they never bootstrap a selection model.

## Inspect and validate

```sh
# Normally driven by the acpx skill; refresh sends no inference prompt.
~/.agents/bin/acpx-routing refresh
~/.agents/bin/acpx-routing resolve --selection /absolute/path/to/selection.json
~/.agents/bin/acpx-routing commit --selection /absolute/path/to/selection.json
~/.agents/bin/acpx-routing show agpt
acpx config show
```

`show <shortcut>` validates freshness and availability and returns the exact
model, default/effective effort, access, decision sources, `guard_argv`, and
shell-quoted `acpx_agent`. The returned guard also binds the inspected selection;
a concurrent model-selection change rejects before launch. `show` without a shortcut returns the diagnostic
report without authorizing a launch. `resolve` previews without publishing.
`--catalogs <file>` on refresh replays an offline catalog fixture.

```sh
just test-python -p test_acpx.py -p test_machines.py
just test-node tests/node/skill-rewrite.test.mjs
just -f agent-marketplace/justfile -d agent-marketplace check
just test-docs-lifecycle
git diff --check
```

The routing CLI tests retain adapter environment, provider, family, plugin-root,
ownership, idempotence, collision, and symlink guarantees. Old assertions fixing
particular generations, exact efforts, and first-route-only lookup were replaced
by caller-visible catalog selection, subscription gating, relative thinking,
snapshot validation, cache expiry, stale recovery, and guarded execution checks.
Offline tests establish these contracts, not model-quality rankings or live
cross-harness inference compatibility.
