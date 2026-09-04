---
status: active
doc_type: research
owner: Prateek
created: 2026-09-03
updated: 2026-09-03
related:
  - ../references/chezmoi-architecture.md
  - ../adr/0006-chezmoi-migration-prototype.md
  - ../adr/0010-machine-type-package-selection.md
  - ../adr/0012-config-gating-convention.md
  - ../plans/chezmoi-migration-plan.md
  - ../plans/test-suite-rebuild-plan.md
status_detail: "Survey plus adversarial cross-model review. Conclusion: no wholesale migration. A package-only nix spike is the open option; nix-darwin waits on a work-Mac MDM test."
---

# Migrating From chezmoi To Nix Flakes: What It Would Take

## Question

Would this repo be better off on nix flakes (nix-darwin plus home-manager)
than on chezmoi, and what would the move cost?

## Method

Two passes on 2026-09-03 against the `prateek/migrate-nix` worktree at
commit 2c488ce.

1. A survey of the chezmoi surface: source tree, templates, data, apply
   scripts, hooks, externals, tests, CI, and the decision records behind them.
2. An adversarial review of the survey's 29 claims by a second model (`agptx`
   through acpx, read-only, with shell and web access). Every claim it marked
   wrong was re-verified against the checkout before it landed here. The
   scorecard is in the appendix.

## What The Repo Is

| Surface | Count |
| --- | --- |
| Source files under `home/` | 1711 |
| Of those, agent skill packages under `home/dot_agents/` | 1498 |
| Templates | 91 |
| Templates left after removing apply scripts, plist fragments, licenses, symlink stubs | 35 |
| Templates that branch on role, OS, host, or features | 16 |
| `modify_` targets merging into app-owned files | 21 |
| Apply scripts | 24 (1125 lines) |
| Brew formulae / casks / MAS / taps declared | 148 / 59 / 6 / 29 |
| Tap-qualified formulae | 11 |
| Executable `defaults write` lines | 145 |
| Secret-backed targets (1Password refs) | 3 |
| Tracked test files / executable zsh tests / lines | 69 / 64 / 13,867 |
| Files mentioning chezmoi across `.agents/skills`, `tests/`, `scripts/` | 120 |
| Commits in the last 30 / 90 days | 54 / 151 |

Formulae are 146 `brews` entries plus 2 `xcode_required_brews`. Casks are 58
unique names; jump-desktop appears in two groups.

## Where The Complexity Lives

Templating is thin. Most of the tree is plain files, and most of those are
agent skill packages rendered into `~/.agents/plugins` by a Python renderer
and reconciled through `claude plugin` and `codex plugin`. The renderer is
portable. The apply script that wraps it is not, because it depends on
`.chezmoi.sourceDir`, `features.tmpl`, and chezmoi's onchange hashing.

The hard parts are:

- **Files the app also writes.** 21 merge targets: 12 preference plists, the
  nvALT color list, and 8 structured configs (Claude, Codex, pi, crit,
  agentsview, Orca, Yojam, obsidian-wiki). The shared engine at
  [`scripts/macos/plist-merge`](../../scripts/macos/plist-merge) preserves
  unmanaged keys and honors delete directives. A pre-apply hook
  ([`plist-hooks.sh`](../../scripts/chezmoi-hooks/plist-hooks.sh)) quits
  running apps before their plist is written and relaunches them after.
- **Side-effect reconcilers.** brew bundle, retired-package uninstall, fork
  swaps ([`reconcile-fork-installs`](../../scripts/packages/reconcile-fork-installs)),
  goku, Tuna reload, Raycast extension builds, launchd agents, wiki clone
  shape, plugin install records.
- **Elevation.** On the Jamf-managed work Mac, sudo-needing scripts first
  trigger a Self Service policy that grants admin for about an hour
  ([reference](../references/jamf-self-service-elevation.md)).
- **A Linux profile that owns almost nothing.** The work×linux DevPod runs one
  apply script; DAYJOB owns the image
  ([runbook](../runbooks/linux-work-devpod-orca.md)).

## How Each Piece Maps To Nix

