---
status: accepted
doc_type: adr
owner: Prateek
created: 2026-09-29
related:
  - 0011-private-repo-config-overlays.md
  - 0023-apm-agent-marketplace-packaging.md
  - 0040-devbox-machine-type.md
  - ../plans/linux-devbox-plan.md
  - ../references/agent-marketplace.md
---

# ADR 0039 — Work overlay lives in the work repo

## Context

[ADR 0011](0011-private-repo-config-overlays.md) put internal-but-not-secret
work content in a separate private repo, cloned on work machines and composed
into `~/.agents/docs/slack.md`. That repo only ever grew the Slack map. Then the
devbox work ([ADR 0040](0040-devbox-machine-type.md)) needed a work-specific
skill, the one that pairs desktop Orca with the devbox's headless server. The
devbox already reads a per-user directory in DAYJOB's work repo for its onstart
hook, and that repo is where work content gets reviewed. Two private homes for
the same kind of content is one too many.

The skill also needs a way to reach the agents. The published marketplace
(`prateek-local`, [ADR 0023](0023-apm-agent-marketplace-packaging.md)) is built
from this public repo, so work content can't go into it.

## Decision

1. **Source of truth.** Work overlay content lives in Prateek's user directory
   in the work repo. It holds `agents/docs/` fragments (the Slack map) and an
   `agent-plugins/` directory that is a hand-maintained native marketplace
   named `work-overlay`, with Claude and Codex catalogs and one `work` plugin.
2. **Fetch.** A gated git-repo external shallow-clones the work repo
   (`--depth 1 --single-branch --filter=blob:none --sparse`, weekly refresh,
   fast-forward pulls) to `~/.local/share/dotfiles/work-overlay`. Chezmoi can't
   pick the sparse directory, so `run_after_36a-work-overlay-sparse` runs
   `git sparse-checkout set` on the overlay directory before scripts 37 and 39. The repo URL, branch, and directory
   name DAYJOB, and this repo is public, so `.chezmoi.toml.tmpl` prompts for
   them on work machines and they live only in the rendered config as
   `[data.work_overlay]`. `home/.chezmoitemplates/work-overlay.tmpl` resolves
   the paths. The overlay is on when the `private_overlay` feature is on and a
   repo is set.
3. **Docs.** `run_onchange_after_37-agent-slack-doc` composes the public Slack
   base with `slack-*.md` fragments from the overlay's `agents/docs/`, and
   rehashes when they change.
4. **Skills.** `run_onchange_after_39-agent-work-overlay` runs the plugin
   reconciler's `--overlay` mode against the overlay marketplace. That mode
   reads the catalogs directly, with no build or receipt, refuses the
   `prateek-local` name, and installs each plugin, enabled, for the clients
   whose catalog lists it, beside `prateek-local`. The Claude, Codex, pi, and
   Cursor config templates register the marketplace and enable its plugins once
   the clone holds a catalog, taking every name from the reconciler's listing.
5. **Devbox.** The devbox reaches the same directory through the work repo's
   own sync, and its onstart hook there is a thin trampoline into
   `scripts/devbox/onstart` in this repo.

The private repo from ADR 0011 stays as a dormant placeholder for anything too
sensitive for the work repo. Nothing clones it.

## Consequences

- Work content has one home, reviewed where the rest of the work lives.
- Overlay skills reach Claude, Codex, and omp natively, with no copies under
  `~/.agents/skills` or `~/.claude/skills`. Cursor and pi read the marketplace
  from their config.
- A version bump in the overlay plugin's manifest refreshes the install on the
  next apply. The external refreshes weekly, or on
  `chezmoi apply --refresh-externals`.
- CI and non-work machines never see the overlay: the prompt runs only on work,
  and every consumer renders nothing when the repo is unset.
- An existing work Mac loses the Slack map silently until its config carries
  `[data.work_overlay]`. Cut over by adding that table to
  `~/.config/chezmoi/chezmoi.toml` (or re-running `chezmoi init --source
  ~/dotfiles`), applying twice (the first apply clones the overlay, the second
  registers its marketplace), then deleting the old
  `~/.local/share/dotfiles/private` clone by hand.
- Client configs name the marketplace and plugins from the overlay's Codex
  catalog, so renaming them in the work repo needs no change here.

## Alternatives considered

- **Keep the separate private repo and add skills to it.** Rejected: a second
  private home, and the devbox would need a second clone and credential.
- **Copy overlay skills into `~/.agents/skills`.** Rejected: script 35 owns that
  directory as an empty stub, and copies would bypass native install records.
- **Commit the work repo URL.** Rejected: it names the employer in a public repo.
