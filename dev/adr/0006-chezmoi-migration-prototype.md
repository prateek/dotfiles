# ADR 0006 — Chezmoi migration target architecture

- Status: Accepted
- Date: 2026-04-26
- Deciders: Prateek
- Related: [../docs/chezmoi-migration-plan.md](../docs/chezmoi-migration-plan.md)
- Related ADR: [0004-tart-install-validation-and-tracing.md](0004-tart-install-validation-and-tracing.md)

## Context

This repo is conventionally checked out at `~/dotfiles`. The current install path mixes package installation, symlink management, shell setup, and macOS/app side effects in custom scripts.

chezmoi can manage home-directory source state, templates, private files, scripts, and machine-local config. Its default source location is not a good fit for this repo because the repo itself is the durable source of truth and many local scripts already assume `~/dotfiles`.

The target architecture should make chezmoi own real source-state files where possible and reserve live links for repo-local executable wrappers that must run directly from the checkout.

## Decision

Keep the canonical checkout at `~/dotfiles`.

Use `.chezmoiroot` with the value `home`, so chezmoi reads source state from:

```text
~/dotfiles/home/
```

Repo tooling, plans, tests, scripts, reference docs, and package manifests stay outside `home/`.

Use native chezmoi source-state naming in `home/`:

- `dot_` for dotfiles;
- `private_` for private targets;
- `executable_` for executable targets;
- `.tmpl` only for host, OS, path, feature, or secret variation;
- `symlink_` only for deliberate live links, primarily repo-local executable wrappers.

Keep app/defaults/license/permission intent in `home/.chezmoidata/` so chezmoi templates and scripts can consume one structured data model. Chezmoi may materialize stable target files directly. Raw captures, rollback records, generated inventories, and other machine-local observations stay outside the repo under XDG state.

Agent tool homes (`~/.agents`, `~/.codex`, and `~/.claude`) are managed as rendered source state under `home/`, not repo-root live-link trees. Local volatile state for those tools stays out of the repo.

Plain `chezmoi apply` may run idempotent `.chezmoiscripts` for safe home-environment setup such as packages, shell dependencies, mise runtimes, and verification. Higher-risk app/default/license/permission mutations still belong behind explicit data gates and the transaction-aware `dotfiles apply <scope>` commands.

Update, 2026-04-27: the target architecture merges `bootstrap.sh` into a tiny `install.sh`. `install.sh` prepares Xcode Command Line Tools, Homebrew, Git, and chezmoi, then hands off to `chezmoi init --apply`. Ongoing setup moves into `.chezmoiscripts` and `.chezmoiexternal.*`.

## Consequences

### Positive

- The repo keeps its `~/dotfiles` convention.
- Chezmoi source state is readable and testable as source state, not a separate symlink descriptor layer.
- Repo-only material stays outside chezmoi's home target mapping.
- Desired app/system declarations use chezmoi's native data mechanism instead of a parallel repo control plane.
- Isolated HOME/XDG tests can exercise `chezmoi init`, `apply`, and `status`.
- Tart remains the clean macOS install proof path for bootstrap, package, shell, and macOS baseline changes.
- App/system mutations can be handled with stricter safety rules than ordinary dotfiles.

### Negative

- Moving files into native chezmoi source-state names creates more churn than linking existing repo paths.
- Temporary research files are not durable source state.
- App/defaults handling needs local transaction and rollback design before it replaces existing scripts.

### Neutral

- Package installation, advanced app/system data, license automation, and permissions are phased work.
- Selected live links remain acceptable for repo-local wrappers.

## Revisit Criteria

Re-open this ADR if any of these happen:

- the repo moves away from the `~/dotfiles` checkout convention;
- `.chezmoiroot = home` blocks a real migration requirement;
- the `dotfiles` CLI takes over enough behavior to need a separate architecture ADR;
- app/system data handling moves into a dedicated tool or separate repository.
