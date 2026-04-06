# GRM (git-repo-manager) on this machine

This dotfiles repo wires up [git-repo-manager](https://github.com/hakoerber/git-repo-manager) ("GRM") for:

- Tracking canonical local clones under `~/code`
- Fast repo URL insertion (shell + global via Hammerspoon)
- Refreshing GRM metadata after `gh repo clone/create`

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

## `gh` wrapper

- Wrapper: `~/bin/gh`
- Behavior:
  - Passes through to the real `gh`
  - Triggers a background `grmrepo-refresh` after successful `gh repo clone/create`

### Extending Back To Multiple `gh` Users

If this machine needs multiple authenticated `gh` users again, keep the current wrapper thin and put the account-selection logic behind a small sourced rules file rather than rebuilding it inline.

Recommended shape:

- Add a rules file such as `~/dotfiles/zsh/lib/gh-user-rules.zsh`
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
