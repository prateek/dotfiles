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
- `docs/plans/`: proposed, active, and historical initiatives.
- `docs/references/`: steady-state operator references.
- `docs/runbooks/`: executable operating procedures.
- `docs/research/`: research snapshots and maintained research.
- `docs/adr/`: architectural decisions.
- `docs/index.md`: routing table for current docs, proposed work, ADRs, and historical records.
- `docs/document-lifecycle.md`: lifecycle states, frontmatter rules, and doc-type guidance.

Chezmoi is the ongoing command surface: prefer `chezmoi apply`, `chezmoi status`, `chezmoi diff`, `chezmoi verify`, `chezmoi managed`, and `chezmoi unmanaged` over adding a wrapper.

Keep repo-local and machine-level agent state separate. Files that define how agents work in this dotfiles checkout stay at the repo root or under repo-root `.agents/`. Files that configure Prateek's machine-wide agent environment stay under `home/` so chezmoi materializes them into `$HOME`.

## Source Surface Overview

Use this table to identify the owning surface before opening deeper docs or grepping. Detailed task routing belongs in focused references, runbooks, or skills.

| Surface | Owns | Detailed routing |
| --- | --- | --- |
| `home/` | Chezmoi source state that materializes into `$HOME`. | [Chezmoi Architecture](docs/references/chezmoi-architecture.md). |
| `home/.chezmoidata/` | Structured package, secret, license, and template inputs. | Package and secret docs plus `$chezmoi-management`. |
| `home/.chezmoitemplates/` | Shared templates, Brewfile rendering, macOS defaults, and plist merge fragments. | [Chezmoi Architecture](docs/references/chezmoi-architecture.md) and `$chezmoi-management`. |
| `home/.chezmoiscripts/` | Idempotent setup hooks run by `chezmoi apply`. | Runbooks and focused tests. |
| `.agents/` | Repo-local agent surface for this checkout. | Repo-specific skills, adapters, and root `AGENTS.md` / `CLAUDE.md`. |
| `home/dot_agents/` | Machine-wide agent surface materialized to `~/.agents`. | Shared skills, docs, and workflow conventions. |
| `docs/` | Routing, decisions, plans, references, runbooks, research, and historical records. | [Docs Index](docs/index.md) and [Docs Lifecycle](docs/document-lifecycle.md). |
| `scripts/` and `tests/` | Validation helpers, audits, renderers, and tests. | [Test Index](tests/README.md). |

## Doc Folder Purposes

| Folder | Contents | `doc_type` | Typical status | Authority |
| --- | --- | --- | --- | --- |
| `docs/` | Routing infrastructure only | `index`, `convention` | `current` | Authoritative for how to navigate docs. |
| `docs/adr/` | Architectural decision records | `adr` | `accepted` once decided; body locked | Authoritative for why a decision was made. Never the live implementation manual. |
| `docs/plans/` | Proposed, active, and historical initiatives | `plan` | `proposed`, `accepted`, `active`, `superseded`, `archived` | Never authoritative for live behavior. |
| `docs/references/` | Steady-state operator references | `reference` | `active` | Authoritative for how live systems work. |
| `docs/runbooks/` | Executable operating procedures | `runbook` | `active` | Authoritative for repeatable procedures. |
| `docs/research/` | Research snapshots and maintained research | `research` | `active`, `archived`, `superseded` | Evidence and context, not current operating guidance unless status is `active`. |

Rules of thumb:

- If you wrote a `plan` and it is now implemented, do not flip it to `current`. Create or update a `reference`, `runbook`, or skill and set the plan to `superseded` or `archived`.
- New ADRs go in `docs/adr/<NNNN>-<slug>.md`. Never renumber.
- Operator references go in `docs/references/`, not `docs/` root.
- Repeatable procedures go in `docs/runbooks/` or a skill.
- Research goes in `docs/research/`; old research must point to `current_guidance`.
- Anything in `docs/plans/` is upcoming, active, or historical. If an agent treats a `plans/` doc as the live spec, it is reading the wrong doc.
- If you edit anything under `docs/`, run `make test-docs-lifecycle` before handoff.

## Docs And Decisions

- Non-trivial repo initiatives get a plan at `docs/plans/<slug>-plan.md`.
- Architectural decisions get the next numbered ADR at `docs/adr/<NNNN>-<slug>.md`; never renumber existing ADRs.
- Markdown docs under `docs/` must use YAML frontmatter with a canonical `status`; follow [docs/document-lifecycle.md](docs/document-lifecycle.md) for states and transitions.
- Keep [docs/index.md](docs/index.md) as the docs routing table. Update it when adding, renaming, closing, superseding, or reclassifying docs.
- Read `docs/` frontmatter before treating a doc as guidance. `current` and `active` docs are operational guidance. `accepted` ADRs are decision records, not current implementation instructions unless paired with a current/active guidance source. `superseded`, `rejected`, and `archived` docs are historical only; follow `superseded_by` or `current_guidance`.
- Plan docs reference their ADRs, and ADRs reference the plan docs that prompted them. Prefer Markdown-relative links for in-repo docs.
- Small one-off fixes do not need a plan or ADR.
- If you read `README.md`, stop and read this file before continuing. `README.md` is a sub-1 minute human-facing intro and is not the source of truth for repo conventions.
- `AGENTS.md` should contain durable conventions only. Do not add one-off session notes.

## Common Commands

- Preview managed state: `chezmoi diff`, `chezmoi status`, `chezmoi apply --dry-run --verbose --exclude=scripts`.
- Render package input: `scripts/packages/render-brewfile --profile core|full`.
- Package/app audits: `scripts/audit/brew-inventory.sh`, `scripts/audit/brewfile-usage.sh`, `scripts/audit/app-inventory.sh`.
- Docs lifecycle checks: `make test-docs-lifecycle` and `docs/validate-doc-lifecycle --base-ref origin/master`.
- Fresh-shell checks: `scripts/audit/zsh-fresh-shells.zsh verify` and `bench`.
- Test index: `tests/README.md`.
- Tart local install lane: `docs/runbooks/tart-mini-validation.md`.
- Worktree workflow: `home/dot_agents/docs/worktrees.md`.
- Git/commit workflow: `home/dot_agents/docs/git.md`.
- Mise config: never edit `home/.config/mise/config.toml`; add entries to `home/dot_config/mise/conf.d/*.toml`.

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

Glossary:

- `modify_` prefix: chezmoi template files that modify existing target files, such as plist merge stubs.
- `chezmoiexternal`: external source declarations fetched by chezmoi rather than stored directly under `home/`.
- `chezmoiignore`: machine-aware exclusion rules for optional or host-local targets.
- `chezmoidata`: committed structured inputs for templates, packages, secrets, and licenses.
- `chezmoiassets`: non-templated payloads loaded with `include`, not `includeTemplate`.

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

## Rules Hygiene

Add a root rule only when it is non-obvious, repeatedly encountered, and specific enough to change future agent behavior. Put procedural detail in a skill or focused doc. No drive-by additions.

## Dependency And Tooling Gotchas

- Python imports must be declared in `pyproject.toml`; add stubs and build-system dependency mirrors when typecheck/build rules need them.
- For skill-creator eval review (the human-review HTML over an iteration directory), default to `scripts/eval-review.py`. Use the canonical skill viewer (`generate_review.py`) only if the user explicitly asks for it.
- After editing a skill, validate it. Frontmatter/parser drift has bitten this repo before.
- If CI says to run the build file generator and provides a diff, apply that diff exactly when local generation is blocked by auth/network/private module issues.
- Use `git diff --check` before handoff on non-trivial docs or code changes.
