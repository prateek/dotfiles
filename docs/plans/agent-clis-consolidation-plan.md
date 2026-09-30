---
status: active
doc_type: plan
owner: Prateek
created: 2026-09-30
updated: 2026-09-30
related:
  - ../adr/0041-agent-clis-single-declaration.md
  - ../adr/0012-config-gating-convention.md
  - ../adr/0020-apply-reconciles-plugin-installs.md
  - ../adr/0027-codex-standalone-installer.md
  - ../adr/0029-claude-code-native-installer.md
  - ../adr/0032-acpx-model-routing.md
  - orca-settings-store-plan.md
status_detail: "Catalogue, resolver, install surfaces, consumers, and tests implemented in source 2026-09-30; live applies (work, devbox, personal, homelab) pending."
---

# agent_clis consolidation

Make `agent_clis` in `home/.chezmoidata/machines.toml` the one per-machine
declaration of which AI agent CLIs a machine gets, and derive every install,
config gate, and consumer from it. The Orca settings work
([plan](orca-settings-store-plan.md)) is the first consumer that needs this.

## Why

Audit on 2026-09-30 (live on work-mbp, declarations for the rest):

| CLI | installed by | gated on | machines today | keyed off it |
| --- | --- | --- | --- | --- |
| `claude` | `run_after_06-claude-native` (ADR 0029) | `agent_clis` | personal, homelab, work, devbox | plugin hooks 36/39, crit `agent_cmd`, Orca |
| `codex` | `run_after_07-codex-standalone` (ADR 0027) | package group `codex` | personal, homelab | `codex-acp` formula (same group), `.codex` ignore gate, plugin hooks, acpx `codex` route, Orca |
| `cursor-agent` | nothing in the repo; installed by hand from `cursor.com/install` | declared in `agent_clis` only | work, devbox declared | `.cursor/cli-config.json` gate, acpx `cursor` route, hook 39 fails if absent, Orca |
| `omp` | mise `conf.d/clis.toml` | none | every machine, including work where Cortex XDR terminates it | plugin hooks when listed, five acpx routes, Orca |
| `pi` | mise `conf.d/clis.toml` | none | every machine | `~/.pi/agent/settings.json` modify (ungated), Orca |
| `gemini` | mise `conf.d/clis.toml` | none | every machine | `bin/gemini-meeting-sync`, Orca |
| `claude-agent-acp` | mise | none | every machine | acpx `claude` and `claude-vertex` routes |
| `codex-acp` | brew, group `codex` | package group | personal, homelab | acpx `codex` route |

Three different gates for three CLIs, three CLIs with no gate at all, one
declared CLI that nothing installs, and no validation of `agent_clis` itself
(a typo silently does nothing). Orca's agent picker shows the union of whatever
landed: on work that is `claude, cursor-agent, omp, pi, gemini`.

## Decisions

- `agent_clis` is the complete list of agent CLIs a machine gets, including the
  mise-installed ones. It is validated against a catalogue; an unknown id fails
  the render the same way an unknown machine type does.
- A catalogue at `home/.chezmoidata/agents.toml` records, per id, the binary,
  the install mechanism, adapters it brings, config paths to gate, the Orca
  TUI agent id, whether it takes plugins, and the acpx harness it satisfies.
  Consumers look up the catalogue instead of carrying `has "x"` ladders.
- acpx keeps its own route declarations ([ADR 0032](../adr/0032-acpx-model-routing.md)).
  The consolidation adds one render-time consistency check: a declared route
  whose harness CLI is not in `agent_clis` fails the apply with a diagnostic
  instead of surfacing later as `missing dependencies`.
- Per-machine matrix, agreed 2026-09-30:

  | machine type | `agent_clis` |
  | --- | --- |
  | personal | claude, codex, omp, pi, gemini |
  | homelab | claude, codex, omp, pi, gemini |
  | work | claude, cursor-agent, pi |
  | devbox | claude, cursor-agent, omp, pi |
  | ci | (empty) |

  Effective changes: work loses `omp` (XDR) and `gemini`; devbox gains `omp`,
  `pi`, and an installed `cursor-agent`; personal and homelab keep what they
  have, since `omp`, `pi`, and `gemini` were unconditional.
- `cursor-agent` gets an install hook shaped like the Claude and Codex ones,
  allowlisted for devbox.
- `codex-acp` follows `codex` through the catalogue; the `codex` package group
  retires because that formula was its only content.

