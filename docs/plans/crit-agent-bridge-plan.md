---
status: active
doc_type: plan
owner: Prateek
created: 2026-07-03
updated: 2026-07-03
related:
  - ./crit-integration-plan.md
  - ../adr/0013-apm-vendored-tool-integrations.md
status_detail: "Implemented and tested (tests/crit-config-modify.zsh; ci/personal render clean; crit reply-post + acpx reply-only flags proven live). Bridge and acpx config both derive from the machines.toml agent_clis overlay; wrapper is templated; agpt rides cursor-agent on work and the Codex adapter on personal. Remaining: a successful live generation + apply post-merge."
---

# Crit Agent Bridge Plan

Wire crit's `agent_cmd` hook to acpx so a review comment can be dispatched to
another model for a suggested reply. Today the two tools run in isolation; this
bridge gives acpx a recurring job and puts a second model in the review loop.

## Evidence

An agentsview audit of the local session store backs the case for building this:

- crit is used heavily, and its use is growing.
- acpx is idle. Only a handful of real `exec` calls exist across the window, and
  the model-pinned shortcuts are almost never invoked.
- The crit review loop is single-model. Comment replies come from the same
  in-session agent that wrote the code, so no second model participates.
- The `agent_cmd` bridge has never been used. The store holds zero real
  dispatches.

## Decisions

