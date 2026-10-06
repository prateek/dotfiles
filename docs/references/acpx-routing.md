---
status: current
doc_type: reference
created: 2026-09-22
updated: 2026-10-05
related:
  - ../adr/0032-acpx-model-routing.md
  - ../adr/0045-acpx-explicit-model-profiles.md
  - ../plans/acpx-routing-plan.md
  - ../../agent-marketplace/packages/utils-agent/skills/acpx/SKILL.md
---

# acpx model routing

Shortcuts select an explicit model profile and effort. Machine policy chooses
the ACP harness and provider. `chezmoi apply` resolves the provider's exact
advertised ID after tool installation and plugin materialization; invocation
uses that frozen selection. [ADR 0045](../adr/0045-acpx-explicit-model-profiles.md)
replaces the automatic latest/previous-generation selection in ADR 0032.

## Profiles

| Shortcut | Model target | Effort |
| --- | --- | --- |
| `agpt`, `agptw` | GPT-6.1 Sol | medium |
| `agptx` | GPT-6 Astra | medium |
| `agptxx`, `agptxxx` | GPT-6 Astra | high, xhigh |
| `pgpt`, `pgptx`, `pgptxx`, `pgptxxx` | GPT-6 Sol | medium, high, xhigh, max |
| `aopus`, `aopusx`, `aopusxx`, `aopusxxx` | Claude Opus 5.5 | medium, high, xhigh, max |
| `popus`, `popusx`, `popusxx`, `popusxxx` | Claude Opus 5 | medium, high, xhigh, max |
| `afable`, `afablex`, `afablexx`, `afablexxx` | Claude Fable 5.1 | medium, high, xhigh, max |
| `pfable`, `pfablex`, `pfablexx`, `pfablexxx` | Claude Fable 5 | medium, high, xhigh, max |
| `agemini`, `ageminix`, `ageminixx`, `ageminixxx` | Gemini 3.8 Flash | high, xhigh, max, ultra |
| `pgemini`, `pgeminix`, `pgeminixx`, `pgeminixxx` | Highest accessible Gemini generation below 3.8 | high, xhigh, max, ultra |

The prefixes identify the chosen current and previous profiles; a new catalog
release does not move the pinned targets. Each suffix names an explicit
profile, rather than advancing a universal effort ladder. In particular,
`agptx` changes model to Astra while keeping medium effort. `agptw` is the
preferred writing profile, shared with `agpt`.

Gemini's previous profiles are the exception: `previous_of = "agemini"`
selects the numerically highest generation below its pinned 3.8 target in the
preferred route's catalog, then the highest configured tier in that generation.
It does not require 3.8 itself to be advertised, and it never selects 3.8 or a
newer generation for the previous profile.

Missing models, missing preceding Gemini generations, and unsupported exact
efforts create explicit rejection commands. Effort support is checked on the
selected advertised ID; a profile never lowers effort or borrows a target from
a lower-priority route. Check `~/.agents/bin/acpx-routing show <shortcut>` before
delegating. It rejects unknown names; acpx itself can interpret an unknown name
as prompt text for its default agent.

Fast variants are excluded. Numeric generation, tier, and family matching
accepts provider prefixes, supported date snapshots, Claude's dot/hyphen
spelling, and context-window decorations. These forms do not add generations.
Launch retains the full advertised ID. Accepted formats and tier order are
explicit model data; unrecognized IDs are ineligible. Multiple matching IDs
are selected deterministically by their full ID, as before.

The preferred harness is selected before the model target: the first eligible
route with recognized models in the requested family wins. If Codex advertises
GPT-6 Sol but lacks GPT-6.1 Sol, `agpt` rejects even if OpenRouter advertises
6.1 Sol. A broken route or a catalog without that family permits selection
from another declared route; a missing target or effort inside the selected
route does not. Family-specific machine preferences can change that order.

## Why these defaults

