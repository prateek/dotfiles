# pi viewers

Two pi extensions that watch agent work in a terminal, on one shared kit:

- `pi-viewer acpx`: every open acpx session under a worktree, attached through
  `acpx sessions watch`. `acpx-pane` (utils-agent's acpx skill) opens it in an
  Orca split, one per worktree.
- `pi-viewer workflow`: one Claude Code Workflow run, tailed from the files
  Claude Code writes. `--once` prints the run as JSON instead.

`bin/pi-viewer` starts pi with the extension and a private agent directory (no
packages, no telemetry). `lib/core.ts` is the pure part (layout, fold rows, hit
regions, input modes, preferences, the keymap); `lib/kit.ts` adds what needs
pi-tui and hosts a viewer's `Spec`. Preferences persist under
`${XDG_STATE_HOME:-~/.local/state}/pi-viewers/<viewer>/`.

Checks: `just pi-viewers-test` runs `tests/*.test.mjs` (no pi needed);
`just pi-viewers-typecheck` links the installed pi's packages and runs `tsc`.
Chezmoi links `~/.local/bin/pi-viewer` here on every machine; without pi the
launcher exits with a message and `--once` still works.
