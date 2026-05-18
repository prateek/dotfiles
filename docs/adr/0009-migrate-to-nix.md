---
status: proposed
created: 2026-05-18
last-reviewed: 2026-05-18
owners: [prateek]
supersedes: [0006-chezmoi-migration-prototype.md]
---

# 0009. Migrate from chezmoi to Nix (home-manager + nix-darwin)

## Status

Proposed. Companion plan: [docs/dev/chezmoi-to-nix-plan.md](../dev/chezmoi-to-nix-plan.md).
Supersedes [ADR 0006](0006-chezmoi-migration-prototype.md) which adopted
chezmoi as the primary dotfiles engine.

## Context

We adopted chezmoi in ADR 0006 because it gave us templating, profiles,
script ordering, and a single `apply` verb. Over the last year the system
grew to ~1k files, ~25 chezmoi templates (`.chezmoitemplates/`), 10 ordered
`.chezmoiscripts/` lifecycle hooks, a custom `plist-merge` engine, a custom
sudo-keepalive library, custom apply pre/post hooks for cfprefsd, a custom
drift-banner watchdog, and several Python mergers for JSON / TOML. Most of
the bespoke layer exists to compensate for things chezmoi does not model.

Specific pain points:

1. **No atomic generations**. A chezmoi apply that fails mid-way leaves a
   partially-converged system; there is no `rollback` verb.
2. **Script ordering is filename-based**. The
   `run_once_before_05-core-tools.sh.tmpl` / `run_onchange_after_10-…`
   convention is fragile; reordering means renames across CI.
3. **Plist management is per-file bespoke**. Each `modify_` stub forwards
   to a shared merger, but the desired-fragment files are hand-authored
   plists with Go-template escaping rules — and we already had to special-case
   Moom's geometry strings.
4. **Secrets gating is opaque**. `secrets_enabled` is a boolean prompt that
   threads through `.chezmoiignore`, `licenses.toml`, and per-file template
   guards. Every secret-backed file is a new private template plus an
   `op://` ref plus a `.chezmoiignore` rule.
5. **CI tests the renderer, not the system**. `chezmoi apply --dry-run`
   tells us the templates parse — it does not tell us the resulting
   system would build.

## Decision

Migrate to:

- **Nix Flakes** as the configuration entry point and lock file.
- **nix-darwin** as the macOS system-config layer (replacing
  `macos-defaults.sh.tmpl`, `pmset`/`nvram`/`systemsetup` calls, and the
  Homebrew bundle).
- **home-manager** as the user-config layer (replacing every
  `home/dot_*` chezmoi target).
- **1Password CLI (`op`) at activation time** as the secrets resolver —
  same `op://` refs we have today, executed by a nix activation hook
  instead of a chezmoi template, gated on `profile.secrets.enabled`.

Keep:

- `scripts/macos/plist-merge` (uv script) for partial-merge plists.
  nix-darwin's `system.defaults.CustomUserPreferences` does full
  overwrites and would clobber runtime-managed keys (Raycast's commands
  list, Tailscale connection state, BetterTouchTool config blob).
- `home/dot_agents/packages/**` + the existing
  `render-agent-{core-skills,plugin-marketplace}` Python renderers.
  Invoked as a home-manager activation hook with a content-hash gate.
- The chezmoi-named source files in `home/` as the content store
  referenced by nix modules. Leaf-level chezmoi prefixes (`dot_zprofile`,
  `dot_zshrc` inside subdirs) are renamed where home-manager would
  otherwise materialize a literally-prefixed name.

Drop:

- `home/.chezmoi*` (root, ignore, toml.tmpl, external.toml.tmpl).
- `home/.chezmoidata/`, `home/.chezmoiscripts/`, `home/.chezmoitemplates/`
  (the templates referenced from the source tree are migrated to plain
  files or to nix derivations; the templating-only ones are deleted).
- `scripts/chezmoi/` (the dry-run validator and any other chezmoi shims).
- The chezmoi-specific test files under `tests/` (`chezmoi-config.zsh`,
  `chezmoi-drift-banner.zsh`, `chezmoi-local-ignores.zsh`,
  `chezmoi-script-status.zsh`).

## Consequences

**Positive:**

- Atomic activations; `darwin-rebuild --rollback` works.
- A single source of truth (`flake.nix` + the host config) replaces the
  chezmoi data file + multiple template fragments.
- Type-checked configuration via the nix module system.
- The Brewfile rendering, profile selection, MAS opt-in, license gating,
  zinit external clone, and Mac App Store opt-in collapse into module
  options on a host config — easier to discover than scattered
  `DOTFILES_*` env vars.
- CI can run `nix flake check` (fast) and `darwin-rebuild build`
  (Mac-only) for a much stronger guarantee than `chezmoi apply --dry-run`.

**Negative / risk:**

- Initial install bar is higher: nix-darwin requires nix already
  installed on the Mac. We add a brief bootstrap in `README.md`.
- Nix learning curve for anyone reading the configs. We mitigate by
  keeping module options short and naming them after the chezmoi
  equivalents (e.g. `profile.installXcode` matches `DOTFILES_INSTALL_XCODE`).
- The nix-darwin homebrew module is not 100% feature-complete vs.
  the Brewfile spec (e.g. per-cask `appdir` is supported, per-formula
  `link = false` is supported, but obscure flags may need raw text).
  We accept this risk and document any gaps as `# TODO(nix)` in the
  homebrew module.
- The agent-skills surface remains rendered by external Python scripts.
  This is "less pure" than a derivation, but the alternative is rewriting
  ~600 lines of Python in nix builtins. Not worth it.
- Two-step install for plists requiring partial merge: nix-darwin emits
  the desired fragment to the nix store, an activation script reads it
  back and calls `plist-merge`. Slightly slower than the chezmoi
  `modify_` stub but identical semantics.

**Operational:**

- Anyone migrating a machine must run nix-darwin's installer first, then
  `darwin-rebuild switch --flake github:prateek/dotfiles#prateek-mac`.
- The chezmoi drift banner is removed. We can re-add a `darwin-rebuild
  --dry-run` based banner if the absence is felt.
- The `bin/dotfiles` wrapper was already removed (see
  ADR 0001 / `home/.chezmoidata/apps/*.toml` retirement); nothing
  additional to remove there.

## Rollout

See [chezmoi-to-nix-plan.md](../dev/chezmoi-to-nix-plan.md) for the
Phase 0-4 plan. This ADR is **Phase 0** (scaffolding, unvalidated).
Approval at Phase 1 (clean build on a real Mac) flips the status to
`accepted` and the prior chezmoi ADRs to `superseded`.

## Alternatives considered

- **Stay on chezmoi**: rejected. The bespoke layer keeps growing; each
  new app config adds a `modify_` stub, a template fragment, a
  `.chezmoiignore` rule, and a test. The system has reached the
  complexity where a more disciplined tool pays for itself.
- **Stow + Makefile + ad-hoc scripts**: rejected. Loses templating and
  the package surface entirely.
- **home-manager standalone (no nix-darwin)**: rejected. Would leave
  `macos-defaults.sh.tmpl` and the plist merging without a clean home,
  defeating much of the benefit.
- **Devbox / mise as the package layer**: rejected. mise is already
  doing developer-runtime work and we keep it for that; system packages
  (brew, casks, MAS) want a higher-throughput install surface.
- **sops-nix for secrets**: rejected for now. The user already has
  1Password CLI signed in across machines; switching to age/sops keys
  for files that are read once at apply time is more friction than the
  reproducibility gain. Revisit if we ever want fully offline activation.