Sol 6.1 medium is the everyday coding and writing profile; Astra medium is the
explicit escalation for difficult debugging, architecture, and review. OpenAI
positions Sol as a balance of intelligence and cost and Astra for demanding
work ([model catalog](https://developers.openai.com/api/docs/models)).
Opus 5.5 medium follows Anthropic's default; Fable 5.1 medium starts long-running
work with bounded reasoning cost ([Opus 5.5](https://www.anthropic.com/claude-opus-5-5),
[Fable 5.1](https://www.anthropic.com/claude-fable-and-mythos-5-1)).
Gemini 3.8 Flash high retains the alternative-provider research profile
([Google guidance](https://ai.google.dev/gemini-api/docs/latest-model)).
These are chosen defaults, not results of a local model-quality comparison.
Catalog discovery still determines availability on each machine.

## Inputs and ownership

| Source | Responsibility |
| --- | --- |
| [acpx_models.toml](../../home/.chezmoidata/acpx_models.toml) | Explicit profiles, family grammar, tier order, and recognized efforts |
| [acpx_harnesses.toml](../../home/.chezmoidata/acpx_harnesses.toml) | Supported families, dependencies, catalog adapter, provider, and environment for each route |
| [machines.toml](../../home/.chezmoidata/machines.toml) | Eligible routes in preference order; host and local overrides |
| [routing.json.tmpl](../../home/dot_config/acpx/routing.json.tmpl) | Renders the combined policy to `~/.config/acpx/routing.json` |
| [reconcile](../../scripts/acpx/reconcile) | Catalog discovery, resolution, and atomic file replacement; installs as `~/.agents/bin/acpx-routing` |
| [apply hook](../../home/.chezmoiscripts/run_after_38-acpx-routing.sh.tmpl) | Refreshes after the package, mise, and plugin hooks on every apply |

`agent_clis` controls which agent CLIs a machine gets
([ADR 0041](../adr/0041-agent-clis-single-declaration.md)); it does not enable
acpx routes. The two meet at render time: every declared route's harness must be
provided by a selected agent (`harness` in `home/.chezmoidata/agents.toml`), or
`routing.json.tmpl` fails the apply naming the route and the missing agent. A
`codex` declaration checks `codex-acp`, which has its own bundled Codex; a
`claude` declaration checks `claude-agent-acp` and Node, which provide the SDK
runtime. Vertex additionally requires `gcloud`. The presence of Cursor on PATH
never enables it on a non-work machine.

The reconciler owns its generated entries in `~/.acpx/config.json`, preserving
other agents, credentials, and top-level settings. It tracks generated names
in `~/.acpx/routing.json` to retire them on later applies. Existing legacy
shortcuts migrate in place. A new name colliding with an unrelated user agent
fails before either file changes. Malformed configuration and symlink targets
also fail before publication. The two JSON files are replaced individually;
the ownership ledger retains retired names so an interrupted publication can
be retried safely.

## Machine policy

Personal/homelab preference is:

1. Matching local inference through omp.
2. Codex and Claude Code subscription routes.
3. Direct OpenAI, Anthropic, and Cerebras API routes through omp.
4. OpenRouter through omp.

Work declares only Claude Code through Vertex/gcloud, then Cursor. Existing
Vertex project, region, and authentication settings remain externally managed.

Local preference preserves the requested family. An unrelated local open model
cannot replace GPT or Claude. Local provider IDs default to `local`, `ollama`,
and `lmstudio`; configure those providers' local endpoints in omp, or override
`acpx_local_providers` with the IDs of your configured local providers. This
change does not install an inference server, create credentials, or invent an
endpoint. Additional model families can be added to the model data.

All eligible routes are declared in `acpx_routes`, in preference order. A
host-local `[data.machines_local]` override can replace that list. Family-specific
`acpx_order_gpt`, `acpx_order_opus`, `acpx_order_fable`, or `acpx_order_gemini`
lists can narrow/reorder eligible routes, but cannot enable an undeclared route.

Broken declarations appear in the report and on stderr during apply. Selection
may use another declared route with an accessible catalog; an unresolvable
shortcut rejects at invocation. There is no runtime provider fallback.

## Catalog and launch contracts

- Codex discovery initializes the actual ACP adapter without prompting. Its
  advertised model/effort pairs exclude an unadvertised configured default.
  Launch sets exact `model`, `model_reasoning_effort`, and normal `service_tier`
  through `CODEX_CONFIG`. Ambient backend/config overrides are cleared so
  discovery and launch use the adapter's compatible bundled Codex.
  [Adapter contract](https://github.com/agentclientprotocol/codex-acp#runtime-options).
- Claude discovery uses the adapter's installed Agent SDK to read concrete
  `resolvedModel` IDs and supported effort levels. It sends no user prompt.
  Launch sets `ANTHROPIC_MODEL`, `CLAUDE_CODE_EFFORT_LEVEL`, and disables fast
  mode. It also pins the matching `ANTHROPIC_DEFAULT_OPUS_MODEL` or
  `ANTHROPIC_DEFAULT_FABLE_MODEL`, because the adapter may normalize the exact
  model back to its alias. Vertex adds `CLAUDE_CODE_USE_VERTEX=1`. Subscription
  routes clear ambient API-key and third-party-provider environment overrides.
  Existing user settings still apply.
  [Claude adapter](https://github.com/agentclientprotocol/claude-agent-acp),
  [alias pinning](https://code.claude.com/docs/en/model-config#environment-variables),
  [fast-mode control](https://code.claude.com/docs/en/fast-mode).
- omp's fresh JSON catalog is queried once per refresh and split by explicitly
  declared provider IDs. Launch uses `omp acp --provider ... --model ... --thinking ...`.
  [ACP implementation](https://github.com/can1357/oh-my-pi/tree/v18.2.6/packages/coding-agent/src/modes/acp).
- Cursor discovery reads `--list-models`. It accepts explicit non-fast effort
  variants (`-high`, `-xhigh`, etc.) and parameterized IDs with advertised effort.
  Unqualified IDs do not establish high-effort support. Existing plugin roots
  are passed through `--add-dir`; absent roots are omitted.

Catalog introspection does not prove inference access, account billing source,
or permission enforcement. The acpx skill retains the per-run model check and
tool-call audit. Work's Vertex access and local endpoints require checks on
their owning machines.

## Inspect and validate

```sh
acpx config show
~/.agents/bin/acpx-routing show agpt
~/.agents/bin/acpx-routing show
```

`show <shortcut>` fails for an unavailable or unknown request. The full report
includes catalog snapshots and route diagnostics. `resolve` reads catalogs and
prints a proposed report without publishing. `--catalogs <file>` replays a
captured catalog object for offline inspection. Normal use refreshes through
`chezmoi apply`; `run_install_scripts=false` and `--exclude=scripts` skip refresh.

```sh
just test-python -p test_acpx.py -p test_crit.py -p test_machines.py
just -f agent-marketplace/justfile -d agent-marketplace check
just test-docs-lifecycle
git diff --check
```

The former template and pin-drift Bats checks are replaced by the reconciliation
CLI checks: exact adapter configuration, model/effort selection, catalog change,
exclusions, plugin-directory validity, and machine gates remain covered. Pin
extraction is retired because profile targets live in model data rather than
launch templates. Checks cover ownership/preservation, repeatability,
local-family constraints, and diagnostics.
