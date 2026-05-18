# Agent Notes

This is the repo-specific contract for coding agents working in Prateek's dotfiles repo. Keep this file lean. Put repeatable maintenance workflow in `$code-gardening`, and keep deep topic guidance in the focused docs it points to.

## Repo Map

- `home/`: chezmoi source state. `.chezmoiroot` points here, so files materialize into `$HOME`.
- `home/.chezmoidata/`: committed structured data for package profiles, secrets, license targets, and template inputs.
- `home/.chezmoiscripts/`: idempotent setup run by `chezmoi apply`.
- `home/.chezmoitemplates/`: shared templates, including Brewfile, macOS defaults, and plist merge helpers.
- `.agents/`: repo-local agent surface for this checkout. Keep repo-specific `AGENTS.md` and `CLAUDE.md` at the repo root; keep repo-local skills and tool adapters under `.agents/`.
- `home/dot_agents/`: chezmoi-managed machine agent surface. Machine-wide `AGENTS.md`, docs, skills, and workflow conventions live here so they materialize under `~/.agents`.
- `home/dot_claude/`: chezmoi-managed Claude config for this machine. Its `CLAUDE.md` target should symlink to `../.agents/AGENTS.md`.
- `home/dot_codex/`: chezmoi-managed Codex config for this machine.
- `scripts/`: focused helpers for packages, macOS/app config, Tart, traces, audits, and hooks.
- `docs/index.md`: starting point for current guidance, active plans, ADRs, and historical records.
- `docs/document-lifecycle.md`: canonical frontmatter statuses and transition rules for `docs/`.
- `docs/plans/`: non-trivial repo change plans.
- `docs/references/`: current operator-facing architecture and reference docs.
- `docs/runbooks/`: current step-by-step operational procedures.
- `docs/research/`: source-backed investigations and background reports.
- `docs/adr/`: architectural decisions.

Chezmoi is the ongoing command surface: prefer `chezmoi apply`, `chezmoi status`, `chezmoi diff`, `chezmoi verify`, `chezmoi managed`, and `chezmoi unmanaged` over adding a wrapper.

Keep repo-local and machine-level agent state separate. Files that define how agents work in this dotfiles checkout stay at the repo root or under repo-root `.agents/`. Files that configure Prateek's machine-wide agent environment stay under `home/` so chezmoi materializes them into `$HOME`.

Use `$agent-skill-management` for changes to `home/dot_agents/packages/`,
apply-time skill/plugin render scripts, Codex or Claude rendered plugin
activation, and the related docs (`docs/plans/chezmoi-agent-skills-plan.md`,
`docs/research/agent-skill-management-research.md`, `docs/adr/0007-default-loaded-plugin-policy.md`). The generated live roots are
`~/.agents/skills`, `~/.claude/skills`, and `~/.agents/plugins`; do not commit
source copies under `home/dot_agents/skills`, `home/dot_claude/skills`, or
`home/dot_agents/plugins`.

## Docs And Decisions

- Non-trivial repo initiatives get a plan at `docs/plans/<slug>-plan.md`.
- Architectural decisions get the next numbered ADR at `docs/adr/<NNNN>-<slug>.md`; never renumber existing ADRs.
- Markdown docs under `docs/` must use YAML frontmatter with a canonical `status`; follow [docs/document-lifecycle.md](docs/document-lifecycle.md) for states and transitions.
- Update [docs/index.md](docs/index.md) when docs are added, moved, closed, or reclassified.
- Current operational guidance belongs in `docs/references/` or `docs/runbooks/`. Completed plans should be archived or superseded and point to current guidance.
- Plan docs reference their ADRs, and ADRs reference the plan docs that prompted them. Prefer Markdown-relative links for in-repo docs.
- Small one-off fixes do not need a plan or ADR.
- `README.md` is user-facing and intentionally tiny. Move coding-agent or maintenance details here or into focused docs instead.
- `AGENTS.md` should contain durable conventions only. Do not add one-off session notes.

## Common Commands

- Preview managed state: `chezmoi diff`, `chezmoi status`, `chezmoi apply --dry-run --verbose --exclude=scripts`.
- Render package input: `scripts/packages/render-brewfile --profile core|full`.
- Package/app audits: `scripts/audit/brew-inventory.sh`, `scripts/audit/brewfile-usage.sh`, `scripts/audit/app-inventory.sh`.
- Fresh-shell checks: `scripts/audit/zsh-fresh-shells.zsh verify` and `bench`.
- Docs lifecycle checks: `make test-docs-lifecycle` for the local diff and `DOCS_LIFECYCLE_BASE=origin/master make test-docs-lifecycle` for a full branch check.
- Test index: `tests/README.md`.
- Tart local install lane: `docs/runbooks/tart-mini-validation.md`.
- Worktree workflow: `home/dot_agents/docs/worktrees.md`.
- Git/commit workflow: `home/dot_agents/docs/git.md`.

