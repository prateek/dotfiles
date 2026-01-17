# iTerm2 + tmux (Ghostty → iTerm2)

This repo treats iTerm2 as a “viewport” and tmux as the session manager:

- iTerm2 default profile: `Solarized Dark Patched` (Dynamic Profile)
- tmux autostart for interactive iTerm2 shells (`main` session by default)
- Scripted “new tab” launcher with presets + modal picker
- tmux command palette (fzf) + shortcuts to trigger the launcher

## Apply

- `./bootstrap.sh` (symlinks `~/.config/tmux`)
- `scripts/macos/apply.sh` (symlinks iTerm2 Dynamic Profiles/Scripts and sets the default profile GUID)
- Restart iTerm2

## iTerm2 theme

- Dynamic Profile: `osx-apps/iterm2/DynamicProfiles/dotfiles.json`
- Color preset (optional): `osx-apps/iterm2/colors/Solarized-Dark-Patched.itermcolors`
- Background texture used by the profile: `osx-apps/iterm2/backgrounds/solarized-grain.png`
- Snapshot your current iTerm2 profile back into the repo: `scripts/iterm2/snapshot-profiles --include-tmux`

## tmux autostart

`zsh/extra/tmux.zsh` auto-attaches iTerm2 shells to tmux:

- Session: `$DOTFILES_TMUX_SESSION` (default: `main`)
- Escape hatch: `DOTFILES_TMUX_AUTOSTART=0`

## Scripted tab opener

Script: `scripts/iterm2/iterm-tab`

- Opens an iTerm2 tab (optionally with a specific profile)
- Creates a tmux window (optionally with a start dir/name/command)
- Attaches the new iTerm2 tab directly to that tmux window

Presets + modal picker:

- `scripts/iterm2/iterm-tab --choose`
- Preset file: `scripts/iterm2/tab-presets.tsv`

## tmux shortcuts (recommended)

In `~/.config/tmux/tmux.conf`:

- `prefix + P`: tmux command palette popup (fzf)
- `prefix + t`: open a new iTerm2 tab in the current pane’s directory
- `prefix + T`: open the preset chooser modal
- `Ctrl + y`: enter tmux copy mode (no prefix)

## iTerm2 shortcut: resume last Codex session

This repo includes an iTerm2 AutoLaunch script that registers two RPCs:

- `codex_resume_last_run()` – finds the most recent `codex resume <uuid>` in scrollback and runs the equivalent resume command
- `codex_resume_last_paste()` – same, but only types it (doesn’t press Enter)

Install via `scripts/macos/apply.sh` (symlinks `osx-apps/iterm2/Scripts`), then restart iTerm2.

Bind a key:

- iTerm2 Settings → Keys (or Profiles → Keys) → Key Bindings → `+`
- Action: **Invoke Script Function**
- Parameters: `codex_resume_last_run()`

## iTerm2 shortcut: split panes in the current directory (vanilla iTerm2)

If you sometimes use iTerm2 splits outside tmux, this repo includes an AutoLaunch script that registers:

- `split_pane_cwd_vertical()` – split left/right, then `cd` to the active pane’s directory
- `split_pane_cwd_horizontal()` – split top/bottom, then `cd` to the active pane’s directory

Bind keys:

- iTerm2 Settings → Profiles → Keys → Key Bindings → `+`
- Action: **Invoke Script Function**
- Parameters:
  - `⌘D` → `split_pane_cwd_vertical()`
  - `⌘⇧D` → `split_pane_cwd_horizontal()`

## Optional: map Cmd+T / Cmd+Shift+T to the tmux version

If you want iTerm2’s `⌘T` to run the scripted flow (instead of iTerm2’s built-in “New Tab”):

- iTerm2 Settings → Keys → Key Bindings:
  - `⌘T` → **Send Hex Codes**: `0x02 0x74` (tmux prefix `C-b`, then `t`)
  - `⌘⇧T` → **Send Hex Codes**: `0x02 0x54`
  - `⌘⇧P` → **Send Hex Codes**: `0x02 0x50`

If your tmux prefix is not `C-b`, replace `0x02` with the hex code for your prefix key.
