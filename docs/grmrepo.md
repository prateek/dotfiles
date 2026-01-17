# GRM (git-repo-manager) on this machine

This dotfiles repo wires up [git-repo-manager](https://github.com/hakoerber/git-repo-manager) ("GRM") for:

- Tracking canonical local clones under `~/code`
- Fast repo URL insertion (shell + global via Hammerspoon)
- Routing `gh` between work/personal accounts based on repo context

## Layout conventions

- Canonical clones live under `~/code/github.com/<owner>/<repo>`
- Exceptions:
  - `github.com/openai/openai` → `~/code/openai`
  - `github.com/chronosphereio/chronosphere-openai` → `~/code/chronosphere-openai`
- Git worktrees can live anywhere; they are **not** tracked by GRM config here.

## Bootstrap

- `~/dotfiles/bootstrap.sh` installs:
  - `cask "hammerspoon"` (via Brewfile)
  - `git-repo-manager` (via `cargo install git-repo-manager --locked`, if `cargo` exists)
- It also symlinks:
  - `~/.config/grm/config.toml` → `~/dotfiles/.config/grm/config.toml`
  - `~/.hammerspoon/init.lua` → `~/dotfiles/.hammerspoon/init.lua`
  - `~/bin/{gh,grmrepo,grmrepo-refresh,repo-index}` → `~/dotfiles/bin/*`

## Keeping GRM config up to date

- Refresh config from local clones:
  - `grmrepo refresh`
- Hooks:
  - Interactive `git clone` and `git worktree {add,remove,prune}` trigger a background refresh (`zsh/lib/grmrepo.zsh`)
  - Interactive shells trigger a background refresh at most once per day (catches manual deletes) (`zsh/lib/grmrepo.zsh`)
  - `gh repo clone/create` triggers a background refresh (via `~/bin/gh` wrapper)
  - `ghc` triggers a background refresh after cloning

Config file: `~/.config/grm/config.toml`

### Config structure note

To keep `grm repos status` working with `owner/repo` naming, `grmrepo-refresh` emits one `[[trees]]` per GitHub owner (namespace), and uses `name="<repo>"` inside that tree.

## Using GRM

- Global status:
  - `grmrepo repos status`
- Clone everything from the config onto a new machine:
  - `grmrepo repos sync config`

## `gh` account routing (work vs personal)

- Wrapper: `~/bin/gh`
- Rules live in: `~/dotfiles/zsh/lib/gh-user-rules.zsh`
- Override per-invocation:
  - `GH_WRAPPER_USER=prateek gh repo view openai/codex`

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