## Chezmoi And App Config

- Keep app config readable at the native target path under `home/` when possible.
- Simple file-backed apps should use focused tests.
- Nested preference plists use a desired-plist fragment at `home/.chezmoitemplates/<bundle-id>.plist.tmpl` driven by a 3-line `modify_` stub through the shared merge engine.
- Plist fragments are Go templates. If a plist value contains literal `{{` or `}}`, escape it, as with Moom geometry strings.
- Non-plist payloads that should not be templated stay under `home/.chezmoiassets/` and load via `include`, not `includeTemplate`.
- Do not reintroduce `home/.chezmoidata/apps/*.toml`; that mechanism was retired with `bin/dotfiles`.
- Gate optional app config in `home/.chezmoiignore`. Do not render empty placeholder config for absent apps.
- Secret-backed configs and licenses are private templates under `home/`, driven by `home/.chezmoidata/secrets.toml` and `licenses.toml`; store only obfuscated `op://` refs.
- Raw app captures live under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/captures/`, not in the repo.
- Mac App Store entries are opt-in with `DOTFILES_INSTALL_MAS_APPS=true`.
- Setapp-managed apps install after Setapp login. Do not add config for a Setapp-installed app until the repo also has an install path for that app.
- Chrome extension settings are not snapshotted from user profiles. Prefer Chrome Sync or extension-native export.

## Shell Startup

Shell load order:

```text
zshenv -> zprofile -> zshrc -> init.sh -> zinit-init.zsh -> lib/*.zsh -> extra/*.zsh
```

- Keep baseline `PATH` entries in `zprofile`'s `path=(...)` array, not ad hoc `export PATH=...` snippets in `zshrc`.
- Keep host-local shell secrets and env overlays in `$HOME/.zprofile.local` or `$HOME/.zshrc.local`; they are sourced by managed zsh startup and ignored by chezmoi.
- Prefer explicit directories like `$HOME/go/bin` over indirect env vars like `$GOPATH/bin` for shell PATH setup.
- When startup only needs mise shims, add `$HOME/.local/share/mise/shims` to `zprofile` instead of running `mise activate --shims` on every shell.
- Reserve `zshrc` PATH mutations for interactive or late overlays only.
- Prefer autoloaded wrappers for optional or conflicting CLIs instead of source-time aliases.
- For zoxide, prefer lazy wrappers plus `zoxide init zsh --cmd j`; keep `zi` reserved for zinit.
- Avoid source-time command substitutions such as `$(brew --prefix)`. Prefer `HOMEBREW_PREFIX`, `whence -p`, or resolution at call time.
- Guard shell widgets and key-binding scripts behind `[[ -o zle ]]`.
- Use a real PTY login shell for shell widget/keymap debugging; `zsh -ic` can lie about ZLE.
- Synthetic shell harnesses must set `DOTFILES_SKIP_LAUNCHCTL_SYNC=1`.
- If syncing `PATH` into `launchctl`, compare against `launchctl getenv PATH`, not a persistent cache file.

## Validation

- For code behavior changes, add or update the smallest meaningful tests and run the relevant local checks.
- For docs/config-only changes, run the lightest checks that prove links, parsers, or generated output still make sense.
- Mirror CI locally when practical by inspecting `.github/workflows`.
- Current CI includes shellcheck, chezmoi dry-run smoke for `core` and `full`, Tart helper contract tests, trace conversion tests, package rendering, and core formula install checks.
- CI does not boot a full macOS VM; that is local via Tart.
- Never ignore test output. If expected errors are part of behavior, assert them.

## Dependency And Tooling Gotchas

- Python imports must be declared in `pyproject.toml`; add stubs and build-system dependency mirrors when typecheck/build rules need them.
- When testing, evaluating, or selecting a specific CLI version, prefer mise (`mise use`, `mise link`, or a repo-owned `mise run <tool>:use` task) over swapping Homebrew/npm/cargo/pipx installs. Use ignored `mise.local.toml` for per-worktree experiments; commit durable machine-wide selections under `home/dot_config/mise/`.
- For skill-creator eval review (the human-review HTML over an iteration directory), default to `scripts/eval-review.py`. Use the canonical skill viewer (`generate_review.py`) only if the user explicitly asks for it.
- After editing a skill, validate it. Frontmatter/parser drift has bitten this repo before.
- If CI says to run the build file generator and provides a diff, apply that diff exactly when local generation is blocked by auth/network/private module issues.
- Use `git diff --check` before handoff on non-trivial docs or code changes.
