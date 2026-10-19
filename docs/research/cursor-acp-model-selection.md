---
status: active
doc_type: research
summary: "How cursor-agent picks the served model and thinking under ACP, why acpx launches lost the requested effort, and the shim and config isolation that fix it."
owner: Prateek
created: 2026-10-19
updated: 2026-10-19
related:
  - ../references/acpx-routing.md
  - ../../agent-marketplace/packages/utils-agent/skills/acpx/SKILL.md
status_detail: "Live probes on cursor-agent 2026.07.01 and acpx 0.19.5 (2026-10-16); bundle offsets refer to that version."
---

# Cursor ACP model selection

## Question

Does `cursor-agent --model <id> acp`, as the acpx reconciler launches it, serve
that model at the requested thinking level? An earlier note claimed `--model`
was ignored and the session ran whatever `acp-config.json` had saved.

## Findings

Three separate mechanisms were conflated:

1. **`--model` is honoured.** The root option reaches `runAcp` and seeds the
   model manager (`initialModel`), which matches legacy slugs
   (`claude-opus-5-5-high`) and bracketed IDs alike and writes the pick into
   `cli-config.json` as a side effect.
2. **The session report lies.** `session/new` builds `models.currentModelId`
   from the persisted `acp-config.json` `selectedModelVariantId` when that
   value is still advertised, and only then from `--model`. With
   `gpt-5.6-sol[...]` saved, every session reported gpt-5.6-sol regardless of
   what was served. The served model is recorded per session in
   `<CURSOR_CONFIG_DIR>/acp-sessions/<id>/store.db` as
   `systemPromptFingerprint.model`, with the effort in the slug.
3. **Effort was snapped to the default.** acpx never sends
   `clientCapabilities._meta.parameterizedModelPicker`, so Cursor runs its
   "variants" picker: the server returns one preset per model, the requested
   effort is sanitised against that list ("Invalid parameter combination …
   falling back to default variant"), and the request goes out at medium.
   Config-dir isolation alone does not change this.

acpx's own `--model` sends `session/set_model`, which persists the pick into
`acp-config.json` and `cli-config.json`, moves every open session in that
process, and in parameterized mode overrides a later launch's `--model` once
before clearing itself.

`CURSOR_CONFIG_DIR` (precedence: that variable, then `$XDG_CONFIG_HOME/cursor`,
then `~/.cursor`) scopes `acp-config.json`, `cli-config.json`, `acp-sessions/`,
and the statsig cache. Credentials live elsewhere: an empty directory still
authenticated through the shared worker.

| Probe | Launch | Reported | Served (store fingerprint) |
| --- | --- | --- | --- |
| Real dir, `--model claude-opus-5-5-medium` | variants | gpt-5.6-sol | claude-opus-5-5-medium |
| Real dir, production argv `--model claude-opus-5-5-high … acp` | variants | gpt-5.6-sol | claude-opus-5-5-**medium** |
| Empty `CURSOR_CONFIG_DIR`, `--model claude-opus-5-5-high` | variants | claude-opus-5-5 medium | medium |
| Isolated dir, `_meta` set, `--model claude-opus-5-5-high` | parameterized | claude-opus-5-5, effort high | — |
| acpx `--agent "<shim> cursor-agent --model claude-opus-5-5-high acp"` | parameterized | — | claude-opus-5-5-high |
| Isolated dir with a saved pick, `_meta` set | parameterized | saved pick (hijacked), file cleared | — |

Cursor's headless mode (`-p`) exposed no subagent tool in a live run, so there
is no native-delegation path for Cursor selections on this version.

## Fix

`scripts/acpx/cursor-acp` (installed as `~/.agents/bin/cursor-acp`) is a stdio
pass-through that sets the `_meta` flag on `initialize`. The reconciler
launches Cursor routes through it with a per-route
`CURSOR_CONFIG_DIR=${XDG_STATE_HOME:-~/.local/state}/dotfiles/acpx/cursor/<route>`,
which discovery shares. On every launch the shim refreshes the user's
`cli-config.json` settings into that directory so permissions, sandbox, and
HTTP/1 changes carry over, leaves the model keys Cursor rewrites per run
alone, and never copies `acp-config.json`.

## Limits

- Concurrent runs on the same route still share one `cli-config.json`; keep
  Cursor fan-out small, as before.
- The flag belongs in acpx. Letting `--agent` runs set `clientCapabilities._meta`
  upstream would retire the shim.
- Verify a Cursor run from the store fingerprint, not from `session/new` or
  the model's self-report, which never includes effort.