## Catalogue sketch

```toml
[agents.claude]
binary = "claude"
install = "native-hook"                 # run_after_06-claude-native
adapters = ["mise:npm:@agentclientprotocol/claude-agent-acp"]
orca = "claude"
plugins = true
harness = "claude"

[agents.codex]
binary = "codex"
install = "native-hook"                 # run_after_07-codex-standalone
adapters = ["brew:codex-acp"]
config_paths = [".codex"]
orca = "codex"
plugins = true
harness = "codex"

[agents.cursor-agent]
binary = "cursor-agent"
install = "native-hook"                 # run_after_07-cursor-agent
config_paths = [".cursor/cli-config.json"]
orca = "cursor"
harness = "cursor"

[agents.omp]
binary = "omp"
install = "mise"
mise = "github:can1357/oh-my-pi"
orca = "omp"
plugins = true
harness = "omp"

[agents.pi]
binary = "pi"
install = "mise"
mise = "npm:@earendil-works/pi-coding-agent"
config_paths = [".pi"]
orca = "pi"

[agents.gemini]
binary = "gemini"
install = "mise"
mise = "npm:@google/gemini-cli"
orca = "gemini"
```

The contract is that every consumer below reads this file and `agent_clis`,
nothing else. The resolver, `home/.chezmoitemplates/agents.tmpl`, emits
`{"selected": {id: entry}, "unselected": {id: entry}}`; `features.tmpl` has
already rejected an unknown id by then.

## How it flows

```text
machines.toml ─ agent_clis ─┐
                            ├─▶ features.tmpl ─▶ agents.tmpl ──▶ {"selected": {…}, "unselected": {…}}
agents.toml ── catalogue ───┘   (fails on an        (resolver)
                                 unknown id)              │
          ┌───────────────┬───────────────┬───────────────┼───────────────┬───────────────┬──────────────┐
          ▼               ▼               ▼               ▼               ▼               ▼              ▼
   clis.toml.tmpl    brewfile.tmpl   .chezmoiignore   hooks 06/07/   hooks 36/39     routing.json   orca-settings
   (mise entries     (brew: adapters) (config_paths    07-cursor      (plugins=true    .tmpl (acpx    .desired.json
   + hook 20          → "codex-acp")   of unselected)  (gate on        → --agent …)     harness       .tmpl (orca ids
   uninstalls                                          selected)                        check)        of unselected)
   unselected)
          │               │               │               │               │               │              │
          ▼               ▼               ▼               ▼               ▼               ▼              ▼
   ~/.config/mise/    Brewfile →     ~/.codex ~/.pi    ~/.local/bin/    claude/codex/    ~/.config/     profile-state.db
   conf.d/clis.toml   brew bundle    ~/.cursor/… gated  {claude,codex,   omp plugin       acpx/routing   settings row
                                                        cursor-agent}    records          .json          (Orca plan)
```

What lands per machine:

| consumer | personal | homelab | work | devbox |
| --- | --- | --- | --- | --- |
| mise entries | omp, pi, gemini, claude-agent-acp | same | pi, claude-agent-acp | omp, pi, claude-agent-acp |
| Brewfile adapters | codex-acp | codex-acp | — | — |
| install hooks | 06 claude, 07 codex | same | 06 claude, 07 cursor-agent | 07 cursor-agent (06 not allowlisted; work tooling provisions claude) |
| hidden config | `.cursor/cli-config.json` | same | `.codex` | `.codex` |
| plugin reconcile | claude, codex, omp | same | claude | — (36 not allowlisted) |
| acpx check | omp, codex, claude routes ✓ | same | claude-vertex, cursor ✓ | no routes |
| mise uninstall on first apply | — | — | omp, gemini | — |

## Consumers to switch

1. `features.tmpl` validates `agent_clis ⊆ catalogue`. A small helper template
   returns the selected catalogue entries as JSON so consumers `fromJson` once.
2. mise: `dot_config/mise/conf.d/clis.toml` becomes a template. The "AI coding
   harnesses" section and `claude-agent-acp` render from the selected entries.
   Hook 20 hashes the rendered content (not the template source) so a matrix
   change re-runs it, and it uninstalls a catalogue mise agent that is installed
   but no longer selected; that is how `omp` leaves work, since
   `packages.retired` is Homebrew-only.