| Today | Nix equivalent | Fit |
| --- | --- | --- |
| Five-layer resolver in [`features.tmpl`](../../home/.chezmoitemplates/features.tmpl), ignore-file gating, cask-enabled gate | Module system: per-host flake outputs, `mkIf`, typed options | Better. The resolver is consulted separately by the Brewfile, the cask gate, the ignore file, scripts, and tests today. |
| [`.chezmoiremove`](../../home/.chezmoiremove) | Generation diff removes links from prior home-manager generations | Better in steady state. It will not clean the pre-existing paths on the first switch; those need a one-time script. |
| 148 brew formulae | nixpkgs, pinned by `flake.lock` | Good. Coverage confirmed for goku, tart, xcodes, bun, terraform, sshpass, src-cli. Not found for mcptools, agent-safehouse, allium, imsg. |
| 59 casks, 6 MAS, Setapp | nix-darwin [`homebrew` module](https://nix-darwin.github.io/nix-darwin/manual/#opt-homebrew.enable) generating a Brewfile for `brew bundle` | Neutral. Homebrew stays installed. Three package managers: nix, brew, mise. |
| Plain config files | `home.file` links into the read-only store | Fine for files only we write. |
| 21 merge targets | No native primitive. Activation scripts calling the existing merge engine, or `mkOutOfStoreSymlink` | Worse. Store links break apps that rewrite their settings. Out-of-store links cannot roll back. home-manager [PR 9464](https://github.com/nix-community/home-manager/pull/9464) for merged mutable config was closed unmerged. |
| 145 defaults writes, PlistBuddy calls, sudo lines | nix-darwin `system.defaults` for common domains, `CustomUserPreferences` and `CustomSystemPreferences` for the rest; PlistBuddy and lsregister stay scripts | Mostly fine. No key removal ([issue 658](https://github.com/LnL7/nix-darwin/issues/658)), no quit-app guard. |
| `run_onchange` scripts | `home.file.<name>.onChange` for change-triggered work; activation blocks otherwise, which run on every switch | Fine. Scripts are already idempotent. |
| Plist quit/relaunch hook, drift banner | Custom activation script. The banner is already being replaced by fastfetch on branch `prateek/banner-fastfetch`. | Port or drop. |
| 3 secret-backed license files | `op inject` at activation, or sops-nix/agenix; or leave these three in chezmoi | Small. Pure evaluation cannot read from `op`. |
| zinit and private-overlay [externals](../../home/.chezmoiexternal.toml.tmpl) | Flake inputs | Different. Inputs are immutable store paths; zinit's self-update and the SSH-only private repo are not drop-in. |
| mise runtimes and `latest` AI CLIs | Keep mise ([ADR 0005](../adr/0005-mise-tool-management.md)) | Cadence tradeoff, not incompatibility. |
| zsh startup with custom `ZDOTDIR` | `programs.zsh.dotDir` plus ordered `initContent`, or `home.file` verbatim | Fine either way. |
| `chezmoi diff` and `status` | `nix build` plus `nvd`; activation repairs managed links | Narrower drift surface, not none. |
| Tart lane and CI dry-run | `nix build .#darwinConfigurations.<host>.system` on an arm64 `macos-latest` runner | Better for evaluation and closure failures. Does not exercise defaults, app writes, or activation. |
| Tests, two repo skills, ADRs 0006/0010/0012 | Rewrite the harness calls; keep the behavioral assertions | Moderate. The [test-suite-rebuild plan](../plans/test-suite-rebuild-plan.md) already says 16 tests survive intact and most others keep an invariant. |

## What Nix Would Fix Here

The survey first claimed package drift was not a live pain. It is.

- Commit 36c092b added a stale-fork report because an installed fork
  "silently missing merged PRs went unnoticed until a manual `brew outdated`".
- The `[packages.retired]` block in
  [`packages.toml`](../../home/.chezmoidata/packages.toml) and its apply
  script exist because `brew bundle` never uninstalls.
- The [migration plan](../plans/chezmoi-migration-plan.md) Rollback section
  states that package and runtime changes are not generally rollbackable.
- The machine-role resolver is hand-rolled and duplicated across consumers.
- zinit updates itself weekly from a mutable checkout rather than through a
  reviewed lock bump.
- CI renders templates but cannot build a dependency closure.
- The dev-deps note atop
  [`clis.toml`](../../home/dot_config/mise/conf.d/clis.toml) asks for a
  module system that gates installs by role.

A nix closure for the nixpkgs-covered formulae gives atomic generations,
rollback, one reviewed lock update, and a host output CI can build. That value
is real. It does not require handing nix the 21 co-owned files.

## What Nix Would Not Fix

- **GUI apps.** Casks, MAS, and Setapp remain Homebrew.
- **Co-owned app files.** The merge engine and the quit/relaunch guard stay,
  as activation scripts.
- **Side effects.** Reconcilers become activation scripts with the same logic.
- **The work Mac.** Installing nix needs root once: an APFS volume, a
  `synthetic.conf` entry, a `nix-daemon` launchd job, and build users
  ([Nix manual](https://nixos.org/manual/nix/stable/installation/installing-binary)).
  nix-darwin activation needs root on every switch
  ([announcement](https://github.com/nix-darwin/nix-darwin/issues/1457)).
  Standalone home-manager does not.
- **The Linux DevPod.** Single-user nix still needs a root-created `/nix`.

## Go/No-Go Checks

Nothing in the repo answers either question. Both need a test on the box.

1. **Work Mac.** Does the Jamf tenant allow the installer's volume, mount,
   daemon, and build users, and does the endpoint agent tolerate `/nix`? If
   not, the work profile stays chezmoi and any nix adoption means two systems
   for good.
2. **DevPod.** Can `/nix` exist on the DAYJOB image? If not, that profile
   stays chezmoi.

## Options

Ranked. The first is the default; each later one requires the previous to
have earned its keep.

1. **Stay on chezmoi** for files, mutable app config, secrets, and activation.
2. **Spike a flake-backed CLI closure.** Expose one
   `packages.aarch64-darwin.cli` derivation for the nixpkgs-covered formulae
   and install it with `nix profile`. Generate the list from `packages.toml`
   or the other way round, but do not run two machine resolvers. Success
   looks like: `nix profile rollback` works, CI builds the closure, and the
   brew formula list shrinks. No home-manager, no sudo.
3. **Standalone home-manager for `home.packages` only**, if the spike proves
   rollback and closure builds matter. Still no sudo per switch.
4. **nix-darwin**, only after the work-Mac check passes and only if
   declarative system defaults are worth root activation on every switch.

## Sizing

No measured basis; ranges only.

| Scope | Size |
| --- | --- |
| Option 2 spike | One or two evenings |
| Option 3, packages only | About a week part-time |
| Full cutover, all four options plus tests, skills, CI, Tart, docs | 4 to 8 weeks part-time |
| Ongoing after a full cutover | sudo per switch on work; two systems if work or Linux is excluded |

The expensive part of a full cutover is operational equivalence, not file
conversion: 21 mutable merges, quit/relaunch safety, retired-package cleanup
on the first switch, work-Mac privilege policy, defaults activation, and
checking real GUI behavior. The 1498 agent-package files are payload, not
conversion work. The test suite is cheaper than it looks because its
assertions target behavior and the harness calls are the only chezmoi-shaped
part.

## Appendix: Claim Scorecard

Verdicts from the adversarial review. Wrong and overstated rows were
re-checked against the checkout; the numbers above already carry the
corrections.

| ID | Survey claim | Verdict | Note |
| --- | --- | --- | --- |
| R1 | 1711 files, 1498 under dot_agents | Holds | 87.55% |
| R2 | About a dozen templates vary by machine | Overstated | 35 remain after exclusions; 16 branch on features |
| R3 | 21 merge targets | Holds | |
| R4 | 24 apply scripts, 1125 lines, idempotent | Holds | |
| R5 | 146 / 59 / 6 / 29 packages | Holds | Plus 2 xcode_required_brews; 58 unique casks |
| R6 | 147 defaults writes, 5 PlistBuddy, 9 sudo, 4 killall | Overstated | Comments counted; executable: 145 / 4 / 8 / 3 |
| R7 | 66 test files; tests are the largest cost | Wrong | 69 files, 64 zsh; rebuild plan says most survive |
| R8 | Plugin renderer ports unchanged | Overstated | Renderer yes, apply wrapper no |
| R9 | Four tapped formulae not in nixpkgs | Unverified | Absence not provable from search |
| R10 | No evidence drift is a live pain | Wrong | 36c092b, retired block, rollback section |
| R11 | Sudo keepalive triggers Jamf elevation | Holds | |
| R12 | DevPod runs one apply script | Holds | Plus a pre-source-state uv hook |
| R13 | Plist hook and drift banner need porting | Holds | Banner already replaced on an unlanded branch |
| R14 | 10 secret-backed targets | Wrong | 3 |
| N1 | Store links break co-owned files; no merge primitive | Holds | PR 9464 closed unmerged |
| N2 | CustomUserPreferences exists; no delete, no quit guard | Holds | |
| N3 | Homebrew module wraps brew bundle; three managers | Holds | |
| N4 | Activation replaces run_onchange via derivation change | Overstated | `onChange` is the analogue |
| N5 | Secrets need op-at-activation or sops/agenix | Overstated | Or leave the 3 files in chezmoi |
| N6 | Flake inputs replace externals | Overstated | Immutable; zinit and SSH repo not drop-in |
| N7 | Install needs root; darwin-rebuild needs sudo; HM does not | Holds | |
| N8 | MDM may block | Unverified | Test, do not assume |
| N9 | Linux needs root-created /nix | Holds | |
| N10 | Store links cannot drift | Overstated | Links can be deleted or replaced |
| N11 | CI can nix build each host | Holds | Not activation behavior |
| N12 | Nix pinning fights mise `latest` | Overstated | Cadence tradeoff |
| N13 | programs.zsh fights ZDOTDIR | Wrong | `dotDir` exists |
| N14 | HM removes orphans automatically | Overstated | Only its own prior links |
| N15 | 5 to 9 weeks | Unverified | Over-sizes files and tests, under-sizes work-Mac acceptance |
