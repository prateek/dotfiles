---
status: archived
doc_type: reference
updated: 2026-06-25
closed: 2026-06-29
current_guidance: ../../home/dot_agents/docs/git.md
status_detail: "Custom grm integration removed (grmrepo, grmrepo-refresh, the bin/gh shim, grm config). Repos are now cloned with ghc/gh; see the git conventions doc."
---

# GRM (git-repo-manager) on this machine

This dotfiles repo wires up [git-repo-manager](https://github.com/hakoerber/git-repo-manager) ("GRM") for:

- Tracking canonical local clones under `~/code`
- Fast repo URL insertion (shell + global via Hammerspoon)
- Refreshing GRM metadata after `gh repo clone/create`

## Layout conventions

- Canonical clones live under `~/code/github.com/<owner>/<repo>`
- Git worktrees can live anywhere; they are **not** tracked by GRM config here.
- The generated GRM config contains only clones that actually exist on this machine.
- A canonical clone is only "first-class" for GRM when it has at least one supported network remote (`git@...`, `ssh://...`, `https://...`). Repos with no `origin` or only local filesystem remotes can still be tracked for status, but `grmrepo repos sync config` cannot clone them onto another machine until the remote is fixed.

## Bootstrap

- `chezmoi apply` installs (via `home/.chezmoiscripts/run_onchange_after_10-brew-bundle.sh.tmpl`):
  - `cask "hammerspoon"` (declared in `home/.chezmoidata/packages.toml`)
  - `git-repo-manager` (via `cargo install git-repo-manager --locked`, if `cargo` exists)
- It also materializes:
  - `~/.config/grm/config.toml` rendered by chezmoi from `home/dot_config/grm/config.toml.tmpl`
    (base + machine-type fragments; see "Machine-type config")
  - `~/.hammerspoon/init.lua` from `home/dot_hammerspoon/init.lua`
  - `~/bin/{gh,grmrepo,grmrepo-refresh,repo-index}` from `home/bin/symlink_*`
    templates that point back to the repo-local `bin/` scripts

## Keeping GRM config up to date

- Refresh config from local clones:
  - `grmrepo refresh`
- Hooks:
  - Interactive `git clone` and `git worktree {add,remove,prune}` trigger a
    background refresh from `home/dot_config/zsh/lib/grmrepo.zsh`
    (materialized to `~/.config/zsh/lib/grmrepo.zsh`)
  - Interactive shells trigger a background refresh at most once per day
    (catches manual deletes) from the same zsh library
  - `gh repo clone/create` triggers a background refresh (via the managed
    `~/bin/gh` wrapper)
  - `ghc` triggers a background refresh after cloning

Config file: `~/.config/grm/config.toml` (generated; do not edit by hand)

### Machine-type config (base + per-type; work stays local)

`~/.config/grm/config.toml` is rendered by chezmoi from `home/dot_config/grm/config.toml.tmpl`,
which merges:

- **base** — `home/.chezmoiassets/grm/base.toml` (committed; every machine; curate by hand).
- **personal / homelab** — `home/.chezmoiassets/grm/<machine_type>.toml` (committed; synced to
  same-type machines).
- **work** — `~/.config/grm/config.local.toml` (host-local, **never committed**; chezmoi-ignored).

`grmrepo refresh` regenerates only *this* machine's fragment — the host-local file on a `work`
machine, otherwise the committed `<machine_type>.toml` — skips owners already covered by `base.toml`,
and re-renders `config.toml`. Work-org clones therefore never enter the dotfiles repo. After
refreshing on a personal/homelab machine, commit the updated
`home/.chezmoiassets/grm/<machine_type>.toml`.

### Config structure note

To keep `grm repos status` working with `owner/repo` naming, `grmrepo-refresh` emits one `[[trees]]` per GitHub owner (namespace), and uses `name="<repo>"` inside that tree.

## Using GRM

- Global status:
  - `grmrepo repos status`
- Clone everything from the config onto a new machine:
  - `grmrepo repos sync config`

## `gh` wrapper

- Wrapper: `~/bin/gh`
- Behavior:
  - Passes through to the real `gh`
  - Triggers a background `grmrepo-refresh` after successful `gh repo clone/create`

### Extending Back To Multiple `gh` Users

If this machine needs multiple authenticated `gh` users again, keep the current wrapper thin and put the account-selection logic behind a small sourced rules file rather than rebuilding it inline.

Recommended shape:

- Add a rules file such as `~/.config/zsh/lib/gh-user-rules.zsh`
- Define one function with a narrow interface:
  - `gh_user_for_context <origin_url> <repo_slug>`
- In `~/bin/gh`:
  - source that rules file if it exists
  - derive context from the current repo `origin`, `--repo/-R`, or a repo argument for commands like `gh repo clone owner/repo`
  - resolve the target account with `gh_user_for_context`
  - fetch a token with `gh auth token --user <name>`
  - exec the real `gh` with `GH_TOKEN` and `GITHUB_TOKEN` set to that token
- Keep `grmrepo-refresh` as a post-success hook for `repo clone/create`

Guidelines:

- Keep repo-to-user matching declarative and isolated in the rules file
- Prefer matching on explicit repo slug or remote URL, not on arbitrary command arguments
- Keep `ghc` SSH-first unless you also need owner-specific SSH aliases; if you reintroduce those aliases, only do it when the corresponding SSH config is actually present

## URL insertion UX

### Shell

- `Ctrl-U` (in zsh `vicmd` mode) runs `url_select` and inserts a chosen repo HTTPS URL.
- Source: `repo-index --format tsv` (fzf picker).

### Global (Hammerspoon)

- `Ctrl+Alt+Cmd+U`: pick a repo URL and paste it
- `Ctrl+Alt+Cmd+T`: pick a file from a repo and paste its absolute path (tracked + untracked, excludes ignored)
- `Ctrl+Alt+Cmd+Shift+T`: same as above, but always asks for the repo first
- In the picker:
  - Type to filter (fuzzy match)
  - `↑/↓` or `Ctrl-J/Ctrl-K`: move selection
  - `Tab`: mark/unmark (multi-select); `Ctrl-A`: select all; `Ctrl-D`: clear
  - `Enter`: paste (if anything is marked, pastes all marked items joined with newlines)

Results are sorted by fuzzy relevance with a recency boost (recently pasted items float to the top, especially when the query is empty).

#### Debugging Hammerspoon

- Logs are printed to the Hammerspoon Console.
- Default log level is `info`.
- Toggle verbose logging:
  - `RepoOverlay.setLogLevel("debug")` (or `RepoOverlay.toggleDebug()`)
  - Back to normal: `RepoOverlay.setLogLevel("info")`
- Quick state dump: `RepoOverlay.dump()`