3. Brewfile: the `codex-acp` line renders from the selected entries' `brew:`
   adapters. The `codex` package group is removed from `packages.toml` and from
   the personal/homelab group lists.
4. Hook 07 (Codex) gates on `has "codex" $f.agent_clis`; ADR 0027 gets a
   status note.
5. `run_after_07-cursor-agent.sh.tmpl`: Cursor's installer into
   `~/.local/share/cursor-agent/versions/<v>/` with `~/.local/bin/{cursor-agent,agent}`
   symlinks, idempotent on `cursor-agent --version`, run with the sanitized
   `PATH` the 06/07 hooks use so the installer never edits shell startup files.
   Sorts after `07-codex-standalone`; added to the devbox allowlist.
6. Hooks 36 and 39 iterate `agent_clis` filtered by the catalogue's `plugins`
   flag instead of the hardcoded `claude|codex|omp` ladder.
7. acpx: the routing render fails when a declared route's `harness` maps to a
   catalogue agent missing from `agent_clis`. The `requires` PATH check in
   `scripts/acpx/reconcile` stays as the runtime truth.
8. `.chezmoiignore`: the `.codex` gate moves to `agent_clis`; `.pi` gains a gate.
9. Orca: hide-list is catalogue Orca ids minus the machine's selection; default
   agent is the first selected in `codex, claude, cursor, omp`. Owned by the
   [Orca plan](orca-settings-store-plan.md).
10. Docs: `acpx-routing.md` (the "`agent_clis` continues to control installation"
    paragraph), `mise-tool-management.md` (templated harness section),
    `chezmoi-architecture.md` (catalogue), `tests/README.md`.

## Increments

1. Catalogue, `features.tmpl` validation, and the matrix in `machines.toml`.
   No consumer changes. Tests: `test_machines.py` (unknown id fails; matrix per
   type renders).
2. Install surfaces: mise template plus uninstall step, Brewfile adapter line
   and group retirement, hook 07 gate, the cursor-agent hook and devbox
   allowlist, `.chezmoiignore` gates. Tests: `test_brewfile.py`,
   `test_config_gates.py`/`gate_examples.py` (`.codex`, `.pi`,
   `.cursor/cli-config.json` per type), a `cursor-agent.bats` mirroring
   `claude-native.bats` with a fixture installer, `test_chezmoi.py` devbox
   managed set.
3. Consumers: hooks 36/39 through the catalogue; the acpx consistency check.
   Tests: `test_acpx.py` (declared route with its agent missing fails render),
   `tests/python/agents/test_packages.py` plugin-agent selection.
4. Docs, ADR 0041 to accepted, then live applies: work (omp and gemini
   uninstalled, cursor-agent hook a no-op), devbox (omp, pi, cursor-agent
   arrive), personal and homelab (no effective change; `codex-acp` stays
   installed under its new provenance).

## Validation

- `just test-python -p test_machines.py -p test_brewfile.py -p test_config_gates.py -p test_acpx.py -p test_chezmoi.py`
- `just test-shell tests/bats/packages/claude-native.bats tests/bats/packages/cursor-agent.bats`
- `just test-chezmoi-apply` for every machine type.
- `scripts/packages/render-brewfile --machine-type <type>` before and after:
  only the `codex-acp` provenance may differ.
- Live on work-mbp: `mise ls` without `omp`/`gemini`, `command -v omp` empty,
  `~/.agents/bin/acpx-routing` report unchanged (routes `claude-vertex`, `cursor`).

## Risks and open items

- Cursor's installer (read 2026-09-30, pinned to 2026.09.28) takes no flags and
  asks nothing: `curl | tar` into a temp dir under `versions/`, atomic `mv`,
  `rm -f` + `ln -s` for `agent` and `cursor-agent`, and only *prints* `PATH`
  advice when `~/.local/bin` is off `PATH`; it never edits shell startup files.
  `cursor-agent.bats` proves the hook against a fixture installer.
- `mise uninstall --all <spec>` and `mise ls --json <spec>` (empty list when
  absent) were confirmed on mise 2026.9.2 before hook 20 relied on them.
- On devbox, `claude` is provisioned by work tooling and the Claude hook is
  not allowlisted; the catalogue records the mechanism, the allowlist decides
  whether a hook runs. That stays as documented in the
  [devbox plan](linux-devbox-plan.md).
- Personal and homelab live state was not reachable from the work network
  during the audit; their effective lists do not change, so the risk is limited
  to render differences the tests cover.
