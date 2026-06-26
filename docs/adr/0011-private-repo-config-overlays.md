---
status: accepted
doc_type: adr
created: 2026-06-26
owner: Prateek
related:
  - 0006-chezmoi-migration-prototype.md
  - 0010-machine-type-package-selection.md
  - ../references/chezmoi-architecture.md
status_detail: "Accepted and implemented on the prateek/slack-conventions branch; first consumer is ~/.agents/docs/slack.md."
---

# ADR 0011 — Private repo for config overlays

## Context

`prateek/dotfiles` is a **public** repo. Some managed config needs internal or
work-specific content that must not be published: e.g. `~/.agents/docs/slack.md`
wants a Chronosphere channel/people/routing map (channel IDs, employee names,
internal hostnames). The old `slack.md` already shipped ~30 internal channel IDs.

Two existing mechanisms each cover part of the need but not this case:

- **1Password via `op://`** (`secrets_enabled` + `private_*.tmpl`,
  [ADR 0006](0006-chezmoi-migration-prototype.md)) — for *secret values*. Renders
  into a single file natively, but 1Password gives no git history/diffs/PRs.
- **Host-local `*.local` files** (`.zprofile.local`, `.config/grm/config.local.toml`,
  gated in `.chezmoiignore`) — for *machine-specific* content. Lives only in
  `$HOME`, so it has no version control either.

The slack map is internal-but-not-secret, wants real version control, and should
land in the **single** file the agent already reads — none of the above delivers
all three.

## Decision

Introduce a separate **private git repo** (`prateek/dotfiles-private`) as the
version-controlled source of truth for internal/work overlay content, and
**compose** it into the public-generated artifact at apply time. Three pieces:

1. **Source of truth** — `prateek/dotfiles-private` holds the internal fragment
   (e.g. `agents/docs/slack-chronosphere.md`). Private repo ⇒ git history, diffs,
   PRs, and access control, decoupled from the public repo.
2. **Fetch** — a gated `git-repo` entry in `home/.chezmoiexternal.toml.tmpl`
   clones it to `~/.local/share/dotfiles/private` (mirrors the existing zinit
   external). Gated directly on **`machine_type == work`** — no derived flag, no
   env var, no prompt — so `ci`/`personal`/`homelab` never reference the private
   repo. (chezmoi errors on missing data keys, so we gate on the long-standing
   `machine_type` rather than a freshly-added key, which would fail apply on any
   config rendered before this change.)
3. **Compose** — `home/.chezmoiscripts/run_after_37-agent-slack-doc.sh.tmpl`
   writes the single target `~/.agents/docs/slack.md` = public base
   (`home/.chezmoitemplates/agent-slack-base.md`, embedded via `includeTemplate`)
   plus the private fragment when present, else a pointer. The target is
   `.chezmoiignore`d so the script owns it.

The composer is a plain `run_after` (every apply), not `run_onchange`: the private
fragment lives on the target side (the cloned external) and cannot be hashed at
template-render time, so onchange would go stale after a private-repo refresh.

Fail-safe by construction: the CI smoke runs `chezmoi apply --dry-run
--refresh-externals=never`, and chezmoi's dry-run did not fetch the `git-repo`
external even with default settings (verified by forcing an SSH failure on the
`work` dry-run). So CI's `work` smoke and any fork render the base + pointer with
no access to the private repo.

## Consequences

- Internal-but-not-secret config gets real version control without leaking into
  the public repo, and renders into the one file the agent reads.
- A third overlay tier now exists, by content type:
  - secret values → 1Password `op://`,
  - machine-specific, no history needed → host-local `*.local`,
  - internal/work, version-controlled → **this** private repo.
- New apply-time dependency on a private repo, but scoped to `machine_type=work`
  and fail-safe everywhere else.
- The generated target is script-owned + ignored; edit the base in
  `.chezmoitemplates/` and the fragment in the private repo, never the rendered
  file.
- Capability gating moved onto `machine_type` (no env toggle), continuing the
  direction in [ADR 0010](0010-machine-type-package-selection.md) "Future work"
  (machine types composing non-package config).

## Alternatives considered

- **Commit the internal map to the public repo.** Rejected: leaks current-employer
  Slack structure and names; the status quo we are fixing.
- **Host-local file only** (`slack.local.md`, the first iteration). Rejected: no
  version control, and a second file the agent must know to read.
- **1Password secure note via `op://`.** Single-file native render and access
  control, but no git history/diffs — fails the version-control requirement.
- **`includeTemplate` an external into a templated doc.** Rejected: chezmoi can't
  reliably splice a target-side external into another file's template render
  (ordering/availability); the `run_after` composer is deterministic.

## Future work

- **Generalize to other overlays.** Candidate work-specific content (other agent
  docs, work-only tool config) could move to `dotfiles-private` the same way. Do
  it per-overlay: anything with secret values stays in 1Password; anything purely
  machine-local with no history need stays a `*.local` file. (Open: a clean rule
  for when a `*.local` should graduate to the private repo.)
- **Clarify the config-gating convention.** The repo now mixes three styles:
  `env | default` (`manage_zinit_external`), `env` + `promptBoolOnce`
  (`secrets_enabled`, `run_install_scripts`), and `machine_type`-gated (this
  overlay's `eq .machine_type "work"`). A short convention (role-derived vs
  first-run choice vs automation toggle) deserves its own note.