- **Reply-only posture.** The dispatched agent reads the repo for context and
  posts a suggested reply. It does not edit the working tree; the human, or the
  original in-session agent at Finish Review, applies changes. Edit-capable is a
  one-flag toggle (see [Who addresses a comment](#who-addresses-a-comment)).
- **Model chosen by a resolution policy** so the bridge can vary by machine and
  contrast with the reviewing model (see [Model resolution](#model-resolution)).
  The default is `agpt`.

## Mechanism

crit's `agent_cmd` hook works as follows (`internal/server/server.go`):

- crit's web UI has a per-comment "send to agent" button. It calls
  `POST /api/agent/request`, and `buildAgentPrompt` assembles a self-contained
  prompt: file, line range, quoted code, comment body, prior replies, plus an
  instruction to address the comment, make the edit if needed, and print the
  reply to stdout.
- crit runs `agent_cmd` with `cwd` = repo root, a 10-minute timeout, and
  whitespace splitting (no shell). A standalone `{prompt}` token is replaced with
  the built prompt as a single argv entry; without the token, crit pipes the
  prompt on stdin. crit captures stdout and posts it back as a reply.
- `agent_cmd` is global-only: it lives in `~/.crit.config.json`, and project
  config cannot override it.

Reply-only is enforced by the wrapper's flags, not by acpx defaults. acpx's
default `approve-reads` mode auto-approves reads (good for context) but *prompts*
on writes. In crit's non-TTY daemon subprocess there is no one to answer that
prompt, so an unguarded write would hang to the 10-minute timeout. Passing
`--no-terminal` and `--non-interactive-permissions deny` turns the unanswerable
write prompt into a clean denial: reads still go through, writes are refused
immediately.

## Who addresses a comment

Two distinct paths exist; the bridge is the first one.

1. **Mid-review "send to agent" button → a fresh `agent_cmd` subprocess.** crit
   spawns our wrapper as a new acpx agent, captures its stdout, and posts it back
   as a reply. This does not route to the original agent that launched crit; that
   agent is blocked on the `crit` CLI and never sees the request. Because the
   dispatched agent is a separate process, it can run a different model from the
   one under review. That contrast is the reason to build the bridge.

2. **After Finish Review → the original in-session agent.** The launching agent
   (for example, the Claude Code session running the crit skill) reads the
   unresolved comments from stdout and addresses them via `crit comment
   --reply-to`, editing files itself. This is the existing loop, unchanged.

Path 1 can edit files: it is a separate subprocess with `cwd` = repo root, so
whether it writes is a wrapper flag. We keep it off so paths 1 and 2 never write
to the tree concurrently. crit live-reloads, so a mid-review edit would race the
original agent's later edits. Suggested reply in; human or original agent applies
out.

## Model resolution

crit's UI has no model picker. The dispatch is a single "send to agent" button,
and its API carries only `{comment_id, file_path}`, so the wrapper decides the
model. Order, first match wins:

1. **`CRIT_AGENT_MODEL` env.** An explicit host-local override (from `.envrc` or
   mise) naming any acpx shortcut.
2. **Launcher-aware contrast.** Branch on who started the crit daemon to pick a
   model unlike the reviewer: dispatch to GPT when Claude launched the review, and
   to Claude when a non-Claude agent did. The GPT- and Claude-family targets are
   whichever this machine's CLIs support. The GPT target is `agpt` (via
   `cursor-agent`, or the Codex adapter where absent); the Claude target is
   `aopus` with `cursor-agent`, else `afable`. The dispatched `agent_cmd` subprocess inherits the
   launcher's environment (`CLAUDECODE=1`, `AI_AGENT=claude-code_*`) with `cwd` =
   repo root, which gives the wrapper the signal it needs.
3. **Machine default from the features overlay.** The GPT-family target above,
   baked into the wrapper at chezmoi apply time from `machines.toml` `agent_clis`
   (resolved by `features.tmpl`): `agpt` in every case, riding `cursor-agent` or
   the Codex adapter as available. A machine with no agent CLIs cannot dispatch,
   so the wrapper exits with a clear message rather than failing to spawn.

Two caveats on the launcher signal, both permanent:

- The environment is frozen at *daemon start* and belongs to whoever started the
  daemon. crit auto-connects to an already-running daemon, so a shared or
  reconnected daemon carries the original starter's signal, not the current
  driver's. That is fine for the common case (one session starts and drives) and
  worth noting otherwise.
- `AI_AGENT` (`claude-code`, `codex`, etc.) is the clean discriminator, but Orca
  injects it and it is absent outside Orca. `CLAUDECODE` is the portable
  Claude-family signal (afable sets it too, but afable *is* Claude, so the GPT
  contrast still holds). `CODEX_HOME` is ambient (set even inside a Claude
  session), so it cannot serve as a launcher signal.

Every tier resolves from data we control: env we author and chezmoi-templated
config. We deliberately do not read a committed repo file to choose the model.
crit keeps `agent_cmd` global-only precisely so an untrusted repo cannot hijack
the dispatched agent, and a committed `.crit-agent-model` would reopen that hole.

## Changes

1. **A shared `agent_clis` feature drives both configs.** Add `agent_clis` (the
   ACP-backed agent CLIs present) to each machine layer in
   `home/.chezmoidata/machines.toml`, resolved by `features.tmpl`. Promote
   `home/dot_acpx/config.json` to `config.json.tmpl` and emit only the shortcuts
   whose backing CLI is listed (`cursor-agent` → `agpt*`/`aopus*`/`agemini`;
   `claude` → `afable*`; the `agpt*` GPT tiers fall back to the Codex adapter
   where `cursor-agent` is absent), so a machine lists no shortcut it can't run.
   The crit
   bridge reads the same overlay (change 2), so the two configs stay orthogonal:
   the bridge adds nothing to the acpx config.

2. **Wrapper `~/.local/bin/crit-agent`**, a chezmoi template
   (`home/dot_local/bin/executable_crit-agent.tmpl`) that bakes the machine's GPT-
   and Claude-family targets from `agent_clis` at apply time, so it names a
   runnable agent without depending on the acpx config:

   ```sh
   #!/usr/bin/env bash
   # Reply-only: --no-terminal + --non-interactive-permissions deny refuse writes.
   set -euo pipefail
   # chezmoi resolves $gpt / $claude / $default from agent_clis here.

   model="${CRIT_AGENT_MODEL:-}"
   if [[ -z "$model" ]]; then
     case "${AI_AGENT:-}" in
       codex_*|cursor_*) model="{{ $claude }}" ;;   # non-Claude reviewer -> Claude
       claude-code_*)    model="{{ $gpt }}" ;;      # Claude reviewer     -> GPT
     esac
     [[ -z "$model" && "${CLAUDECODE:-}" == "1" ]] && model="{{ $gpt }}"
   fi
   model="${model:-{{ $default }}}"
   [[ -n "$model" ]] || { echo "crit-agent: no acpx agent CLI available" >&2; exit 1; }

   exec acpx --format quiet --no-terminal --non-interactive-permissions deny \
     "$model" exec "$1"
   ```

3. **`~/.crit.config.json` via a `modify_` merge script.** crit writes that file
   itself (`auth_token`, `share_consented`, `auth_user_*`, `live_cookie`), so a
   fully managed file would clobber crit's writes on every apply. Set only
   `agent_cmd` and round-trip everything else verbatim, following the JSON
   `modify_` pattern already shipped at
   `home/Library/Application Support/Yojam/modify_config.json.tmpl` (Python's
   `json`, which preserves insertion order). Because `~/.crit.config.json` holds
   the `auth_token` secret, the source carries the `private_` (0600) attribute:
   `home/modify_private_dot_crit.config.json.tmpl`. The desired value:

   ```json
   { "agent_cmd": "crit-agent {prompt}" }
   ```

   crit whitespace-splits this and substitutes `{prompt}` as one argv entry →
   `crit-agent "<full prompt>"` → `$1` in the wrapper.

4. **Test** (parallel to `tests/orca-settings-modify.zsh` and the other
   `*-config-modify` tests). Assert: the modify script sets `agent_cmd` and
   round-trips a pre-seeded `auth_token`/`share_consented` byte-for-byte; the acpx
   config emits the right shortcuts per machine (work → all seven, personal →
   `afable*` only, ci → none); the templated wrapper resolves per machine
   (`CRIT_AGENT_MODEL` wins; on work `AI_AGENT=codex_*`→`aopus`, Claude
   launcher→`agpt`; on personal →`afable`/`codex`) and carries the reply-only
   flags; and a machine with no CLIs fails closed. Wire into the `Makefile` and
   `tests/README.md`.

5. **Doc**: a short section in
   [home/dot_agents/docs/acpx.md](../../home/dot_agents/docs/acpx.md) covering
   what "send to agent" does, the reply-only posture, and model resolution.

6. **Live smoke**: `chezmoi apply`, run a crit review in a scratch repo, click
   "send to agent" on a comment, and confirm the reply posts back with no file
   edited.

## Failure modes and rollback

crit's `runAgentCmd` posts a reply only on a successful exit with non-empty
stdout. On a non-zero exit or empty stdout it logs the outcome and posts nothing,
so a failed dispatch produces no reply rather than a broken one. `--format quiet`
holds acpx's stdout to the final answer, so the posted reply is the agent's
response and nothing else.

Rollback: remove `agent_cmd` from `~/.crit.config.json` via the same `modify_`
script. With `agent_cmd` unset, crit's "send to agent" endpoint returns
`agent_cmd not configured` and the bridge is inert.

## Open questions to resolve during build

- Confirm `~/.local/bin` is on the crit daemon's inherited PATH in this setup.

## Out of scope

- The `--author 'Claude'` vs `'Claude Code'` drift (upstream-vendored skill
  territory; cosmetic).
- Broader acpx shortcut adoption; this bridge is a step toward it.
