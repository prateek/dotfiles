---
status: archived
doc_type: plan
owner: Prateek
created: 2026-06-29
updated: 2026-06-30
closed: 2026-06-30
current_guidance: ../../home/dot_agents/docs/worktrees.md
related:
  - ../../home/dot_agents/docs/worktrees.md
  - ../../home/dot_agents/docs/git.md
  - ../references/grmrepo.md
status_detail: "Closed 2026-06-30; implemented and committed. Orca-only: worktrunk + custom grm (incl. the bin/gh shim) removed, repo-index kept, root orca.yaml added, docs rewritten, github-pr-review-setup migrated to ohc. Current guidance is worktrees.md + git.md. Orca app settings (workspaceDir, keybindings) are owned by the sibling Orca app-config plan. Deferred (not in this repo): upstream Orca PR for org-aware nesting. No ADR."
---

# Worktree Convention Cleanup Plan

## Context

The dotfiles document and ship a Worktrunk-based worktree workflow
([worktrees.md](../../home/dot_agents/docs/worktrees.md),
[git.md](../../home/dot_agents/docs/git.md): "Prefer worktree-first workflow via
`w`"). The actual worktrees on both machines are Orca worktrees. The documented
Worktrunk root, `~/code/wt`, is absent on both machines.

This plan makes Orca the only worktree system, removes the custom grm refresh
path, and leaves the filesystem-based repo index in place.

## Decision

Use Orca for all worktree creation and management.

- Remove Worktrunk: the `w`/`wta`/`wtn` wrappers, the `wt` tool, its config, and
  its hook.
- Remove the custom grm integration, including `bin/gh`. That wrapper only
  exists to run grm refreshes after selected `gh` commands.
- Keep `repo-index` unchanged. It scans the filesystem under `~/code/github.com`
  and does not depend on grm.
- Standardize on `~/code/worktrees/<repo>/<name>` on both machines. The root is
  Orca's `workspaceDir`, set to `~/code/worktrees` by the sibling Orca app-config
  plan (below). This plan depends on that rather than shipping its own layout
  enforcement.
- Open an upstream Orca PR for org-aware nesting:
  `~/code/worktrees/<org>/<repo>/<name>`. Adopt that layout after Orca supports
  it.

Related work — Orca app settings. A sibling plan,
`~/.claude/plans/valiant-kindling-llama.md` ("Maintain Orca app config in
dotfiles"), version-controls the `settings` slice inside `orca-data.json` with the
repo's Yojam `modify_` deep-merge pattern: an allowlist of non-default keys (23
shared base + a per-`machine_type` overlay), a `semantic_equal` no-op guard, and
cask-gating, applied with Orca quit. Its base fragment includes
`workspaceDir: ~/code/worktrees`, and it also commits `~/.orca/keybindings.json`.
So the worktree-root layout and keybindings are owned there; this plan covers the
worktrunk/grm removal, `orca.yaml`, and the worktree workflow, and relies on that
plan for the Orca settings.

No ADR is planned. This plan and the `worktrees.md` rewrite carry the convention.

## Why It Is Feasible

`bin/gh` is only a grm shim. It finds the real `gh`, passes arguments through,
and starts `grmrepo-refresh` in the background after successful `gh repo clone`
or `gh repo create` commands. Its header mentions possible multi-account
routing, but the current behavior is pass-through plus grm refresh. Removing grm
removes the reason for `bin/gh` and `~/bin/gh`.

`repo-index` is independent of grm. `bin/repo-index` scans
`~/code/github.com/<owner>/<repo>` directories that contain `.git`, then emits
TSV rows with `<owner/repo>\t<https_url>\t<local_path>`. It does not read grm
config. `repo_select`, `url_select`, and the Hammerspoon switcher keep using
that index. `ghc` still clones into `~/code/github.com`, so the index keeps
populating.

The Orca path can be set from the CLI. In Orca upstream `main`,
[`computeWorktreePath`](https://github.com/stablyai/orca/blob/ab1aac2bda4e3b95fb0e9c850f1562ad4145df96/src/main/ipc/worktree-logic.ts#L84)
builds `<workspaceRoot>/<repo>/<name>` when `nestWorkspaces` is enabled.
`workspaceRoot` comes from per-repo `worktreeBasePath`, then falls back to the
global `workspaceDir`. Setting `--worktree-base-path ~/code/worktrees` per repo
yields `~/code/worktrees/<repo>/<name>` on both machines.

Org-aware nesting belongs upstream. `computeWorktreePath` builds
`<root>/<repo>/<name>` with `repo = basename(repoPath)`. It has no owner or org
segment and no path template. Adding `<org>` requires an Orca change.

## Findings

The investigation covered this laptop directly and the m4mini through
`orca --environment m4mini`.

| | This laptop (work, user `prungta`) | m4mini (user `prateek`) |
| --- | --- | --- |
| Real worktree root | `~/code/worktrees/<repo>/<name>` | `~/orca/workspaces/<repo>/<name>` |
| Created / managed by | Orca | Orca |
| `~/code/wt` (documented root) | absent | absent |
| `~/.config/git/config.local` | present (hooksPath + chronosphere `insteadOf`) | absent |
| Global `worktree.*` / `extensions.worktreeConfig` | none | none |

The machines differ only in Orca's local base-path setting. Set the per-repo
base path to `~/code/worktrees` on both.

## What Changes

### Worktree actions: committed `orca.yaml`

Orca reads a committed `orca.yaml` at a repo's root
([`parseOrcaYaml`](https://github.com/stablyai/orca/blob/ab1aac2bda4e3b95fb0e9c850f1562ad4145df96/src/main/hooks.ts#L80);
[recognized keys](https://github.com/stablyai/orca/blob/ab1aac2bda4e3b95fb0e9c850f1562ad4145df96/src/main/hooks.ts#L142):
`scripts`, `issueCommand`, `defaultTabs`). It is the committed, team-shared source
for per-worktree actions, gated by a one-time trust prompt per machine. This is the
home for the per-worktree setup the worktrunk hooks used to do: commit one at the
dotfiles repo root and it applies to every dotfiles worktree on every machine,
because it ships in the repo. (`.orca/` in a repo holds per-user local overrides
such as `issue-command`.)

The full supported schema, with every key:

```yaml
# orca.yaml — committed per-repo Orca config, at the repo root
scripts:
  # runs after a worktree is created; env includes $ORCA_WORKTREE_PATH and $ORCA_ROOT_PATH
  setup: |
    mise install
    direnv allow
  # runs before a worktree is archived/removed
  archive: |
    echo "archiving $ORCA_WORKTREE_PATH"
# optional: command Orca runs to pull issue context when seeding a worktree from an
# issue (Orca supplies the issue reference; per-user override: .orca/issue-command)
issueCommand: gh issue view --json title,body
# terminal tabs opened in a new worktree; title/command optional, color = 3- or 6-digit hex
defaultTabs:
  - title: agent
    command: claude
    color: "#7c3aed"
  - title: dev
    command: just dev
  - title: shell
```

That is the entire surface —
[`parseOrcaYaml`](https://github.com/stablyai/orca/blob/ab1aac2bda4e3b95fb0e9c850f1562ad4145df96/src/main/hooks.ts#L80)
keeps only `scripts.{setup,archive}`, `issueCommand`, and `defaultTabs[]` of
`{title?, command?, color?}` (color must match `^#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?$`).
`orca.yaml` does not set the worktree location — its schema has no path, layout, or
base-path key. Layout is handled below.

### Worktree layout: set via the Orca settings fragment

The worktree root is Orca's
[`workspaceDir`](https://github.com/stablyai/orca/blob/ab1aac2bda4e3b95fb0e9c850f1562ad4145df96/src/shared/types.ts#L2421),
a global setting inside the state blob at
`~/Library/Application Support/Orca/orca-data.json`
([persistence.ts](https://github.com/stablyai/orca/blob/ab1aac2bda4e3b95fb0e9c850f1562ad4145df96/src/main/persistence.ts#L310)).
The sibling Orca app-config plan manages this slice with a Yojam-style `modify_`
deep-merge and sets `workspaceDir = ~/code/worktrees` in its base fragment, so the
root is unified across machines from there — this plan ships no separate layout
mechanism.

Both machines already use the global `workspaceDir` (no per-repo `worktreeBasePath`
overrides exist, per `orca project setups`), and `nestWorkspaces` is on by default,
so the result is `~/code/worktrees/<repo>/<name>` through Orca's UI, `ohc`, or
`orca worktree create`. (This supersedes an earlier idea of a per-repo
`--worktree-base-path` apply-script plus an `ohc` base-path change; neither is
needed once the global `workspaceDir` is managed.)

The fragment takes effect wherever `chezmoi apply` runs with Orca quit. The m4mini
is chezmoi-managed, so the `workspaceDir` change lands there on the next apply (with
Orca quit), the same as on the laptop.

### User-global Orca config: `~/.orca/`

Some user-global Orca config lives as standalone files under `~/.orca/`, outside the
blob. The portable one is
[`~/.orca/keybindings.json`](https://github.com/stablyai/orca/blob/ab1aac2bda4e3b95fb0e9c850f1562ad4145df96/src/main/keybindings/keybinding-file.ts#L25)
(schema: `version`, `keybindings`, `platforms.{darwin,linux,win32}`). The sibling
Orca app-config plan commits it at `home/dot_orca/keybindings.json` (cask-gated), so
this plan does not — noted here only to complete the picture.

The other `~/.orca/` files stay unmanaged — machine-specific or secret:
`linear-token.enc` (encrypted token), `linear-viewer.json` (account cache), and
`agent-hooks/` (runtime endpoints and tokens).

### Worktrunk

Delete `home/dot_config/zsh/autoload/{w,wta,wtn}`, `extra/worktrees.zsh` (`wsc`),
the worktrunk config (`home/dot_config/worktrunk/config.toml`), `bin/wt-hook-sparse`
+ its symlink stub (`home/bin/symlink_wt-hook-sparse.tmpl`), the `worktrunk`
Brewfile entry (`home/.chezmoidata/packages.toml:38`), and
`tests/e2e-worktrees.zsh` (it tests `w` +
Worktrunk hooks; Orca owns creation now, so drop the test and record the
coverage change).

### grm

Remove the grm surface:

- `bin/grmrepo`, `bin/grmrepo-refresh` + their symlink stubs
  (`home/bin/symlink_grmrepo.tmpl`, `symlink_grmrepo-refresh.tmpl`).
- `home/.chezmoiassets/grm/*.toml`, `home/dot_config/grm/config.toml.tmpl`, and
  the host-local grm lines in `home/.chezmoiignore` (10–11).
- `home/dot_config/zsh/lib/grmrepo.zsh`, the `grmrepo` skill, `tests/grmrepo-refresh.zsh`.
- `bin/gh` + `home/bin/symlink_gh.tmpl` (pure passthrough once the refresh is
  gone; use real `gh` directly), and the guarded `grmrepo-refresh` call in
  `home/dot_config/zsh/autoload/ghc` (66–67).
- The `grm`/git-repo-manager package entry, wherever it is declared.
  `packages.toml` does not declare it; it is likely a manual Homebrew install.
  Use `rg git-repo-manager` to confirm.
- Close [grmrepo.md](../references/grmrepo.md) as `superseded`/`archived` with
  `current_guidance`.

**Keep** `bin/repo-index` + `home/bin/symlink_repo-index.tmpl` and
`tests/repo-index.zsh` unchanged. It is filesystem-based and the pickers depend
on it.

### `ohc` and `ghc`

`ohc` (`ghc clone`, then `orca repo add`, then `orca worktree create`) stays as the
create path. The only change here is dropping the now-removed `grmrepo-refresh` call
from `ghc`. No `--worktree-base-path` change is needed — the global `workspaceDir`
from the sibling plan's fragment already places worktrees at `~/code/worktrees`.

### Docs and Pointers

- Rewrite worktrees.md to Orca-only (create via Orca/`ohc`, the
  `~/code/worktrees/<repo>/<name>` layout, the org-nesting followup).
- [git.md](../../home/dot_agents/docs/git.md): reword "Defaults" + "Validation
  checklist" off `w`; remove the "Use the `gh` wrapper" section and point to
  real `gh`.
- [AGENTS.md:57](../../AGENTS.md) + `home/dot_agents/AGENTS.md` pointers.
- `tests/README.md` + `docs/index.md`; both skill references were ours (local):
  `github-pr-review-setup` is migrated from worktrunk to `ohc` (its script now
  creates an Orca worktree via `ohc`, then `gh pr checkout`s the PR into it, with
  `--checkout-mode inplace` as the non-Orca fallback); `repo-guideline-site`'s
  `worktrunk-patterns.md` only cites Worktrunk.dev as a docs-site design exemplar,
  so it is left as-is.

## Change list (by area)

- **Remove worktrunk**: `w`/`wta`/`wtn`, `extra/worktrees.zsh`, worktrunk config,
  `wt-hook-sparse` + stub, `worktrunk` Brewfile entry, `tests/e2e-worktrees.zsh`.
- **Remove grm**: `grmrepo`, `grmrepo-refresh` + stubs, grm config
  (`.chezmoiassets/grm/*`, `dot_config/grm`, `.chezmoiignore` 10–11),
  `lib/grmrepo.zsh`, grmrepo skill, `tests/grmrepo-refresh.zsh`, `bin/gh` +
  `symlink_gh.tmpl`, the `ghc` refresh call, the grm package entry; close
  `grmrepo.md`.
- **Keep unchanged**: `repo-index` (+ stub + test), `ghc` (minus the refresh
  call), the repo pickers.
- **Orca config (this plan)**: commit a root `orca.yaml` for per-worktree
  setup/archive (and optionally `defaultTabs`), replacing the worktrunk hooks.
- **Orca config (sibling plan, depended on)**: the `workspaceDir = ~/code/worktrees`
  layout root and `home/dot_orca/keybindings.json` are owned by the Orca app-config
  plan (`~/.claude/plans/valiant-kindling-llama.md`); no layout apply-script or
  `ohc` base-path change here.
- **Docs**: worktrees.md rewrite, git.md cleanup including removal of the
  gh-wrapper section, both AGENTS.md files, tests/README, docs/index.md.
- **Followup (separate repo)**: upstream Orca PR for org-aware nesting.

## Migration and cutover

The change is forward-only. The `workspaceDir` setting (from the sibling plan) and
the removal of worktrunk and grm affect new worktrees and new shells. They do not
move existing worktrees or stop running agents. So the cutover drains; it does not
migrate.

Existing worktrees:

- This laptop already creates worktrees at `~/code/worktrees/<repo>/<name>`, the
  target layout. No action, except one straggler at
  `~/orca/workspaces/monorepo/matched-writes-doc` that can drain or be removed
  when its work lands.
- The m4mini has every worktree under `~/orca/workspaces/<repo>/<name>`. Leave
  them in place. As each branch merges or closes, remove it the normal way
  (`orca worktree rm` / `git worktree remove`). New worktrees land at
  `~/code/worktrees`. Delete `~/orca/workspaces` once it empties.
- Do not bulk `git worktree move`. Orca keys worktree identity — and the attached
  agent sessions, comments, and lineage — on the path. Relocating out from under
  Orca orphans that state. Move a single long-lived worktree only when needed,
  with `git worktree move` plus a re-point or recreate in Orca, and only when no
  agent is attached.

Running agents:

- Removing worktrunk, grm, and `bin/gh` does not delete worktree directories or
  stop agent panes. `repo-index` stays, so the pickers keep working.
- Shells already running have the `w`/`wta`/`wtn` autoloads and `grmrepo.zsh`
  loaded; removal only affects new shells. In-flight agents finish on their
  current shell, and nothing they need for an existing worktree disappears
  mid-task.
- One footgun: after `chezmoi apply` removes `~/bin/gh`, a shell that already
  hashed `gh` can report `command not found` until `hash -r` or a new shell. Real
  `gh` resolves after that. If an agent is mid-`gh` work, apply after it idles.

Sequencing:

- Land this branch, then `chezmoi apply` per machine when no agent is mid-task
  that calls `w` / `wt` / `gh repo clone`. Follow the rollout order (grm first,
  then the root standardization, then worktrunk).
- Other in-flight dotfiles worktree branches keep the old `w` and grm files until
  they pick up master. That divergence is expected and harmless.

## Testing plan

- `make test-docs-lifecycle` (plan + index + grmrepo.md closure; links).
- Remove `tests/e2e-worktrees.zsh` + `tests/grmrepo-refresh.zsh`; confirm
  `tests/README.md` and any runner stop referencing them. `tests/repo-index.zsh`
  stays green (unchanged).
- Fresh-shell checks (`scripts/audit/zsh-fresh-shells.zsh verify` / `bench`) after
  removing the `w` family + grm lib + `gh` wrapper; confirm no dangling alias /
  fpath / `command -v` path and that `repo_select` / `url_select` still load and
  that real `gh` resolves on PATH.
- chezmoi dry-run for affected machine types (symlink stubs, Brewfile, grm config,
  worktrunk config, `.chezmoiignore` all change), with `MISE_TRUSTED_CONFIG_PATHS`.
- Manual on both machines: create a worktree via `ohc`, confirm it lands at
  `~/code/worktrees/<repo>/<name>`; run a repo picker; run `gh repo view` to
  confirm plain `gh` works.

## Rollout order

1. Remove the grm surface (+ `bin/gh` + the `ghc` refresh call); close grmrepo.md.
   Leave `repo-index` and the pickers untouched.
2. Commit a root `orca.yaml` for per-worktree setup/archive (replacing the
   worktrunk hooks). Coordinate with the sibling Orca app-config plan for the
   `workspaceDir = ~/code/worktrees` root and `~/.orca/keybindings.json`; apply on
   both machines with Orca quit, trust the `orca.yaml` once per machine, and verify
   that worktrees land at `~/code/worktrees/<repo>/<name>` and the hooks run.
3. Remove the worktrunk surface (`w` family, config, hook, Brewfile entry, e2e
   test) with fresh-shell + dry-run validation.
4. Rewrite worktrees.md + git.md; sync both AGENTS.md files, skills,
   tests/README, docs/index.md.
5. Separately: open the upstream Orca PR for org-aware nesting; adopt when it
   ships.

## Orca configuration surface (reference)

Where Orca keeps each kind of config (pinned to orca `main` at `ab1aac2`):

- **Per-repo, committed — `orca.yaml`** (repo root): worktree hooks and defaults
  (`scripts.setup`, `scripts.archive`, `issueCommand`, `defaultTabs[]`). Parsed by
  [`parseOrcaYaml`](https://github.com/stablyai/orca/blob/ab1aac2bda4e3b95fb0e9c850f1562ad4145df96/src/main/hooks.ts#L80);
  [recognized keys](https://github.com/stablyai/orca/blob/ab1aac2bda4e3b95fb0e9c850f1562ad4145df96/src/main/hooks.ts#L142).
  Trust-gated on first run.
- **User-global, committable — `~/.orca/keybindings.json`**
  ([keybinding-file.ts](https://github.com/stablyai/orca/blob/ab1aac2bda4e3b95fb0e9c850f1562ad4145df96/src/main/keybindings/keybinding-file.ts#L25)):
  keyboard-shortcut overrides (`version`, `keybindings`, `platforms.{darwin,linux,win32}`).
  A standalone file, not in the blob — committed by the sibling Orca app-config plan
  at `home/dot_orca/keybindings.json`. The other `~/.orca/` files are not
  committable: `linear-token.enc` (secret), `linear-viewer.json` (account cache),
  `agent-hooks/` (runtime endpoints/tokens).
- **Per-user, per-repo — `.orca/`** (repo dir): local overrides such as
  `.orca/issue-command`.
- **Global app state — `~/Library/Application Support/Orca/orca-data.json`**
  ([persistence](https://github.com/stablyai/orca/blob/ab1aac2bda4e3b95fb0e9c850f1562ad4145df96/src/main/persistence.ts#L310)):
  one blob holding GlobalSettings
  ([`workspaceDir` / `nestWorkspaces`](https://github.com/stablyai/orca/blob/ab1aac2bda4e3b95fb0e9c850f1562ad4145df96/src/shared/types.ts#L2421)),
  registered repos and project setups (per-repo `worktreeBasePath`, `hookSettings`,
  `externalWorktreeVisibility`), worktree metadata, agent sessions, saved remote
  environments (the m4mini), and credentials. Not committed wholesale, but its
  `settings` slice (the non-default keys, including `workspaceDir`) is enforced by
  the sibling Orca app-config plan via a Yojam-style `modify_` deep-merge applied
  with Orca quit. The rest changes only through the app or the `orca` CLI; never
  edit the blob by hand while Orca runs.
- **`orca` CLI (writes into the blob)**: `orca project setup-update
  --worktree-base-path`, `orca repo set-base-ref`, `orca worktree set`,
  `orca environment add`, automations. The supported way to script blob changes.
- **Environment variables — `ORCA_*`**: runtime and integration knobs
  (`ORCA_AGENT_HOOK_*`, `ORCA_CODEX_HOME`, `ORCA_BITBUCKET_*`,
  `ORCA_AZURE_DEVOPS_API_BASE_URL`, `ORCA_CLI_INSTALL_PATH`, dev `ORCA_DEV_*`). None
  set the worktree layout.
- **Setup-hook env**: `scripts.setup` runs with `$ORCA_WORKTREE_PATH` and
  `$ORCA_ROOT_PATH` set
  ([getSetupEnvVars](https://github.com/stablyai/orca/blob/ab1aac2bda4e3b95fb0e9c850f1562ad4145df96/src/main/hooks.ts#L411)).
- **Read but not owned by Orca** (external configs it imports or surfaces) — manage
  these in their own tools, not as Orca config:
  - Repo MCP: `.mcp.json`, `.cursor/mcp.json`, `.claude.json`, `.claude/mcp.json`
    (`mcpServers`); Orca surfaces them and masks secret `env`. Commit only if no
    secrets.
  - Agent skill dirs: `~/.agents/skills`, `~/.claude/skills`, `~/.codex/skills`, and
    repo `.agents|.claude/skills` — already managed here by `$agent-skill-management`.
  - `~/.ssh/config` (+ `Include`) and Ghostty config — imported for SSH hosts and
    terminal colors; owned elsewhere.
  - Third-party agent hook settings Orca writes managed entries into
    (`~/.claude/settings.json`, `~/.codex/...`, `~/.cursor/hooks.json`, Copilot,
    Gemini, Devin, Droid, Grok, Kimi, Hermes, amp): machine-specific / secret — do
    not commit.

Independently re-checked against orca `main` by a no-context `acpx agpt` research
pass: the only Orca-native, committable config files are `orca.yaml` (per-repo) and
`~/.orca/keybindings.json` (user-global). Everything else is either the per-machine
blob or external configs owned by other tools.

Takeaway: the committable Orca-native config is `orca.yaml` (this plan) and
`~/.orca/keybindings.json` (sibling plan). The worktree-root `workspaceDir` and the
other non-default `settings` keys are enforced by the sibling plan's `modify_`
deep-merge into the blob (applied with Orca quit); everything else in the blob
changes only through the app or the `orca` CLI.
