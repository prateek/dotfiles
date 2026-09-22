---
status: current
doc_type: reference
created: 2026-09-22
updated: 2026-09-22
related:
  - ../adr/0032-acpx-model-routing.md
  - ../plans/acpx-routing-plan.md
  - ../../agent-marketplace/packages/utils-agent/skills/acpx/SKILL.md
---

# acpx model routing

Model shortcuts select a family, generation, and effort. Machine policy chooses
the ACP harness and provider. `chezmoi apply` resolves exact IDs after tool
installation and plugin materialization; invocation uses that frozen selection.

## Names

| Name | Selection |
| --- | --- |
| `agpt` | Latest GPT generation, highest configured tier, high effort |
| `pgpt` | Preceding GPT generation, highest configured tier, high effort |
| `agptx`, `agptxx`, `agptxxx` | Latest GPT, one/two/three supported effort steps above high |
| `pgptx`, `pgptxx`, `pgptxxx` | Same effort progression for the preceding generation |
| `agptw` | Preceding GPT generation, smallest available tier, high effort |
| `aopus`, `popus` | Latest/preceding Opus; the same `x` suffixes apply |
| `afable`, `pfable` | Latest/preceding Fable; the same `x` suffixes apply |
| `agemini`, `pgemini` | Latest/preceding Gemini; the same `x` suffixes apply |

Each `x` follows the selected model's supported ladder. If a model advertises
`high, max`, its first step is `max`. Missing high effort, a missing preceding
generation, and effort overflow create explicit rejection commands. They do not
borrow a generation from a lower-priority route or reduce effort.
Check `~/.agents/bin/acpx-routing show <shortcut>` before delegating. It also
rejects unknown names; acpx itself can interpret an unknown name as prompt text
for its default agent.

Fast variants are excluded. Generation comparison is numeric; model snapshots
and context-window decorations do not count as extra generations. Tier order
and accepted ID formats are explicit model data. Extend that data when providers
introduce a new naming convention; unrecognized IDs are not eligible.

The preferred harness is selected before generation: an older model in Codex's
catalog wins over a newer model in OpenRouter's catalog when Codex is preferred.
If Claude's catalog contains only current Opus/Fable, their `p` shortcuts reject.
If the preceding GPT generation has one tier, `pgpt` and `agptw` select it.

## Inputs and ownership

| Source | Responsibility |
| --- | --- |
| [acpx_models.toml](../../home/.chezmoidata/acpx_models.toml) | Families, generation grammar, tier order, effort ladder, naming |
| [acpx_harnesses.toml](../../home/.chezmoidata/acpx_harnesses.toml) | Supported families, dependencies, catalog adapter, provider, and environment for each route |
| [machines.toml](../../home/.chezmoidata/machines.toml) | Eligible routes in preference order; host and local overrides |
| [routing.json.tmpl](../../home/dot_config/acpx/routing.json.tmpl) | Renders the combined policy to `~/.config/acpx/routing.json` |
| [reconcile](../../scripts/acpx/reconcile) | Catalog discovery, resolution, and atomic file replacement; installs as `~/.agents/bin/acpx-routing` |
| [apply hook](../../home/.chezmoiscripts/run_after_38-acpx-routing.sh.tmpl) | Refreshes after the package, mise, and plugin hooks on every apply |

`agent_clis` continues to control installation/plugin activation. It does not
enable acpx routes. A `codex` declaration checks `codex-acp`, which has its own
bundled Codex; a `claude` declaration checks `claude-agent-acp` and Node, which
provide the SDK runtime. Vertex additionally requires `gcloud`. The presence
of Cursor on PATH never enables it on a non-work machine.

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
extraction is retired because there are no hardcoded pins. New checks cover
ownership/preservation, repeatability, local-family constraints, and diagnostics.
