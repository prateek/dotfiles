---
status: proposed
doc_type: plan
owner: Prateek
created: 2026-10-02
updated: 2026-10-02
related:
  - ../research/hermes-agent-field-guide.md
  - ../adr/0041-agent-clis-single-declaration.md
status_detail: "Proposed: install Hermes Agent on personal-mbp, m4mini, and (after an XDR smoke test) work-mbp, CLI-only against a local model, with policy in a chezmoi-owned managed-scope dir. Nothing implemented."
---

# Hermes Agent Plan

Add [Hermes Agent](https://github.com/NousResearch/hermes-agent) as an
`agent_clis` entry. Facts behind every step are in the
[field guide](../research/hermes-agent-field-guide.md), pinned to
`bed0d535`.

## Decisions

- **Machines:** personal-mbp, m4mini, and work-mbp. work-mbp joins only after
  the smoke test in step 5 passes.
- **Gateway:** none for now. No `hermes gateway install`, no messaging
  platforms, no cron. Cron runs only inside a live gateway, so scheduled jobs
  wait for a later decision.
- **Provider:** local model through an OpenAI-compatible endpoint
  (`provider: custom` plus `model.base_url`). No API keys in the first pass.
- **Config ownership:** Hermes managed scope. chezmoi renders a policy
  `config.yaml` that wins per key. Hermes keeps owning `~/.hermes/` in full.

## Design

### 1. Catalogue entry

Add to `home/.chezmoidata/agents.toml`:

```toml
[agents.hermes]
binary = "hermes"
install = "native-hook"                     # run_after_07-hermes
config_paths = [".config/hermes-managed"]
```

Leave out `orca`, `plugins`, and `harness`. Orca's agent id for Hermes is
unverified, Hermes reads skills through `external_dirs` instead of rendered
plugins, and an acpx route is out of scope (step 7). `config_paths` lists
only the managed dir. chezmoi never manages anything under `~/.hermes`.

### 2. Install hook

Add `home/.chezmoiscripts/run_after_07-hermes.sh.tmpl`, shaped like the
`run_after_07-cursor-agent` hook. It should:

- Skip when `hermes --version` already succeeds. Updates come from a manual
  `hermes update`, never from apply, because upstream ships patch releases
  every few days and v0.21.2 fixed `state.db` regressions.
- Otherwise download `install.sh` and run it with
  `--commit <pinned sha> --non-interactive --skip-browser --skip-computer-use`
  under the narrowed `PATH` the cursor hook uses. The pin lives in the hook,
  next to a comment saying where it came from.
- After installing, remove the `PATH` line the installer appends to
  `$HOME/.zprofile`. zsh never reads that file under `ZDOTDIR`, but it is
  drift, and `zprofile` already puts `~/.local/bin` first.

mise, pipx/uv, and Homebrew are all out. Releases carry no assets, the PyPI
package is six minors stale, `setup.py` refuses wheel builds outside Nix,
and upstream calls brew unsupported.

### 3. Managed scope

- Source: `home/dot_config/hermes-managed/readonly_config.yaml`. chezmoi
  renders it read-only, and v1 managed scope enforces only through file
  permissions.
- Export `HERMES_MANAGED_DIR="$HOME/.config/hermes-managed"` from
  `home/dot_config/zsh/dot_zshenv.tmpl`, gated on `hermes` being in
  `agent_clis`. It has to reach agent tool-shells and acpx children too, and
  Hermes reads it from the environment only, never from a `.env`.
- `/etc/hermes` is out: the work Mac has no sudo outside a Jamf grant.

Policy keys:

| Key | Value | Why |
| --- | --- | --- |
| `model.provider` / `model.base_url` / `model.default` | `custom`, local endpoint, model id | Decision: local provider. |
| `auth.adopt_external_logins` | `false` | The default adopts Claude Code's and Codex's OAuth logins and rotates their refresh tokens, which logs those CLIs out. |
| `skills.external_dirs` | `[~/.agents/plugins]` | One recursive walk finds every published skill. |
| `skills.write_approval` | `true` | Hermes can edit external skills in place, and those files are apply-owned. |
| approvals mode | `manual` | The default `smart` lets an auxiliary model approve commands. |

Keep list-valued keys Hermes appends to, such as `command_allowlist`, out of
the managed file. A managed list replaces the user's list whole, which would
erase every "allow always" answer.

### 4. Local model runtime

Hermes needs an OpenAI-compatible server. Add Ollama to the `ai-agent-apps`
package group, or use Hermes Desktop's one-click local setup. Pick the model
id per machine once each machine's RAM is known, and template
`model.default` from machine data if they differ.

### 5. Work Mac gate

Cortex XDR's BIOC kills omp's whole causality group on the work Mac, and
Hermes' process tree (a PM-provisioned Python 3.14) is untested there.
Before adding `hermes` to the work machine type:

1. In a throwaway Terminal.app window (not Orca), run the pinned installer
   by hand with the same flags, then `hermes --version` and one chat turn
   against the local model.
2. Check that the terminal survived. If it died, read the root-only
   `trapsd` logs for a `terminate_causality` with a matching BIOC.
3. Confirm TLS works under inspection. Local inference is loopback, but the
   update check, the model catalog fetch, and PyPI lazy installs go out
   through the PANW proxy. They need the work shells' CA bundle.

If XDR kills it, record that next to the omp comment in `machines.toml`
and leave work-mbp out.

### 6. Instructions and identity

Hermes has no machine-wide instructions slot. Inside a repo it loads
`AGENTS.md` (git root down to cwd), so repo guidance already works.
`~/.agents/AGENTS.md` is not loaded. Its only global file is `SOUL.md`, the
persona prompt, so leave `SOUL.md` at its default rather than symlinking
machine conventions into it.

### 7. Deferred

- Gateway and messaging platforms (decision: none yet).
- acpx custom-agent route through `hermes acp`, which does send real
  `session/request_permission`.
- Orca agent id.
- Hosted providers and `op://` secrets through Hermes' native
  `secrets.onepassword`.

## Rollout

1. personal-mbp: catalogue entry, hook, managed scope, and Ollama, then
   `chezmoi apply`.
2. Verify on personal-mbp:
   - `hermes config` shows the managed keys as locked.
   - `hermes config set auth.adopt_external_logins true` is refused.
   - A skill from `~/.agents/plugins` is listed.
   - `claude` and `codex` stay signed in after a Hermes session.
3. m4mini: add to the homelab type and apply.
4. work-mbp: step 5, then add to the work type only if it passes.

## Validation

- Render the hook and zshenv for each machine type with
  `chezmoi execute-template`. Confirm the gate and that `HERMES_MANAGED_DIR`
  is set in both zsh startup paths, per the AGENTS.md env-var check.
- Run the existing `agent_clis` catalogue tests (see `tests/README.md`).
  The `features.tmpl` refusal of unknown ids is the guarantee worth keeping.
- `just test-docs-lifecycle` and `git diff --check`.

## Open Questions

- Does managed scope behave with the dir under `$HOME` on macOS? The design
  doc calls v1 "Linux/POSIX-first". Rollout step 2 answers this.
- Does `~` expand inside managed `skills.external_dirs`, or does it need an
  absolute, templated path?
- Does Claude-only skill frontmatter (`allowed-tools`,
  `disable-model-invocation`) parse cleanly in Hermes?
- Which local model fits each machine?
