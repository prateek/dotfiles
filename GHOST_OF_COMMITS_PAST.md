# Ghost of Commits Past

Things a past agent landed or assumed that someone still has to verify. Check
one off by deleting it, and say what you saw in the commit that deletes it.

## 2026-10-20: Thaw layout, groups, triggers and grid (home/.chezmoitemplates/com.stonerl.Thaw.plist.tmpl)

- On a personal Mac on macOS 27 with Thaw 3.0 beta: the seeded `MenuBarItemGroups` (version 1) still loads and "Show as a Folder" works.
- On a fresh Mac after `chezmoi apply` and Thaw's first launch: both spacers land in hidden, and with all its apps running the Thaw Bar grid shows Often as row one.

Skills: `chezmoi-management`, `peekaboo-vm-app-audit`.

## 2026-10-22: perf-views skill (agent-marketplace/src/utils-agent/skills/perf-views/)

- After apply, in Claude and Codex, `/perf-views` runs, and the skill is absent from the model's skill listing.
- From a sample span file, write all three exports; the trace opens in ui.perfetto.dev, the speedscope file in speedscope.app, and `inferno-flamegraph --countname ns` draws the folded file.
- Run the benchmark-zsh-startup Perfetto recipe through `open-perfetto`; the timeline shows `.zshrc` spans.

Skills: `utils-agent:perf-views`, `agent-skill-management`, `benchmark-zsh-startup`.

## 2026-10-22: orcactl engine and src/ layout (docs/plans/orcactl-plan.md)

- Open the `install-smoke` macOS run for this commit; `orcactl-test` passes inside `just test-ci` (Go from mise.toml).
- `just test-orca-shortcuts-docker --entrypoint orcactl --orca-version 1.4.224 --scenario paired`; all checks pass.

Skills: `utils-agent:orca-cli`.
