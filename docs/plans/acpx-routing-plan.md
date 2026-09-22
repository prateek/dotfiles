---
status: accepted
doc_type: plan
created: 2026-09-22
updated: 2026-09-22
status_detail: "Implemented and locally validated; not applied to the host. Work-machine and inference validation remain deployment checks."
current_guidance: ../references/acpx-routing.md
related:
  - ../adr/0032-acpx-model-routing.md
---

# acpx model routing

Separate model intent, ACP harness capabilities, and machine access policy.
The accepted naming is `a` for latest and `p` for previous generation. Both
start at high effort; each `x` advances one supported effort level. `agptw`
selects the preceding GPT generation's smallest tier at high effort. Fast
variants are excluded. Unsupported requests fail rather than changing family,
generation, or effort.

Declarations determine eligibility; finding an executable does not enable it.
Prefer matching local inference, native subscriptions, direct APIs, then
aggregators. Work declares Claude Code through Vertex/gcloud and Cursor only.
Personal and homelab declare local, Codex, Claude Code, OpenAI, Anthropic,
Cerebras, and OpenRouter; Cursor is excluded. Choose the preferred harness
first, then resolve generations within its catalog at chezmoi apply time.

## Work

- [x] Record the architecture and current adapter contracts.
- [x] Add separate model and harness inputs plus machine declarations.
- [x] Resolve and validate catalogs after dependencies install; publish acpx
  launch commands and a readable resolution report without embedding secrets.
- [x] Replace hardcoded shortcuts and the pin-drift audit; update skill guidance.
- [x] Verify generation/tier/effort selection, policy exclusions, failures,
  configuration ownership, and repeated apply through public command seams.

## Regressions fixed

The current template passes `-c model_reasoning_effort=...` to codex-acp 1.6.2.
Its ACP startup ignores these arguments and reads `CODEX_CONFIG` JSON instead.
The adapter runs its own bundled Codex unless `CODEX_PATH` overrides it.
Catalog and launch validation must therefore use the same adapter backend.

Claude's adapter can normalize an exact Opus model ID to its moving alias.
Launch also pins the corresponding default-model environment variable. A
prompt-free SDK check resolved that alias to both the current and an older
explicit pin, confirming that it does not always return the current default.

Both defects had failing regression assertions before their fixes.

## Validation boundary

Use the existing rendered-config test seam and the reconciliation CLI with
external catalog/ACP processes substituted. Add prompt-free live discovery
against installed adapters. Tests do not prove model inference, work-machine
Vertex access, or an unconfigured local endpoint.

## Results

- All 24 focused routing, crit, and machine-policy tests passed. They cover
  repeated publication and preservation of unrelated configuration.
- Package validation passed 37 checks and reproduced the plugin build.
- Documentation validation and CI/personal/work chezmoi apply previews passed.
  The rendered hook passed shellcheck; the SDK helper passed Node syntax checks.
- The installed acpx accepted the generated `argv` configuration. Prompt-free
  native ACP sessions confirmed GPT high/xhigh with fast mode off, and Claude
  high effort with the alias backing pinned.
- This host's adapter catalogs resolved `agpt` to `gpt-5.6-sol`, `pgpt` and
  `agptw` to `gpt-5.5`, and `aopus` to `claude-opus-5[1m]`. These are observed
  results, not committed pins. Local/OpenAI/Anthropic/Cerebras routes reported
  no accessible models; Cursor remained excluded from the personal policy.

No user prompts were submitted. The source changes have not been applied to
the host, and work-machine Vertex/Cursor access remains unverified.
