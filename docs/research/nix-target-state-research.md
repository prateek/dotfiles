---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-03
updated: 2026-09-06
related:
  - ../research/nix-migration-research.md
  - ../research/work-mac-nix-readiness.md
  - ../references/chezmoi-architecture.md
  - ../references/chezmoi-hook-lifecycle.md
  - ../adr/0006-chezmoi-migration-prototype.md
  - ../adr/0007-default-loaded-plugin-policy.md
  - ../adr/0009-goku-karabiner-codegen.md
  - ../adr/0010-machine-type-package-selection.md
  - ../adr/0011-private-repo-config-overlays.md
  - ../adr/0012-config-gating-convention.md
  - ../adr/0019-plugin-hooks-in-vendored-payload.md
  - ../adr/0020-apply-reconciles-plugin-installs.md
status_detail: "Agent-written, adversarially reviewed by a second model on 2026-09-03; composition revised 2026-09-05 to one hosts.toml, no machine types, dendritic feature files, and keyed group aggregates after nineteen repo surveys and two prototypes; work-Mac readiness measured 2026-09-04. Native shape first, literal translation as an appendix. Builds on the no-wholesale-migration verdict and does not reopen it."
---

# A Fully Nix-Based Dotfiles Repo: Target State And Where Fidelity Breaks

## Question

[Nix Migration Research](nix-migration-research.md) answered "should we
migrate" on 2026-09-03: no wholesale move, a `nix profile` or dev-shell for
CLI formulae is the only live option, and nix-darwin waits on a work-Mac MDM
test. This doc answers the follow-on. If the repo did end up entirely on
Nix, what is the target-state design, construct by construct, and where does
fidelity break against what chezmoi does today?

It does not re-argue the verdict. Where the prior doc already made a point,
this doc cites its section and builds on it.

## Where This Stands (2026-09-06)

Exploration since the second pass, in order, with what each settled.

- **Nineteen repo surveys** (2026-09-04), one per public Nix config, under
  [`nix-repo-surveys/`](nix-repo-surveys/) and listed in the
  [index](../index.md). Each compares one repo's answers to this doc's three
  hard problems and open questions at a pinned sha. Cross-cutting results
  are folded into the sections below; the survey docs stay as the evidence.
- **Two logic prototypes**, single-file HTML under [`prototypes/`](../../prototypes/README.md)
  at the repo root, since `docs/` is Markdown only.
  [`nix-target-state-alternatives.prototype.html`](../../prototypes/nix-target-state-alternatives.prototype.html)
  drives eight decision axes (substrate, work-Mac shape, composition,
  co-owned files, plists, secrets, CI, Homebrew) through a preset for each
  surveyed repo.
  [`nix-composition-alternatives.prototype.html`](../../prototypes/nix-composition-alternatives.prototype.html)
  prices eight composition models against one canonical desired state,
  operation by operation. Both are throwaway per the prototype convention
  and will move to a scratch branch once their questions are settled.
- **Composition direction** (2026-09-05): all configuration in Nix code
  with at most one TOML host registry, no machine types, wimpysworld's
  registry in front of mightyiam's dendritic aggregates. "Composition
  model" below is the result. The prototype's `apps-roles` model and this
  doc's earlier role-preset tree are superseded by it; the prototype has
  not yet been extended with the chosen shape and its two rejected
  variants.
- **Work-Mac readiness** (2026-09-04): measured on the laptop without
  installing anything, [Work Mac Nix Readiness](work-mac-nix-readiness.md).
  No MDM blocker short of a real install. The shape ranking in Problem B
  holds, and a third shape, NixOS in an OrbStack VM, was added.
- **Teaching artefacts** live outside the repo at
  `~/code/teach/nix-composition/`: three lessons (the five composition
  seams, the repo's own cross-module dependencies, a seam-by-dependency
  matrix) with reference sheets. Findings that changed this doc are cited
  inline.

Rebased onto master `9a24d70` on 2026-09-06. Three master changes post-date
the measurements in Method and are reflected where they matter: the Linux
DevPod pilot and its `machines-composite.toml` were reverted (`435e0fb`), so
the live fleet is four hosts and a Linux row is hypothetical until the pilot
returns; the wiki ingest role is paused; and the test suite moved to Bats
plus native Python and Node discovery
([ADR 0022](../adr/0022-bats-and-zsh-test-support.md)), which retires the
"zsh tests survive as they are" framing below in favour of the Bats and
Python suites surviving as they are.

Still open, in priority order: the twelve-file skeleton flake that proves
the key-dedup and `hm-only` mechanics (open questions 17, 18, 20); the cask
path for the `hm-only` work Mac (19); the VM egress test (21); extending the
composition prototype with the chosen shape so "bundles or not" is settled
by numbers; and the real install on the work Mac that is the only answer to
endpoint-agent tolerance (3). The verdict of
[Nix Migration Research](nix-migration-research.md) is unchanged: none of
this is a decision to migrate.

## Method

Read on 2026-09-03 against this worktree at commit e8dabc4. Repo counts were
re-measured: 1,738 files under `home/`, 93 `.tmpl` files, 22 `modify_`
stubs, 24 apply scripts, 1 externals file, 6 `.chezmoidata` files.

Upstream sources were read at pinned commits. `ask` could not fetch them on
this machine (rustls `UnknownIssuer` behind the corporate CA), so tarballs
were pulled with `gh api repos/<owner>/<repo>/tarball/<sha>`. Hosted
Determinate Systems pages could not be fetched directly; their text was read
through search-result excerpts and is marked as such.

| Source | Pinned at | Committed |
| --- | --- | --- |
| [home-manager](https://github.com/nix-community/home-manager/tree/693e8ce0fb240a73c116a03cfd7b19269c87af88) | `693e8ce0` | 2026-09-04 |
| [nix-darwin](https://github.com/nix-darwin/nix-darwin/tree/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48) | `4cff07de` | 2026-08-16 |
| [nix-homebrew](https://github.com/zhaofengli/nix-homebrew/tree/ec8417a617de4d3c739aed40837e308ebd667165) | `ec8417a6` | 2026-09-03 |
| [sops-nix](https://github.com/Mic92/sops-nix/tree/fbf759290e0cb0a98dfc813a4eb7d53ad1dacb57) | `fbf75929` | 2026-09-02 |
| [agenix](https://github.com/ryantm/agenix/tree/b027ee29d959fda4b60b57566d64c98a202e0feb) | `b027ee29` | 2026-02-04 |
| [opnix](https://github.com/brizzbuzz/opnix/tree/0ea3a9e6a94fdd0c444aa7729b98e568a0588222) | `0ea3a9e6` | 2026-08-18 |
| [Determinate nix-installer](https://github.com/DeterminateSystems/nix-installer/tree/a0b0252e916a0fde9c89fd7917de6134093db944) | `a0b0252e` | 2026-09-03 |
| [Nix manual sources](https://github.com/NixOS/nix/tree/d3bf40359442360b5cf93397d042b34ac0b4fb07) | `d3bf4035` | 2026-09-03 |
| [nixpkgs `lib/modules.nix` and manual](https://github.com/NixOS/nixpkgs/tree/3ed67ec0a4d3c7ab4ae1f04f8ee8df07bfa506a2) | `3ed67ec0` (nixos-unstable) | 2026-09-03 |
| [DeterminateSystems/determinate README](https://github.com/DeterminateSystems/determinate) | `main`, unpinned | read 2026-09-03 |

Abbreviations used in citations below: HM (home-manager), ND (nix-darwin),
NHB (nix-homebrew), DSI (Determinate nix-installer). Line numbers refer to
the pinned commits.

A second pass on 2026-09-03 put the first draft through an adversarial
review by a different model (`agptx` through acpx: cursor-agent pinned to
`gpt-5.6-sol-xhigh-fast`, read-only, shell denied, web search allowed). Its
brief was Prateek's challenge to the draft: it translated chezmoi construct
by construct, so would a Nix-native decomposition look different? Its
verdict and findings are folded into this revision. Every row it marked
wrong was re-checked before landing: row 23 was re-tested on this machine
and held (Appendix B); row 24 was corrected after reading the app
documentation. Its GitHub citations were resolved at the pinned commits with
`gh api`; the Claude Code and Codex documentation pages were read through
the harness's web tools. The review text itself is not committed; its
scorecard is the `Review` column in Appendix A.

Sources added in the second pass:

| Source | Pinned at | Read |
| --- | --- | --- |
| [Claude Code managed settings](https://code.claude.com/docs/en/managed-settings), [settings](https://code.claude.com/docs/en/settings), [settings reference](https://code.claude.com/docs/en/settings-reference) | hosted docs, unpinned | 2026-09-03 |
| [Codex config basics](https://developers.openai.com/codex/config-basic), [managed configuration](https://developers.openai.com/codex/enterprise/managed-configuration) | hosted docs, unpinned | 2026-09-03 |
| [pi](https://github.com/earendil-works/pi) | `97f0ccdd`, `c8ada4e7` | 2026-09-03 |
| [Orca](https://github.com/stablyai/orca) | `04a0db59` | 2026-09-03 |
| [crit](https://github.com/tomasz-tomczyk/crit) | `6eeaa9e6`, `5d747d79` | 2026-09-03 |
| [obsidian-wiki](https://github.com/Ar9av/obsidian-wiki) | `5cab5c16` | 2026-09-03 |
| [agentsview configuration](https://www.agentsview.io/configuration/), [Yojam](https://yoj.am/) | hosted pages, read by the reviewer only | 2026-09-03 |
| [SrvOS](https://srvos.org/nixos/getting_started/), [flake-parts](https://flake.parts/), [nixos-hardware](https://github.com/NixOS/nixos-hardware/blob/3f7d0bca003eac1a1a7f4659bbab9c8f8c2a0958/flake.nix), [lewisflude/nix](https://github.com/lewisflude/nix/commit/a1a65faa4c602bc27be99a140edbaa39b3b7d108) | see links | 2026-09-03 |

Sources added in the third pass (2026-09-04 to 2026-09-05):

| Source | Pinned at | Read |
| --- | --- | --- |
| [nixpkgs `lib/modules.nix`](https://github.com/NixOS/nixpkgs/blob/f01ce79aecd8e59ab8a5e1fa2c2d66c224427c22/lib/modules.nix), [`lib/types.nix`](https://github.com/NixOS/nixpkgs/blob/741494f04db5124a8af24fd1bdca17eb7149e59e/lib/types.nix) | `f01ce79`, `741494f` | 2026-09-04 |
| [flake-parts `extras/modules.nix`](https://github.com/hercules-ci/flake-parts/blob/31729ca8cbdb4fa927b34e5f4353e6a83f39e993/extras/modules.nix) | `31729ca` | 2026-09-04 |
| [Dendritic pattern README](https://github.com/mightyiam/dendritic/blob/6c76240658cf1c840faad557c0e0726064170a65/README.md), [mightyiam/infra](https://github.com/mightyiam/infra/tree/704d7e996b24744b2daeab4d3fc18cefc51d203c), [import-tree](https://github.com/denful/import-tree) | `6c76240`, `704d7e99`, HEAD | 2026-09-04, 2026-09-05 |
| [wimpysworld/nix-config registry and `noughty`](https://github.com/wimpysworld/nix-config/tree/e2ca3b06484541d0349df60990a3ec2d470b44c3) | `e2ca3b06` | 2026-09-05 |
| Nineteen repo surveys under [`nix-repo-surveys/`](nix-repo-surveys/) | per-survey shas | 2026-09-04 |
| The two prototypes and [Work Mac Nix Readiness](work-mac-nix-readiness.md) | this worktree | 2026-09-04 to 2026-09-06 |

## Two Target Shapes

The first draft drew one target: each chezmoi construct replaced by its
nearest Nix construct, with the data files, the package groups, the machine
resolver, the verbatim `home/` tree, and the merge scripts carried across.
The review's central finding is that this is a migration scaffold, not a
Nix-native target. It keeps chezmoi's seams, and several of the draft's
"partial" rows are costs of those seams rather than properties of Nix.

This revision therefore describes two shapes:

- **The Nix-native target** (next section): ownership moves into feature
  modules, hosts are rows in one registry that name group aggregates, and
  the layered resolver does not exist. This is the end state, revised on
  2026-09-05.
- **The literal migration scaffold** (Appendix A): the construct-by-construct
  translation. It is still the path a migration walks, and its fidelity
  table is where "what breaks" is argued row by row.

"What Stays Outside Nix" and "The Hardest Three Problems" apply to both
shapes unless a paragraph says otherwise.

## The Nix-Native Target

### Composition model

Revised 2026-09-05 after nineteen repo surveys, a logic prototype that
prices eight composition models against one canonical desired state
([composition prototype](../../prototypes/nix-composition-alternatives.prototype.html)), and
Prateek's direction: all configuration in Nix code, at most one TOML file,
no machine types, following wimpysworld's registry and mightyiam's dendritic
layout.

Those two repos disagree on one decision. wimpysworld imports every module
into every host and each module gates itself on the host's tags; its own
README rule is "tags are for classification, not configuration", and
`imports` inside an evaluation cannot read the registry at all
([survey](nix-repo-surveys/wimpysworld-nix-config.md)). mightyiam's hosts
import named aggregates, a module is on only when imported, and the
dendritic README calls `enable` options an anti-pattern
([README#L215-L220 at `6c76240`](https://github.com/mightyiam/dendritic/blob/6c76240658cf1c840faad557c0e0726064170a65/README.md#L215-L220)).
The target takes the registry from one and the module layout from the
other:

- **One `hosts.toml`.** One table per host, keyed by a logical name that is
  also the flake attribute. A row holds `system`, `substrate` (`darwin+hm`,
  `hm-only`, `hm-linux`), `user`, `groups`, an optional `features` list for
  host-only exceptions, and the facts that survive from `machines.toml`
  (`jamf_policy_id`, `wiki_host_alias`, `tls_inspection`, and so on). The
  machine hostname is not a key and not in the file; MDM rewrites it.
- **One typed host record.** `flake.modules.generic.host-record` declares
  the `host.*` options and their assertions and is imported into both the
  darwin and the home-manager evaluation. Modules read `host.*` for values.
  Nothing reads it to select.
- **One file per feature.** `modules/<group>/<feature>.nix` declares
  `features.<name> = { groups; darwin; homeManager; }`. A helper turns each
  feature into `flake.modules.darwin.<name>` and
  `flake.modules.homeManager.<name>` and joins the named group aggregates by
  keyed reference. The directory is documentation; membership is the
  `groups` list.
- **Groups as keyed aggregates.** The ten package groups become
  `flake.modules.<class>.<group>`, seeded empty for every declared group in
  both classes, so a CLI-only group still exists on a darwin host and an
  unknown group in a row is an evaluation error rather than a silent skip.
- **A ten-line builder.** Reads the rows with `builtins.fromTOML` at the
  flake-parts level, where imports may be computed, and produces
  `darwinConfigurations` for `darwin+hm` rows and `homeConfigurations` for
  every row with a user. The work Mac's `hm-only` row imports the
  home-manager halves only.
- **No machine types.** `work`, `personal`, `homelab`, and `ci` stop being
  selectors; three to seven machines do not need the vocabulary. A row
  names its groups. If a preset is ever wanted, it is an aggregate of
  aggregates (`personal.imports = map ref [ ... ]`), and keyed diamonds make
  `["personal" "developer-tools"]` harmless. A type survives only as a fact
  if some module needs an `is.work` value. The work-on-Linux composite no
  longer exists on master (the DevPod pilot was reverted on 2026-09-05); if a
  Linux host returns it is one `hm-linux` row, not a new layer.

```toml
# hosts.toml (excerpt)
[work-mbp]
system = "aarch64-darwin"
substrate = "hm-only"                 # no standing sudo
user = "prungta"
groups = ["core", "mac-desktop", "ai-agent-apps", "developer-tools", "work-apps", "forks"]
tls_inspection = true

[m4mini]
system = "aarch64-darwin"
substrate = "darwin+hm"
user = "prateek"
groups = ["core", "ai-agent-apps", "codex", "developer-tools", "apple-development", "homelab-overlay"]
features = ["wiki-ingest"]            # a host-only exception, no group
wiki_host_alias = "m4mini"
```

```nix
# modules/personal-apps/tailscale.nix
{ features.tailscale = {
    groups      = [ "personal-apps" "homelab-overlay" ];
    darwin      = { homebrew.casks = [ "tailscale" ]; };
    homeManager = { programs.zsh.initContent = "alias ts=tailscale"; };
}; }
```

This is how the surrounding ecosystem composes machines. SrvOS builds a host
from machine-type, hardware, role, and mixin modules imported directly
([SrvOS getting started](https://srvos.org/nixos/getting_started/)).
nixos-hardware exports importable hardware and capability modules
([flake.nix at `3f7d0bca`](https://github.com/NixOS/nixos-hardware/blob/3f7d0bca003eac1a1a7f4659bbab9c8f8c2a0958/flake.nix)).
flake-parts exists to split a flake into focused modules with typed option
namespaces ([flake.parts](https://flake.parts/),
[modules in separate files](https://flake.parts/define-module-in-separate-file)).
mightyiam's own repo does exactly the aggregate step: feature files
contribute to named modules, hosts import them, and a `mkModuleOption`
helper sets a `key` on each aggregate
([mightyiam/infra at `704d7e99`](https://github.com/mightyiam/infra/tree/704d7e996b24744b2daeab4d3fc18cefc51d203c)).

The current repo shows what the other decomposition costs. Installing and
configuring one app crosses `packages.toml`, `machines.toml`,
`features.tmpl`, `package-cask-enabled.tmpl`, `.chezmoiignore`, the desired
fragment, the modify stub, the shared merge program, and a focused test:
eleven to thirteen files per app, measured on 2026-09-03 by tracing Thaw and
VoiceInk through the repo. ADR 0010's stated consequence, that adding an app to a
group changes install and config in one place, describes the module design
rather than the current one.

Typed options sit downstream of one flat data file. `builtins.fromTOML`
only turns syntax into untyped values
([Nix builtins](https://nix.dev/manual/nix/2.31/language/builtins.html));
the host record types them on read and `assertions` check combinations,
which is what wimpysworld's `noughty` module does over its registry
([module system deep dive](https://nix.dev/tutorials/module-system/deep-dive)).
The list-replace rule in `machines.toml` disappears because there are no
layers left to merge: a row is the whole selection. The TOML stays because
the existing bats and Python tests, the audits, and chezmoi during any
partial adoption can all read it, and converting rows to Nix option values
later is mechanical.

### Five composition seams

The eight models the prototype prices are bundles of five smaller
decisions. Naming them is what made the two source repos reconcilable.

| Seam | Decision | Target's position |
| --- | --- | --- |
| Mapping owner | Where "host X gets app Y" is written: host side (import lists), app side (import everything, gate inside), or data side (registry plus resolver) | Host side. A row names aggregates and aggregates import features. The row is data; the mapping is imports. |
| Facts record | Whether a typed host record exists apart from selection | Separate. `host.*` carries facts; selection is the row's `groups` and `features`. |
| Module unit against the class split | One app spans a darwin and a home-manager evaluation; hide that in one file or expose two trees | One file, two named fragments, plus a check that lists which features have which. |
| Role layer | Whether named sets exist between hosts and features | Groups yes, reused three to four times today. Types no, one host each. |
| Registry as data or code | Whether groups and hosts are a data file or Nix | One TOML for hosts, readable outside Nix; everything else Nix. |

Two more were decided once: identity is the flake attribute, never the
hostname; per-host exceptions live in the row's `features`, never as a
`host.name` test inside a module. The shapes considered, priced against the
same five hosts and the same two example apps:

| | Tags and gates (wimpysworld) | Groups, keyed (chosen) | Features per row | Nested aggregates (mightyiam) | Registry in Nix |
| --- | --- | --- | --- | --- | --- |
| Thaw on every desktop | 1 file | 1 file | 1 file + 2 rows | 1 file | as chosen |
| One-host job | gate on a tag | row `features` | row | distinct module + row | same |
| Tailscale in two groups | n/a | key dedups (unverified) | n/a | needs a shared aggregate | same |
| Unselected feature | options evaluated everywhere | never; checkable | never; checkable | never | same |
| Typo in a row | silent | eval error | eval error | eval error | eval error |
| "What does work get" | read every gate | row, then one grep | row | row + aggregate tree | same |
| Read by tests and audits | yes | yes | yes | yes | only via `nix eval` |

Writing fragments straight into aggregates, mightyiam's merge style, was
rejected for our groups: they overlap (Tailscale, Codex, developer-tools),
and a fragment written into two aggregates is two anonymous modules, so
list and `lines` options double silently and one-definition options error.
Features per row is honest at five hosts and becomes the dendritic README's
named anti-pattern at ten: every group-level change is N row edits.

### Module identity and the diamond rule

The chosen shape rests on five facts from nixpkgs `lib/modules.nix` at
`f01ce79` and flake-parts `extras/modules.nix` at `31729ca`:

1. Imports are deduplicated by module `key`; the final module list is the
   unique-by-key closure over the import graph
   ([modules.nix#L558-L572](https://github.com/NixOS/nixpkgs/blob/f01ce79aecd8e59ab8a5e1fa2c2d66c224427c22/lib/modules.nix#L558-L572)).
2. A module imported by path has the path as its key. Anything else gets
   `"${parentKey}:anon-${n}"` from its import site
   ([#L523-L556](https://github.com/NixOS/nixpkgs/blob/f01ce79aecd8e59ab8a5e1fa2c2d66c224427c22/lib/modules.nix#L523-L556)),
   so the same attribute set imported from two places is two modules.
3. `flake.modules.<class>.<name>` wraps each definition with `_class` and
   `_file` and no `key`; the source says `# TODO: set key?`
   ([extras/modules.nix#L13-L33](https://github.com/hercules-ci/flake-parts/blob/31729ca8cbdb4fa927b34e5f4353e6a83f39e993/extras/modules.nix#L13-L33)).
   The `deferredModule` merge adds `_file` only
   ([types.nix#L1313-L1328](https://github.com/NixOS/nixpkgs/blob/741494f04db5124a8af24fd1bdca17eb7149e59e/lib/types.nix#L1313-L1328)).
4. A module tagged with a class cannot be imported into another class's
   evaluation
   ([#L452-L466](https://github.com/NixOS/nixpkgs/blob/f01ce79aecd8e59ab8a5e1fa2c2d66c224427c22/lib/modules.nix#L452-L466));
   `generic` modules import anywhere.
5. `unifyModuleSyntax` keeps a module's own `key` when it has one
   ([#L655-L695](https://github.com/NixOS/nixpkgs/blob/f01ce79aecd8e59ab8a5e1fa2c2d66c224427c22/lib/modules.nix#L655-L695)).

Consequences. A feature reached through two groups is evaluated twice
unless something supplies a key. The key goes at the reference, not the
definition:
`ref = class: name: { key = "flake.modules.${class}.${name}"; imports = [ config.flake.modules.${class}.${name} ]; }`,
which is mightyiam's `mkModuleOption` applied to `flake.modules`. A key
written in the definition would make a second file that also defines the
same name vanish silently (same key, first wins). Reference-side keys also
give per-host exclusion for free through `disabledModules` by key. The host
record is `generic` because it must be declared in both classes. Three
named anti-patterns: `or {}` around a missing aggregate (budimanjojo),
definition-side keys, and relying on `nix flake check`, which does not
evaluate `darwinConfigurations`
([flake-check.md](https://github.com/NixOS/nix/blob/d3bf40359442360b5cf93397d042b34ac0b4fb07/src/nix/flake-check.md)),
so every assertion must be pulled into `checks.<system>` or it never runs in
CI. Two footguns of `fromTOML` in a flake: the file must be git-tracked or a
`git+file` flake will not see it, and with the row key as the flake
attribute `darwin-rebuild switch --flake .` stops resolving by hostname
(open question 22).

Verification status: the dedup mechanics are derived from source and
mirrored by mightyiam's own helper, not yet executed here; Nix is not
installed on any of these machines. A twelve-file skeleton flake, evaluated
in an OrbStack Nix container, is the planned proof (open questions 17, 18,
20). One negative control is worth keeping: drop `ref`, import raw values
through both aggregates, and `host.features` must show `tailscale` twice,
which is the kclejeune failure reproduced.

Two things a pass over the repo's own cross-module dependencies added on
2026-09-04. Modules with effects outside Nix keep an `enable` or presence
option whatever the import rule says, because an un-imported module cannot
run its off-branch (the wiki archive kill switch that disables Orca
automations). And the fleet invariant "at most one ingest host" cannot be a
per-host assertion, since a host evaluation cannot see other hosts; it is a
flake check over the rows.

### Tree

Names are illustrative.

```text
flake.nix                  flake-parts plus import-tree ./modules
flake.lock
hosts.toml                 one table per host: system, substrate, user,
                           groups, features, surviving facts
modules/
  _wiring/
    host-record.nix        flake.modules.generic.host-record: host.* options
                           and assertions
    groups.nix             the group vocabulary; seeds empty aggregates in
                           both classes; the ref helper
    features.nix           features.<name> -> keyed modules plus group
                           membership by reference
    build.nix              rows -> darwinConfigurations, homeConfigurations
    checks.nix             checks.<system>.compose: per-host features,
                           dormant features, undeclared groups, duplicates
  core/                    git, zsh, mise, ...
  mac-desktop/             ghostty, raycast, hammerspoon, moom, thaw, tuna,
                           karabiner, zed
  ai-agent-apps/           claude-code, cursor-agent, pi, orca, agentsview
  developer-tools/         orbstack, gh, ...
  personal-apps/           tailscale, voiceink, nvalt, granola-mcp
  homelab-overlay/         tartelet, wiki-sync, wiki-ingest
  work-apps/  codex/  apple-development/  forks/
pkgs/                      agent-plugin-marketplace, karabiner-goku,
                           raycast-extensions, hammerspoon, build-mic
assets/                    agent-packages, static config, surviving scripts
secrets/                   references.nix (op:// refs only)
```

Each feature file carries its nix-darwin and its home-manager fragment; the
directory under `modules/` is documentation, and membership is the feature's
`groups` list. There is no `hosts/` directory and no `roles/` directory. The
`assets/agent-packages` tree is the 1,498-file skill payload; it is data for
the marketplace derivation, not module code.

### What disappears

| Construct | Steady state | Migration only |
| --- | --- | --- |
| `features.tmpl` resolver and the layered `machines*.toml` | Gone. One flat `hosts.toml`, no layers, no list-replace rule; rows keyed by logical name, so an MDM hostname rewrite is inert. | |
| `machine_type` as the selection axis | Gone. A row names its groups directly; a preset, if one is ever wanted, is an aggregate of aggregates; a surviving fact is a typed record field. `machines-composite.toml` already went with the DevPod revert on master. | |
| `package-cask-enabled.tmpl` and the 20 `.chezmoiignore` cask gates | Gone. An app module owns package and config. | |
| Group union, name dedupe, unknown-group validation | Gone. Module-system key dedup for overlaps, a seeded group vocabulary so an unknown group is an evaluation error, and the compose check for dormant features. | |
| `run_onchange_` hash lines | Gone. Derivations and `onChange` carry their own inputs. | |
| `run_once_` bootstrap | | One-time migration script. |
| uv pre-source hook | Gone. Store interpreter. | |
| `.chezmoiremove` | | One-time cleanup. |
| Retired-package ledger | Gone for Nix packages. Homebrew cleanup is a per-host policy (row 11). | |
| Brewfile renderer and its golden tests | Gone. `homebrew.brewfile` is module output. | |
| Drift banner | Gone. Generations and `nix store diff-closures`, with the per-file loss in row 38. | |
| Plist modify stubs | Gone for domains written through `defaults`. Kept for shapes `defaults` cannot express. | |
| Plist quit guard | Narrows to apps proven to overwrite live preferences (row 25). | |
| First-run prompts and `[data].machines_local` | Gone. Host policy is committed (row 7). | |

### Per-app ownership for the structured configs

The draft's row 24 treated the nine JSON, TOML, and line-based configs as
one problem. They are not one problem. The native design asks each app
whether it offers a layer Nix can own outright.

| App | Layer the app offers | Native decision | Verified |
| --- | --- | --- | --- |
| Claude Code | `/Library/Application Support/ClaudeCode/managed-settings.json` plus `managed-settings.d/*.json`, merged alphabetically after the base file. Managed sits above user, project, and local settings. Arrays such as `permissions.allow` and hook lists concatenate across scopes ([managed settings](https://code.claude.com/docs/en/managed-settings), [settings](https://code.claude.com/docs/en/settings)). | Hooks, permissions, and marketplace registration move to a managed drop-in; the hook-union merger is unnecessary because scopes concatenate. `enabledPlugins` stays in the user file: a managed value cannot be overridden per project, and ADR 0007 depends on that override. The path is root-owned, so on the work Mac this trades a merge for a Jamf-gated write (Problem B). | docs read |
| Codex | `/etc/codex/config.toml` is a system layer below `~/.codex/config.toml`; `/etc/codex/managed_config.toml` is a managed layer above the user file and CLI flags ([config basics](https://developers.openai.com/codex/config-basic), [managed configuration](https://developers.openai.com/codex/enterprise/managed-configuration)). | Machine defaults go in the system layer. The user file is left to Codex and its plugin records (ADR 0020). Same root-owned path caveat. | docs read |
| obsidian-wiki | Setup writes a line-based global config under `$XDG_CONFIG_HOME/obsidian-wiki` ([cli.py at `5cab5c16`](https://github.com/Ar9av/obsidian-wiki/blob/5cab5c16/obsidian_wiki/cli.py)). | A Nix-owned install generates the whole file. The one-key merger goes away. | source read |
| pi | Global and trusted project settings merge recursively ([`97f0ccdd`](https://github.com/earendil-works/pi/commit/97f0ccdd96cc207b6ad3630c56eea4d32dbdcf53), [`c8ada4e7`](https://github.com/earendil-works/pi/commit/c8ada4e76e123e8f292e4b057f443f874554b5ac)); the UI writes global state into the same file. | No separate machine-default file. The global merge stays. | commits resolved |
| Orca | `orca-data.json` is one atomically rewritten state file holding settings, projects, worktrees, and tabs ([`04a0db59`](https://github.com/stablyai/orca/commit/04a0db591eb0944352d67be2fb0bc15b95df5371)). | The settings-subtree reconciler stays. | commit resolved |
| agentsview | One auto-created `config.toml`, environment overrides for some keys, additive `session_sources`, no include layer ([configuration](https://www.agentsview.io/configuration/)). | The reconciler stays for the dynamic source list and the credentials it preserves. Environment variables where they suffice. | reviewer-read |
| crit | `agent_cmd` and `open_cmd` are honored from the global file only, which also holds auth state ([`6eeaa9e6`](https://github.com/tomasz-tomczyk/crit/commit/6eeaa9e62415abf19b76bbc4bfc7648204921681), [`5d747d79`](https://github.com/tomasz-tomczyk/crit/commit/5d747d79423f7bca35a5e4ab9ab6b82d100ea470)). | The merger stays unless crit adds a system layer. | commits resolved |
| Cursor CLI | No documented system, project, or managed layer for `cli-config.json`. | The merger stays. | unverified beyond local behavior |
| Yojam | Flat-file config the app writes back to, no include layer. The vendor site names `rules.json` while this repo manages `config.json` ([Yojam](https://yoj.am/)). | Whole-file ownership only if app persistence is disabled; otherwise the merger stays. Storage filename per version unverified. | reviewer-read |

Net: two mergers disappear (Codex, obsidian-wiki), one splits by setting
class (Claude), six remain (pi, Orca, agentsview, crit, Cursor, Yojam).
Row 24's fidelity becomes "mixed".

### Concept-map rows that change under this shape

| Row | Scaffold fidelity | Native | Why |
| ---: | --- | --- | --- |
| 5 | full, simpler | eliminated | Module values replace feature templating. |
| 6 | full | eliminated | Selecting a host output replaces first-run prompts. The output name is the logical host name, so `--flake .` needs `#<name>` or generated hostname aliases (open question 22). |
| 7 | partial | eliminated | `secrets_enabled` becomes committed host policy. |
| 8 | full | eliminated | One flat `hosts.toml` row plus group aggregates replace the layered resolver; a Linux host, if one returns, is a row rather than a composite layer. |
| 9 | full | eliminated | App modules contribute Homebrew and Nix packages directly. |
| 11 | partial | full for Nix packages, per-host policy for Homebrew | Removed packages leave the generation on their own. |
| 16 | full | eliminated | Imports replace inverted file gates. |
| 17 | full | eliminated | Package and config share one module. |
| 19 | full | eliminated as a primitive | Derivations and `onChange` carry their own inputs. |
| 20 | partial | eliminated after migration | Bootstrap ownership replaces once-only scripts. |
| 22 | full | eliminated | No modifier bootstrap remains. |
| 24 | none natively, partial via activation | mixed | See the per-app table. |
| 36 | full | eliminated | XDG paths are native options, not data. |
| 39 | none | eliminated | Preference intent is reviewable Nix source. The merged-result preview is still lost (Problem A). |

## What Stays Outside Nix

These are the pieces a fully Nix repo would still not own, with the reason.

- **GUI apps.** Casks, MAS apps, and Setapp stay Homebrew and the App Store.
  The nix-darwin module wraps `brew bundle`; it does not install Homebrew
  itself and cannot uninstall MAS apps
  ([ND homebrew.nix#L666-L674](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/homebrew.nix#L666-L674),
  [#L880-L886](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/homebrew.nix#L880-L886)).
  Setapp apps install after login, so their config stays gated exactly as
  today (`CLAUDE.md`, "Chezmoi And App Config").
- **The content of the co-owned files.** Nix can own the desired fragment
  and the merge program. It cannot own the file, because the app writes it
  too. Under the native seams the set shrinks from 22 to the six apps in the
  per-app table plus any plist domain `defaults` cannot express. Problem A.
- **Tool-owned install records.** Claude and Codex plugin records and caches
  stay with the CLIs (ADR 0020). Karabiner's `karabiner.json` stays with
  goku and the app (ADR 0009).
- **Mutable runtime state.** zinit plugin clones, mise installs, Raycast's
  encrypted extension store
  ([plan](../plans/raycast-config-automation-plan.md)), and the wiki archive
  clone shape reconciled by `scripts/agent-sessions/reconcile-wiki-clone`.
- **Privilege.** Jamf temp-admin on the work Mac
  ([reference](../references/jamf-self-service-elevation.md)). nix-darwin
  assumes root is available; it does not obtain it.
- **The 1Password session.** Biometric `op` reads happen in the user's
  session. Nix evaluation cannot use them, and root activation does not have
  them. Problem C.
- **Weekly cadence.** `refreshPeriod = "168h"` and the ISO-week zinit bucket
  have no declarative analogue. Freshness becomes a lock bump you review, or
  a launchd job.

## The Hardest Three Problems

### A. Files the app also writes

Today the repo merges into 22 app-owned files: 12 preference plists through
[`plist-merge`](../../scripts/macos/plist-merge), which preserves unmanaged
keys, honors `<!-- chezmoi-delete: ... -->` directives (lines 45-47, 70-75),
and echoes stdin unchanged when nothing logically changed so chezmoi skips
the write (lines 58-68, 86-91); the nvALT color list, an NSKeyedArchiver
plist rewritten by its own Python stub
(`home/Library/private_Colors/modify_nvALT.clr.tmpl`); eight structured
configs (Claude, Codex, crit, Cursor, pi, Orca, Yojam, agentsview) merged by
small Python programs; and one line-based file
([obsidian-wiki](../../home/dot_config/obsidian-wiki/modify_config.tmpl)).
The Claude merger unions hook lists by matcher so Orca and Superset
injections survive
([modify_private_settings.json.tmpl:55-71](../../home/dot_claude/modify_private_settings.json.tmpl)).
The Cursor merger exists because a full rewrite would log the CLI out
([modify_private_cli-config.json.tmpl:6-16](../../home/dot_cursor/modify_private_cli-config.json.tmpl)).

Why home-manager's file model does not fit. `home.file` places a symlink to a
store path
([files.nix#L283-L303](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/files.nix#L283-L303)).
An app that saves by writing a temp file and renaming it replaces that
symlink with a regular file. The next switch then sees a foreign file at the
path and refuses with "would be clobbered" unless `-b`, a backup extension,
or `force = true` is set
([check-link-targets.sh#L18-L40](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/files/check-link-targets.sh#L18-L40),
[#L96-L110](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/files/check-link-targets.sh#L96-L110)).
`force` "will silently delete the target"
([file-type.nix#L135-L143](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/lib/file-type.nix#L135-L143)),
which is the exact outcome the mergers exist to avoid. `mkOutOfStoreSymlink`
into the repo checkout would make the app write into the working tree. No
option in `files.nix` or `file-type.nix` merges into an existing file, and
the upstream attempt closed unmerged (prior doc, N1).

Target design, in three tiers. The first tier came out of the review.

1. **Use the app's own layer where one exists.** Claude Code managed
   drop-ins, the Codex system layer, and a generated obsidian-wiki config
   remove two mergers and split a third; see the per-app table under The
   Nix-Native Target. The cost is that the two managed paths are root-owned
   (`/Library/Application Support/ClaudeCode`, `/etc/codex`), which on the
   work Mac means the Jamf flow in Problem B, and that Claude's
   `enabledPlugins` must stay user-level for ADR 0007's per-project override.
2. **Plists go through `defaults`.** `targets.darwin.defaults."<bundle id>"`
   runs `defaults import <domain> <generated plist>` per domain
   ([user-defaults#L15-L29](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/targets/darwin/user-defaults/default.nix#L15-L29)),
   and nix-darwin's `CustomUserPreferences` runs one `defaults write` per key
   as the primary user
   ([defaults-write.nix#L8-L16](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/system/defaults-write.nix#L8-L16)).
   Both preserve keys we do not manage, which is the property `plist-merge`
   provides; the review challenged this for `defaults import` and a re-test
   on this machine confirmed it (Appendix B). Both go through `cfprefsd`, so
   the post-apply `killall cfprefsd`
   ([plist-hooks.sh:183](../../scripts/chezmoi-hooks/plist-hooks.sh)) is no
   longer needed. Both lose two things: the delete directive, because `null`
   is filtered rather than removed
   ([user-defaults#L23-L26](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/targets/darwin/user-defaults/default.nix#L23-L26),
   [defaults-write.nix#L11](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/system/defaults-write.nix#L11)),
   and the write-only-if-changed behavior, because the commands run on every
   switch. Deletes become a small activation list of `defaults delete`
   calls. The two non-domain files (`nvALT.clr`, Yojam's `config.json`) fall
   into tier 2.
3. **The remaining structured configs keep the mergers, as activation.** A
   `dotfiles.merges.<target>` option carries `kind`, the desired fragment
   (built with `pkgs.writeText` from the same data the templates use today),
   and `deletes`. One `home.activation.mergeManagedFiles` block after
   `writeBoundary` runs the existing Python programs from
   `pkgs.python3.withPackages (ps: [ ps.tomlkit ])`, wrapped in `run` so
   `DRY_RUN` prints instead of writing
   ([home-environment.nix#L488-L507](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/home-environment.nix#L488-L507)).
   The read-modify-write race noted in the Cursor merger stays the same. The
   uv bootstrap hook for the headless profile disappears, because the
   interpreter is a store path.

What is lost with no workaround. `chezmoi diff` shows the merged result
before apply, because modifiers run during target computation
([hook lifecycle](../references/chezmoi-hook-lifecycle.md), "Apply" step 4).
Nix has no equivalent preview; a `DRY_RUN` diff printed by the merge block
is the closest substitute. The interactive quit-and-relaunch prompt
([plist-hooks.sh:126-141](../../scripts/chezmoi-hooks/plist-hooks.sh)) has
no home in activation. A check-only block before `writeBoundary` can refuse
when a listed app is running (verification before the boundary is allowed,
[home-environment.nix#L484-L492](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/home-environment.nix#L484-L492)),
and the quit itself must move after the boundary. Under nix-darwin the
activation runs as root under `env -i`
([activation-scripts.nix#L84-L100](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/system/activation-scripts.nix#L84-L100)),
so `DOTFILES_SKIP_PLIST_HOOKS` style switches do not reach it; they would
have to become module options. Whether a `defaults` write is overwritten
when a running app later saves its own preferences was not verified here.

### B. The MDM-managed work Mac

What installing Nix requires. The installer creates an APFS volume, adds a
`/etc/synthetic.conf` entry for the `/nix` mount point, writes `/etc/fstab`,
encrypts the volume with a key in the system keychain when FileVault is on,
and installs a LaunchDaemon to mount it at boot
([Nix manual installing-binary.md#L111-L158](https://github.com/NixOS/nix/blob/d3bf40359442360b5cf93397d042b34ac0b4fb07/doc/manual/source/installation/installing-binary.md#L111-L158);
[DSI create_nix_volume.rs#L24-L89](https://github.com/DeterminateSystems/nix-installer/blob/a0b0252e916a0fde9c89fd7917de6134093db944/src/action/macos/create_nix_volume.rs#L24-L89)).
It creates 32 `_nixbld` build users by default
([DSI README#L383-L385](https://github.com/DeterminateSystems/nix-installer/blob/a0b0252e916a0fde9c89fd7917de6134093db944/README.md#L383-L385)).
All of that is root work, once.

Where MDM bites. The installer's macOS planner runs a `check_suis` pre-flight
that fails when any installed configuration profile carries a
"Restrictions - Media" policy, because that policy stops the store volume
from mounting
([DSI planner/macos/mod.rs#L397-L402](https://github.com/DeterminateSystems/nix-installer/blob/a0b0252e916a0fde9c89fd7917de6134093db944/src/planner/macos/mod.rs#L397-L402),
[#L454-L488](https://github.com/DeterminateSystems/nix-installer/blob/a0b0252e916a0fde9c89fd7917de6134093db944/src/planner/macos/mod.rs#L454-L488)).
Determinate's troubleshooting page for that error says the fix is an MDM
administrator creating an exception for machines running Nix
([SUIS premount dissented](https://docs.determinate.systems/troubleshooting/suis-premount-dissented/);
read through a search excerpt, not fetched). Determinate also publishes an
MDM deployment guide built around a Self Service script that installs a
signed `.pkg`, run by a non-root user with admin rights
([Deploy with MDM](https://docs.determinate.systems/guides/mdm/); same
caveat). That is the same shape as the repo's Jamf temp-admin flow. Whether
this tenant's profiles include the media restriction, and whether the
endpoint agent tolerates `/nix`, are the on-box checks the prior doc already
lists ("Go/No-Go Checks"). Measured on 2026-09-04: this tenant pushes no
media-restrictions payload, so the hard-fail does not apply; the endpoint
question stays open ([Work Mac Nix Readiness](work-mac-nix-readiness.md)).

What each switch requires. nix-darwin runs the entire activation as root and
`darwin-rebuild switch` refuses otherwise
([activation-scripts.nix#L69-L81](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/system/activation-scripts.nix#L69-L81),
[#L104-L112](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/system/activation-scripts.nix#L104-L112);
[darwin-rebuild.sh#L149](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/pkgs/nix-tools/darwin-rebuild.sh#L149);
[issue 1457](https://github.com/nix-darwin/nix-darwin/issues/1457)). User
things happen through `launchctl asuser ... sudo --user=<primaryUser>`
([defaults-write.nix#L12-L16](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/system/defaults-write.nix#L12-L16)),
with `system.primaryUser` naming that user
([primary-user.nix#L9-L19](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/system/primary-user.nix#L9-L19)).
On the work Mac the user is not in `admin` by default
([script_lib.sh:53-58](../../home/.chezmoitemplates/script_lib.sh)), so every
switch is: trigger the Jamf policy, wait for `admin`, then
`sudo darwin-rebuild switch`. A root switch also runs without the user's SSH
agent, which breaks the `git+ssh` private-overlay input
([issue 1471](https://github.com/nix-darwin/nix-darwin/issues/1471)).
`touchIdAuth` for `sudo_local`
([pam.nix#L14-L40](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/security/pam.nix#L14-L40))
removes the password typing, not the group requirement.

Determinate specifics. If the work Mac gets Determinate Nix, nix-darwin must
stop managing Nix: the `determinate` darwin module with
`determinateNix.enable = true` does that, and the README says Determinate
Nix "does not work properly" otherwise
([DeterminateSystems/determinate README, nix-darwin section](https://github.com/DeterminateSystems/determinate#nix-darwin)).
nix-darwin already guards `/etc/nix/nix.custom.conf` hashes from Determinate
installer versions so it does not clobber them
([ND nix/default.nix#L881-L899](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/nix/default.nix#L881-L899)).
Determinate Nixd feeds Nix the Keychain's certificates on macOS
([README, first paragraph](https://github.com/DeterminateSystems/determinate));
that matters here, since plain rustls clients fail behind this laptop's
corporate CA (the `ask` failure in Method).

Measured on the box on 2026-09-04
([Work Mac Nix Readiness](work-mac-nix-readiness.md)): no media-restrictions
profile, so the installer's hard-fail does not apply; the installer's `plan`
step runs inside an admin window and lists an encrypted store volume,
`synthetic.conf`, `fstab`, two LaunchDaemons, and 32 build users; the
corporate CA bundle already on the machine verifies the intercepted TLS
chain, so it serves as `ssl-cert-file`; and every host Nix talks to is
reachable through the content filter. Off an admin grant, `sudo` is not
password-gated but absent, and a denied attempt is reported to the
administrator. Endpoint-agent tolerance of the `/nix` volume remains the one
thing only an install answers.

Three target shapes for the work host, in order of how much they give up.

| Shape | Needs | Gives up |
| --- | --- | --- |
| Standalone home-manager only | Nix installed once, root inside one admin window. No sudo per switch. | `system.defaults` system domains, LaunchDaemons, the `homebrew` module, nix-homebrew. Casks need an HM activation `brew bundle` behind a custom option, which is what chezmoi does today and the only no-root path, or they stay outside Nix (open question 19). |
| nix-darwin plus HM as a module | All of the above, plus Self Service elevation and a Touch ID tap before every switch, and an SSH-agent workaround for the private input. | Nothing structurally, but every apply is a manual ritual, and with `sudo` absent outside a grant there is no unattended switch, ever. |
| NixOS in an OrbStack VM | OrbStack, which is installed and permitted; the corporate CA bundle in the VM's trust store (`security.pki.certificateFiles`); copied credentials for Vertex and other OAuth tools. Root inside the VM is the user's own. | The Mac host stays on chezmoi: casks, defaults, plists, GUI apps, Karabiner. The dev shell becomes Linux. Untested: whether the VM's NAT egress clears the corporate tunnel and filter (open question 21). |

The prior doc's ranking (standalone HM before nix-darwin, "Options" 3 and 4)
holds and gains the VM as a third path that needs no MDM admin to rebuild.
On this host the ordering is not a preference; it is the difference between
one root operation ever and one per switch.

### C. Secrets without store leakage

The rule to preserve: secret values never land in the repo or in the
world-readable `/nix/store`. Today the three license files are rendered with
`onepasswordRead` at apply time
(`home/Library/Application Support/BetterTouchTool/private_license.bttlicense.tmpl`,
lines 16-21), the refs are obfuscated `op://` IDs in
[secrets.toml:1-14](../../home/.chezmoidata/secrets.toml) with per-machine
overrides in local chezmoi config, and `secrets_enabled` defaults to false
([machines.toml:23](../../home/.chezmoidata/machines.toml)) so the paths are
ignored elsewhere ([.chezmoiignore:180-185](../../home/.chezmoiignore)).

The constraint in Nix. Anything read during evaluation is copied into the
store. sops-nix states it is "not possible to use secrets at evaluation
time"
([README#L1010-L1016](https://github.com/Mic92/sops-nix/blob/fbf759290e0cb0a98dfc813a4eb7d53ad1dacb57/README.md#L1010-L1016));
agenix documents the `builtins.readFile` anti-pattern that "can cause the
cleartext to be placed into the world-readable Nix store"
([README#L479-L489](https://github.com/ryantm/agenix/blob/b027ee29d959fda4b60b57566d64c98a202e0feb/README.md#L479-L489)).
So `onepasswordRead` cannot move into a template. It has to move to
activation or to a service.

| Option | How it works | What changes for this repo |
| --- | --- | --- |
| **opnix** | Keeps `op://` references. A launchd service or activation resolves them with a 1Password service account token stored in a file (`/etc/opnix-token`, mode 640, for system; `$HOME/.config/opnix/token` for the HM devshell). HM module writes `path` relative to home with a `mode`. | The auth model changes from the user's biometric `op` session to a long-lived service-account token on disk. Whether service accounts can read the vaults these items live in was not verified. Sources: [README#L69-L79](https://github.com/brizzbuzz/opnix/blob/0ea3a9e6a94fdd0c444aa7729b98e568a0588222/README.md#L69-L79), [getting-started.md#L174-L218](https://github.com/brizzbuzz/opnix/blob/0ea3a9e6a94fdd0c444aa7729b98e568a0588222/docs/getting-started.md#L174-L218), [best-practices.md#L42-L57](https://github.com/brizzbuzz/opnix/blob/0ea3a9e6a94fdd0c444aa7729b98e568a0588222/docs/best-practices.md#L42-L57). |
| **sops-nix (HM module)** | Encrypted files committed to the repo; decrypted by a `sops-nix` systemd user service on Linux or a launchd agent on Darwin into `$XDG_RUNTIME_DIR/secrets.d` or `DARWIN_USER_TEMP_DIR`, symlinked to `~/.config/sops-nix/secrets`; `path` may be absolute. The age key file "must have no password". | Encrypted license blobs would live in a public repo, a policy shift from "refs only". Adds an unencrypted age key on every machine. Sources: [README#L780-L845](https://github.com/Mic92/sops-nix/blob/fbf759290e0cb0a98dfc813a4eb7d53ad1dacb57/README.md#L780-L845); [sops.nix#L396-L438](https://github.com/Mic92/sops-nix/blob/fbf759290e0cb0a98dfc813a4eb7d53ad1dacb57/modules/home-manager/sops.nix#L396-L438). |
| **agenix (HM module)** | Same commit-encrypted model with SSH identities; a launchd agent decrypts on Darwin. age is unauthenticated: anyone with write access to the `.age` files can swap secrets. | Same repo-policy shift as sops-nix, weaker integrity story. Sources: [README#L393-L424](https://github.com/ryantm/agenix/blob/b027ee29d959fda4b60b57566d64c98a202e0feb/README.md#L393-L424), [#L758-L772](https://github.com/ryantm/agenix/blob/b027ee29d959fda4b60b57566d64c98a202e0feb/README.md#L758-L772); [age-home.nix#L232](https://github.com/ryantm/agenix/blob/b027ee29d959fda4b60b57566d64c98a202e0feb/modules/age-home.nix#L232). |
| **`op read` in activation** | An HM activation block after `writeBoundary` runs `op read <ref>` in the user's session and installs the file with mode 0600, wrapped in `run` for `DRY_RUN`. Refs come from `data/secrets.toml` and host overrides. | Closest to today: same refs, same biometric session, nothing in the store. It does not work under root activation (nix-darwin) unless HM activation runs as the user, and it cannot run unattended on a headless host. |

Recommended target: the fourth row for interactive Macs, opnix only if a
headless host (the homelab mini) must apply unattended. Both keep `op://`
references as the committed form and keep values out of the store. sops-nix
and agenix solve a different problem (secrets for machines that have no
1Password session) and would change what the public repo contains.

## What The Test Surface Becomes

Under the native shape the checks are about ownership and composition, not
about reproducing today's renders. Every host evaluates and builds its
activation closure. Every group aggregate holds the features it should, every row names declared groups, and no feature is dormant. Enabling
one app contributes its package, files, defaults, service, and secret
declarations, and a disabled app contributes nothing. The reconcilers that
survive (per-app table) keep their own unit tests. Tart proves defaults,
GUI behavior, launchd, MDM, and app persistence. The Brewfile string
assertion and the resolver evaluation in the bullets below belong to the
scaffold, not the target.

As of 2026-09-05 the suite is Bats plus native Python and Node discovery
composed through Make ([ADR 0022](../adr/0022-bats-and-zsh-test-support.md));
CI runs shellcheck, a macOS behaviour and dry-run job that inits chezmoi for
the key machine types, parses the Brewfile, and installs the `ci` formulae
([install-smoke.yml](../../.github/workflows/install-smoke.yml)). The Linux
DevPod job went with the pilot. The runnable suite is described in
[tests/README.md](../../tests/README.md).

- **`nix flake check` is narrower than it looks.** It evaluates `checks`,
  `packages`, `devShells`, and `nixosConfigurations.*.config.system.build.toplevel`,
  and builds `checks`. It does not touch `darwinConfigurations` or
  `homeConfigurations`
  ([Nix flake-check.md](https://github.com/NixOS/nix/blob/d3bf40359442360b5cf93397d042b34ac0b4fb07/src/nix/flake-check.md)).
  Every host must be exposed explicitly:
  `checks.aarch64-darwin.<host> = self.darwinConfigurations.<host>.system`
  and `checks.<system>.<user> = self.homeConfigurations.<user>.activationPackage`.
  That replaces the "chezmoi init + apply --dry-run per machine type" job
  with a closure build per host, which is stronger for evaluation and
  dependency failures and silent about activation.
- **The compose check.** Under the registry shape one `checks.<system>.compose`
  derivation bakes eval-time JSON per host: the features each row reaches,
  features no row reaches (dormant), groups a row names that `groups.nix`
  does not declare, and duplicate reaches that would mean a key was lost.
  It replaces `test-machines-features` and the unknown-group render
  failure, and it is the only place the fleet invariant "at most one ingest
  host" can live (ingest is paused on master as of 2026-09-05). Whether a darwin toplevel evaluates on a Linux runner so
  its assertions run at all is open question 18. A row nobody builds rots
  the way wimpysworld's commented-out host did; every row is built by some
  lane or deleted.
- **Module tests replace template golden tests (scaffold shape).** nix-darwin's own harness
  builds `system.build.toplevel` and greps the generated scripts
  ([release.nix#L15-L56](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/release.nix#L15-L56);
  [tests/homebrew.nix](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/tests/homebrew.nix)).
  The repo's `test-render-brewfile` becomes an assertion on the internal
  `homebrew.brewfile` string
  ([homebrew.nix#L942-L946](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/homebrew.nix#L942-L946)).
  The machine-feature checks (now in the Python suite) become `nix eval` on
  `config.host.*` per row. The "retired package still in a group" render failure
  ([brewfile.tmpl:122-131](../../home/.chezmoitemplates/brewfile.tmpl))
  becomes a module `assertions` entry. home-manager's own tests use `nmt`
  ([tests/default.nix#L1-L12](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/tests/default.nix#L1-L12))
  if the repo wants file-tree assertions on the HM side.
- **Activation dry runs.** `home-manager switch -n` sets `DRY_RUN`
  ([cli#L1229-L1230](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/home-manager/home-manager#L1229-L1230));
  well-behaved blocks print through `run` instead of acting, and `onChange`
  hooks are skipped
  ([files.nix#L412-L416](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/files.nix#L412-L416)).
  `darwin-rebuild build` and `--dry-run` exist
  ([darwin-rebuild.sh#L19-L22](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/pkgs/nix-tools/darwin-rebuild.sh#L19-L22)),
  but `check` also requires root
  ([#L149](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/pkgs/nix-tools/darwin-rebuild.sh#L149)).
  This is the replacement for `chezmoi apply --dry-run --exclude=scripts`.
- **Diffs.** `nix store diff-closures` between the current and built
  generation
  ([diff-closures.md](https://github.com/NixOS/nix/blob/d3bf40359442360b5cf93397d042b34ac0b4fb07/src/nix/diff-closures.md))
  shows package changes. Nothing shows a preference or merge-result diff;
  that was the `textconv` and modifier preview chezmoi gave.
- **Pre-activation checks.** nix-darwin's `system.checks` run at switch time
  (build users, NIX_PATH, macOS version, Homebrew cleanup check)
  ([checks.nix#L282-L318](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/system/checks.nix#L282-L318);
  [homebrew.nix#L1008-L1024](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/homebrew.nix#L1008-L1024)).
  The repo's `run_onchange_after_90-verify` becomes a `postActivation` block
  or an HM block at the end of the DAG.
- **What still needs a machine.** Defaults landing, the merges, GUI app
  behavior, casks, MAS, LaunchAgent bootstrap, and the Jamf flow. The Tart
  lane keeps that job. The Bats and Python suites survive as they are; only
  the chezmoi-specific fixtures change. The
  [test refactoring plan](../plans/test-suite-rebuild-plan.md) is archived
  and [ADR 0022](../adr/0022-bats-and-zsh-test-support.md) is the current
  guidance.

## Open Questions

Numbered as in the first draft; the review changed the shape of several and
added eight.

1. Does Claude Code accept a `directory` marketplace whose plugin
   directories are symlinks into the store, and do plugin hooks keep their
   executable bits through `lndir`? Row 29. Test the marketplace derivation
   and the CLI install-record reconcile on their own; the answer does not
   depend on the rest of the layout. Unverified.
2. Does a running app overwrite a `defaults` write when it later saves its
   own preferences? Applies to every app moved to key-level or domain
   `defaults`. Unverified.
3. Half answered on 2026-09-04: the tenant pushes no "Restrictions - Media"
   profile ([readiness](work-mac-nix-readiness.md)). Whether the endpoint
   agent tolerates the `/nix` volume, the build users, and unsigned store
   binaries still needs a real install. Problem B.
4. Can the DAYJOB DevPod image carry a root-created `/nix` and a daemon, or
   does `--init none` limit Nix to root? Row 41. Image owner question; moot
   while the DevPod pilot stays reverted (2026-09-05).
5. Can 1Password service accounts read the vaults that hold the three
   license items? Problem C, opnix row. Decides whether opnix is viable for
   the homelab mini.
6. Resolved by the native shape: the machine-local override is not needed.
   Host policy is committed; runtime switches stay outside desired state.
7. Is Homebrew fully declarative on each host? `homebrew.onActivation.cleanup
   = "uninstall"` removes everything outside the generated Brewfile, which
   the work Mac may not want. Row 11. Decide per host.
8. Does `ray build` run inside a sandboxed derivation, or do Raycast
   extensions stay an activation step? Row 31. Unverified.
9. Which Claude keys belong in a managed drop-in without breaking the
   per-project overrides ADR 0007 relies on? Hooks and permissions yes,
   `enabledPlugins` no. Anything else needs the settings reference's scope
   column.
10. Which Codex defaults belong in `/etc/codex/config.toml` (below the user
    file) rather than `managed_config.toml` (above it)?
11. Which plist domains are safe for whole-domain `defaults import`, and
    which need key-level writes because the app also writes the domain?
12. Which current plist values exceed what nix-darwin's typed defaults can
    represent (row 26)?
13. Does Cursor expose any supported managed or project layer for
    `cli-config.json`?
14. Which apps allow disabling their own persistence so Nix can own the
    whole file? Yojam is the candidate.
15. Which Yojam version writes `config.json`, `rules.json`, or both?
16. Answered for Claude on 2026-09-04: the work Mac carries an MDM-owned
    managed Claude Code policy (audit hooks, `allowManagedHooksOnly`, denies
    for `curl`, `wget`, and `WebFetch`), so that seam is not ours to write
    there. `/etc/codex` is still untested.
17. Does the reference-side `key` collapse a diamond through flake-parts'
    function wrapper when feature modules are functions of `pkgs`, and does a
    second file defining the same name merge rather than drop? Skeleton
    flake.
18. Can `darwinConfigurations.<x>.config.system.build.toplevel.drvPath` be
    evaluated on a Linux runner without import-from-derivation, so assertions
    run in CI at all? Skeleton flake.
19. How do casks reach the `hm-only` work Mac: an HM activation `brew bundle`
    behind a custom option, which is what chezmoi does today and the only
    no-root path, or outside Nix? A design decision; it blocks the work
    profile.
20. Does `disabledModules = [{ key = ...; }]` work as a per-host exclude on a
    keyed aggregate? Decides whether presets can be aggregates without losing
    "drop a group from one host".
21. Does an OrbStack VM's NAT egress clear the corporate tunnel and filter?
    One `curl https://cache.nixos.org/nix-cache-info` and one
    `gcloud auth print-access-token` from inside a NixOS machine with the CA
    installed settle it.
22. With the row key as the flake attribute, `darwin-rebuild switch --flake .`
    and `home-manager switch --flake .` stop resolving by hostname. Generate
    alias attributes from a `hostnames` field, or accept `#<name>` on every
    invocation?

## Appendix A: The Literal Migration Scaffold

The first draft's target, kept as the migration path. It maps each chezmoi
construct onto the nearest Nix construct and carries the data model across
unchanged. The `Review` column in the concept map records the adversarial
review's verdict per row; "Inherited-choice" means the translation is
correct but the native target has no such construct.

### Scaffold tree

Names are illustrative.

```text
flake.nix          inputs: nixpkgs, home-manager, nix-darwin, nix-homebrew,
                   determinate, homebrew-core, homebrew-cask, one input per
                   third-party tap, zinit (flake = false), dotfiles-private
                   (work only), a secrets backend (see Problem C)
flake.lock         the one reviewed lock bump that replaces refreshPeriod,
                   `brew update`, and the weekly zinit bucket
hosts/
  m4mini.nix       darwinConfigurations.m4mini      type = homelab, host layer
  work-mbp.nix     darwinConfigurations.M-D2N572TGQN type = work, jamf policy id
  personal.nix     darwinConfigurations.<hostname>  type = personal
  ci.nix           darwinConfigurations.ci          the `ci` type as a buildable host
  devpod.nix       homeConfigurations."prungta@devpod"  work x linux, HM only
modules/
  machine/         the machines.toml resolver as typed options
    options.nix    machine.type, machine.groups, machine.features.<flag>
    layers/        defaults.nix, os-darwin.nix, os-linux.nix, type-<t>.nix,
                   composite-work-linux.nix, host-<h>.nix
  darwin/          nix-darwin modules: homebrew.nix (from data/packages.toml),
                   defaults.nix, launchd.nix, elevation.nix, nix-homebrew.nix
  home/            home-manager modules: zsh.nix, agents.nix, merges.nix,
                   plists.nix, launchd.nix, secrets.nix, apps/<app>.nix
packages/          derivations: agent-plugins (the renderer), karabiner-json
                   (goku), raycast-extensions, hammerspoon, build-mic, and an
                   overlay for formulae nixpkgs lacks
data/              packages.toml, machines*.toml, orca.toml, licenses.toml,
                   secrets.toml, unchanged, read with builtins.fromTOML
files/             the verbatim home tree (today's home/ minus .chezmoi* files)
scripts/           activation-time helpers that survive: plist-merge, the
                   JSON/TOML mergers, reconcile-fork-installs,
                   reconcile-agent-plugins, the plist quit guard
tests/             checks.<system>.* plus the surviving zsh behavioral tests
```

What each chezmoi directory becomes:

| Today | Target | Note |
| --- | --- | --- |
| `home/` with `dot_`, `private_`, `executable_`, `symlink_` prefixes | `files/` plus `home.file` and `xdg.configFile` declarations in `modules/home/` | Attributes move from filenames to options. `executable` exists ([HM file-type.nix#L80](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/lib/file-type.nix#L80)); `private_` has no equivalent, see the concept map. |
| `home/.chezmoidata/*.toml` | `data/*.toml` read with `builtins.fromTOML` | Data stays TOML. Only the consumers change. |
| `home/.chezmoitemplates/` | Nix functions under `modules/` and string interpolation | `script_lib.sh` becomes a `pkgs.writeShellApplication` library or is dropped where activation supplies the same helpers. |
| `home/.chezmoiassets/` | `files/assets/` | Nix strings only interpret `${`, so Moom's `{{` geometry needs no escaping. |
| `home/.chezmoiscripts/` (24) | `home.activation` blocks, `system.activationScripts`, and `packages/` derivations | Split by kind: pure builds become derivations, side effects become activation. |
| `home/.chezmoiexternal.toml.tmpl` | flake inputs | Immutable and locked. See rows 14 and 15. |
| `home/.chezmoiignore` | `lib.mkIf` on the module options | The 20 cask gates collapse into `apps/<app>.nix` files that enable themselves when the cask is selected. |
| `home/.chezmoi.toml.tmpl` | `hosts/<host>.nix` | No prompts. Identity is the flake attribute you switch to. |
| `home/.chezmoiremove` | a one-time migration script | HM removes only its own prior links ([HM files.nix#L307](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/files.nix#L307)). |
| `scripts/chezmoi-hooks/` | `home.activation` entries | Config hooks have no other analogue. |
| `tests/*.zsh` | `checks.<system>.*` for evaluation and closure, zsh tests for behavior | The [test-suite rebuild plan](../plans/test-suite-rebuild-plan.md) already separates assertions from harness calls. |

### Concept map

Fidelity: **full** means the Nix construct does what chezmoi does today
with no behavior loss. **partial** means it covers the common case with a
named gap. **none** means no built-in construct exists and the behavior
would be an activation script or an external tool.

| Chezmoi construct | Nix construct | Source | Fidelity | Review |
| --- | --- | --- | --- | --- |
| 1. Plain files under `home/` | `home.file.<name>.source` or `.text`; symlinks into the store, linked with `ln -Tsf` at activation | [HM files.nix#L283-L303](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/files.nix#L283-L303) | full for files only we write | Holds |
| 2. `private_` (0600/0700 targets) | No mode option on `home.file`. Store paths are world-readable. A 0600 target needs an activation `install -m 0600` copy or a secrets tool. | [HM file-type.nix#L38-L143](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/lib/file-type.nix#L38-L143) (no `mode`); [agenix README#L488](https://github.com/ryantm/agenix/blob/b027ee29d959fda4b60b57566d64c98a202e0feb/README.md#L488) on the world-readable store | partial | Holds |
| 3. `executable_` | `home.file.<name>.executable = true` | [HM file-type.nix#L80-L88](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/lib/file-type.nix#L80-L88) | full | Holds |
| 4. `symlink_` live links (8: six `bin/` wrappers, `~/.claude/CLAUDE.md`, `~/.codex/skills`) | `config.lib.file.mkOutOfStoreSymlink` with an absolute path. HM creates absolute links; a relative target such as `../.agents/AGENTS.md` would resolve inside the store, so it must be spelled absolute. | [HM files.nix#L124-L140](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/files.nix#L124-L140); [HM dotfiles.md#L155-L169](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/docs/manual/usage/dotfiles.md#L155-L169) | full | Holds |
| 5. `.tmpl` Go templates on `.chezmoi.os`, `.chezmoi.hostname`, features | Nix string interpolation and module options. Host facts are evaluation inputs, not runtime detection. | [features.tmpl:27-39](../../home/.chezmoitemplates/features.tmpl) today | full, and simpler | Inherited-choice |
| 6. `promptChoiceOnce machine_type`, `promptStringOnce jamf_policy_id` ([.chezmoi.toml.tmpl:22-34](../../home/.chezmoi.toml.tmpl)) | One flake attribute per host. `home-manager switch --flake .` resolves `$USER@$(hostname -f)`, then `$USER@$(hostname)`, then `$USER@$(hostname -s)`; nix-darwin takes `--flake .#<host>`. | [HM cli#L208-L222](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/home-manager/home-manager#L208-L222) | full | Inherited-choice |
| 7. Host-local `[data].machines_local` in `~/.config/chezmoi/chezmoi.toml` | No pure equivalent. Flakes read only files in the flake source; a `git+file` flake fetches files "as long as they have been added to the Git repository". An out-of-repo override needs `--impure` with `builtins.getEnv`/`pathExists`, or an untracked local flake input. | [Nix flake.md#L258-L262](https://github.com/NixOS/nix/blob/d3bf40359442360b5cf93397d042b34ac0b4fb07/src/nix/flake.md#L258-L262) | partial | Inherited-choice |
| 8. `machines.toml` layer merge, defaults < os < type < composite < host < local, lists replaced wholesale ([machines.toml:3-10](../../home/.chezmoidata/machines.toml)) | Module option priorities: `mkOptionDefault` 1500, `mkDefault` 1000, plain 100, `mkForce` 50; ordering via `mkBefore` 500, `mkAfter` 1500. Lists merge by concatenation in the module system, so `groups` needs a scalar-like type or per-layer `mkOverride` to keep replace semantics. | [nixpkgs modules.nix#L1568-L1573](https://github.com/NixOS/nixpkgs/blob/3ed67ec0a4d3c7ab4ae1f04f8ee8df07bfa506a2/lib/modules.nix#L1568-L1573), [#L1604-L1606](https://github.com/NixOS/nixpkgs/blob/3ed67ec0a4d3c7ab4ae1f04f8ee8df07bfa506a2/lib/modules.nix#L1604-L1606) | full | Inherited-choice |
| 9. `packages.toml` groups unioned into a Brewfile, `trusted: true` for tap-qualified names, `link`, `args`, `appdir` ([brewfile.tmpl:41-113](../../home/.chezmoitemplates/brewfile.tmpl)) | `homebrew.taps`, `brews`, `casks`, `masApps`, `extraConfig`; per-entry `trusted`, `link`, `args`, cask `args.appdir` and `args.no_quarantine`. The module generates the Brewfile and runs `brew bundle` at activation with `--no-upgrade` by default. | [ND homebrew.nix#L666-L760](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/homebrew.nix#L666-L760), [#L290-L327](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/homebrew.nix#L290-L327), [#L441](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/homebrew.nix#L441), [#L525-L582](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/homebrew.nix#L525-L582), [#L962-L975](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/homebrew.nix#L962-L975) | full (nix-darwin only) | Inherited-choice |
| 10. nixpkgs-covered formulae | `home.packages` or `environment.systemPackages`, pinned by `flake.lock` | prior doc, "How Each Piece Maps To Nix" | full | Holds |
| 11. `[packages.retired]` plus `uninstall-retired-packages` ([packages.toml:384-395](../../home/.chezmoidata/packages.toml); [uninstall-retired-packages:11-16](../../scripts/packages/uninstall-retired-packages)) | `homebrew.onActivation.cleanup = "uninstall"` removes everything not in the generated Brewfile, which is broader than a named retired list. MAS apps are never uninstalled. `"check"` fails activation instead. | [ND homebrew.nix#L78-L112](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/homebrew.nix#L78-L112), [#L880-L886](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/homebrew.nix#L880-L886) | partial | Inherited-choice |
| 12. Forks reconciler: uninstall the official, install the fork with `--no-quarantine`, retire, report outdated ([reconcile-fork-installs:13-23](../../scripts/packages/reconcile-fork-installs), [:163-168](../../scripts/packages/reconcile-fork-installs), [:206-210](../../scripts/packages/reconcile-fork-installs)) | The Brewfile subtraction is a Nix `filter`. The ordered swap is not expressible in a Brewfile; it stays a `preActivation` script. Cleanup removes retired forks for free. | [ND activation-scripts.nix#L114-L140](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/system/activation-scripts.nix#L114-L140) (order: `preActivation` first, `homebrew` near last) | partial | Holds |
| 13. `run_once_before_00-homebrew` installing Homebrew | nix-homebrew installs Homebrew itself, can adopt an existing install with `autoMigrate`, and pins taps as flake inputs with `mutableTaps = false`. `autoMigrate` deletes the Homebrew git repositories and keeps installed packages. | [NHB README#L1-L60](https://github.com/zhaofengli/nix-homebrew/blob/ec8417a617de4d3c739aed40837e308ebd667165/README.md#L1-L60), [#L116-L146](https://github.com/zhaofengli/nix-homebrew/blob/ec8417a617de4d3c739aed40837e308ebd667165/README.md#L116-L146); [NHB modules#L393-L405](https://github.com/zhaofengli/nix-homebrew/blob/ec8417a617de4d3c739aed40837e308ebd667165/modules/default.nix#L393-L405), [#L468-L477](https://github.com/zhaofengli/nix-homebrew/blob/ec8417a617de4d3c739aed40837e308ebd667165/modules/default.nix#L468-L477) | full (nix-darwin only) | Holds |
| 14. Private overlay external, SSH URL, 168h refresh, composed by `run_after_37` (ADR 0011; [.chezmoiexternal.toml.tmpl:5-14](../../home/.chezmoiexternal.toml.tmpl)) | A `git+ssh` flake input, composed by a pure derivation. Refresh becomes `nix flake update dotfiles-private`. Under nix-darwin the switch runs as root and loses the user's SSH agent (issue 1471 below). CI needs `--override-input dotfiles-private` with a stub because inputs cannot be optional. | [ND issue 1471](https://github.com/nix-darwin/nix-darwin/issues/1471); ADR 0011 | partial | Holds |
| 15. zinit `git-repo` external plus weekly `zinit update --all` ([run_onchange_after_11:6-12](../../home/.chezmoiscripts/run_onchange_after_11-zinit-update.sh.tmpl)) | zinit checkout as a `flake = false` input linked read-only; its self-update stops working. Plugin clones stay mutable under ZINIT_HOME. No date-bucketed trigger exists; a weekly refresh becomes a `launchd.agents` job or a lock bump. HM has no zinit module (searched `modules/programs/zsh/`). | [HM launchd.nix#L14](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/launchd/launchd.nix#L14), [#L184-L187](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/launchd/launchd.nix#L184-L187) | partial | Inherited-choice |
| 16. `.chezmoiignore` gates (headless profile, cask gates, license paths) ([.chezmoiignore:18-63](../../home/.chezmoiignore), [:103-185](../../home/.chezmoiignore)) | `lib.mkIf` on `machine.*` options and `home.file.<name>.enable = false`. | [HM file-type.nix#L38-L44](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/lib/file-type.nix#L38-L44) | full | Inherited-choice |
| 17. `package-cask-enabled.tmpl` | `lib.elem "<cask>" config.machine.casks` | [package-cask-enabled.tmpl:10-21](../../home/.chezmoitemplates/package-cask-enabled.tmpl) today | full | Inherited-choice |
| 18. `.chezmoiremove` | Generation cleanup removes only links HM created in a prior generation. Pre-existing paths need a one-time script. | [HM files.nix#L307-L370](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/files.nix#L307-L370) | partial | Holds |
| 19. `run_onchange_` with embedded hashes | `home.file.<name>.onChange`, run after `linkGeneration`, skipped under `DRY_RUN`. Fires on the file's content, which is what the hash lines simulate today. Blocks with no file to hang off run every switch. | [HM file-type.nix#L121-L133](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/lib/file-type.nix#L121-L133); [HM files.nix#L408-L420](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/files.nix#L408-L420) | full | Inherited-choice |
| 20. `run_once_` | No once-per-hash primitive in HM. Idempotent activation blocks run every switch; a stamp file emulates once. | [HM home-environment.nix#L470-L483](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/home-environment.nix#L470-L483) (blocks must be idempotent) | partial | Inherited-choice |
| 21. `run_before_` / `run_after_` ordering | `lib.hm.dag.entryBefore`, `entryAfter`, `entryBetween`; side effects must follow `writeBoundary`. | [HM dag.nix#L31-L60](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/lib/dag.nix#L31-L60); [HM home-environment.nix#L484-L492](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/home-environment.nix#L484-L492) | full | Holds |
| 22. `hooks.read-source-state.pre` installing uv so modifiers can run ([.chezmoi.toml.tmpl:49-59](../../home/.chezmoi.toml.tmpl); [hook lifecycle](../references/chezmoi-hook-lifecycle.md)) | Not needed. Activation scripts reference `${pkgs.python3.withPackages (ps: [ ps.tomlkit ])}` from the store. | Nix store path interpolation | full, and the hook disappears | Holds |
| 23. 12 plist `modify_` stubs through `plist-merge` (key-level merge, `chezmoi-delete`, byte-equal skip) ([plist-merge:45-91](../../scripts/macos/plist-merge)) | `targets.darwin.defaults."<domain>"` runs `defaults import` per domain, or ND `system.defaults.CustomUserPreferences` runs `defaults write` per key as the primary user. Both preserve unmanaged keys (re-tested on this machine, Appendix B). Neither deletes: null values are filtered out, not removed. Both write on every switch. No app quit guard. | [HM user-defaults#L15-L29](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/targets/darwin/user-defaults/default.nix#L15-L29), [#L49-L50](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/targets/darwin/user-defaults/default.nix#L49-L50); [ND defaults-write.nix#L8-L16](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/system/defaults-write.nix#L8-L16), [#L48](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/system/defaults-write.nix#L48); [ND CustomPreferences.nix#L22-L50](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/system/defaults/CustomPreferences.nix#L22-L50); [ND issue 658](https://github.com/LnL7/nix-darwin/issues/658) | partial | Holds (re-tested, Appendix B) |
| 24. 9 JSON/TOML/line `modify_` stubs (Claude, Codex, crit, Cursor, pi, Orca, Yojam, agentsview, obsidian-wiki) | Mixed; see the per-app table under The Nix-Native Target. For the apps that keep a merger there is no built-in construct: `home.file` offers `text`, `source`, `recursive`, `onChange`, `force`; nothing merges into a file the app also writes. `force` "will silently delete the target". [HM PR 9464](https://github.com/nix-community/home-manager/pull/9464) for merged mutable config closed unmerged (prior doc, N1). Escape hatch: activation blocks running the existing Python mergers. See Problem A. | [HM file-type.nix#L60-L143](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/lib/file-type.nix#L60-L143) | mixed: two removed, one split, six remain | Corrected (per-app table) |
| 25. Plist quit/relaunch guard in `hooks.apply.pre/post`, interactive prompt, `cfprefsd` kill, dry-run detection ([plist-hooks.sh:44-58](../../scripts/chezmoi-hooks/plist-hooks.sh), [:126-141](../../scripts/chezmoi-hooks/plist-hooks.sh), [:183](../../scripts/chezmoi-hooks/plist-hooks.sh)) | A check-only block before `writeBoundary` may verify and exit; quitting apps is a side effect and must sit after it. ND activation runs under `env -i` as root, so `DOTFILES_*` switches do not reach it. Writing through `defaults` removes the need to kill `cfprefsd`. | [HM home-environment.nix#L484-L492](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/home-environment.nix#L484-L492); [ND activation-scripts.nix#L84-L112](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/system/activation-scripts.nix#L84-L112) | partial | Holds |
| 26. `run_onchange_after_30-macos-defaults`: 143 `defaults write` lines, `sudo` system domains, PlistBuddy, lsregister, `killall` | ND typed `system.defaults.<domain>` (22 domain files) plus `CustomUserPreferences` and `CustomSystemPreferences`; the Dock is restarted for you. PlistBuddy, lsregister, and Spotlight stay in `system.activationScripts.postActivation.text`. HM `targets.darwin.defaults` covers user domains without root. | [ND defaults dir](https://github.com/nix-darwin/nix-darwin/tree/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/system/defaults); [ND defaults-write.nix#L155-L157](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/system/defaults-write.nix#L155-L157); [ND activation-scripts.nix#L156-L158](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/system/activation-scripts.nix#L156-L158) | partial (no delete, no quit guard) | Holds |
| 27. `script_lib.sh` sudo keepalive and Jamf temp-admin ([script_lib.sh:59-94](../../home/.chezmoitemplates/script_lib.sh), [:161-230](../../home/.chezmoitemplates/script_lib.sh)) | ND: the whole activation is root, so it is one `sudo darwin-rebuild switch`. Nothing grants `admin` membership; the Jamf step must run first. `security.pam.services.sudo_local.touchIdAuth` replaces the password prompt, not the group requirement. Standalone HM: the CLI never calls sudo. | [ND activation-scripts.nix#L69-L81](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/system/activation-scripts.nix#L69-L81); [ND darwin-rebuild.sh#L149](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/pkgs/nix-tools/darwin-rebuild.sh#L149); [ND pam.nix#L14-L40](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/security/pam.nix#L14-L40); [ND issue 1457](https://github.com/nix-darwin/nix-darwin/issues/1457) | partial on work, full elsewhere | Holds |
| 28. Two LaunchAgents (`com.prateek.wiki-sessions-sync`, `com.prateek.tartelet-runner`) | HM `launchd.agents` writes `~/Library/LaunchAgents` and runs `launchctl bootout`/`bootstrap` as the user. ND `launchd.user.agents` copies the plist as the primary user via `sudo --user` and loads it. | [HM launchd.nix#L14](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/launchd/launchd.nix#L14), [#L272-L318](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/launchd/launchd.nix#L272-L318); [ND launchd.nix#L37-L48](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/system/launchd.nix#L37-L48) | full | Holds |
| 29. Agent plugin marketplace render plus `reconcile-agent-plugins --apply` (ADR 0007, 0019, 0020; [run_onchange_after_36:3-41](../../home/.chezmoiscripts/run_onchange_after_36-agent-plugins.sh.tmpl)) | The renderer becomes a derivation over `files/agents/packages` and the vendored apm payloads. `~/.agents/plugins` is a recursive `home.file` link (leaves are store symlinks). The reconcile stays an `onChange` block on that link because the CLIs own their install records (ADR 0020). Whether Claude accepts a `directory` marketplace whose plugin dirs are store symlinks is unverified. | [HM file-type.nix#L90-L103](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/lib/file-type.nix#L90-L103) | partial | Holds |
| 30. Karabiner goku codegen at apply, seeding a `Default` profile into the app-owned `karabiner.json` (ADR 0009; [run_onchange_after_45:22-46](../../home/.chezmoiscripts/run_onchange_after_45-karabiner-goku.sh.tmpl)) | The EDN is a `home.file`; compile and write remain an `onChange` block because goku edits the live file in place. | ADR 0009 | partial | Holds |
| 31. Raycast extension `npm install` and `ray build` at apply ([run_after_21](../../home/.chezmoiscripts/run_after_21-raycast-extensions.sh.tmpl)) | `buildNpmPackage` with `npmDepsHash` gives a network-free build per lockfile; `ray build` inside a derivation is unverified. Otherwise an activation block with the same stamp logic. | [nixpkgs javascript.section.md#L78-L125](https://github.com/NixOS/nixpkgs/blob/3ed67ec0a4d3c7ab4ae1f04f8ee8df07bfa506a2/doc/languages-frameworks/javascript.section.md#L78-L125) | partial | Unverified |
| 32. Hammerspoon Fennel compile, `build-mic` Swift CLIs, Tuna reload, Tartelet settings, Xcode select | Pure builds become derivations (Fennel, Swift with the Darwin SDK in `stdenv`). App reloads and Xcode selection stay activation. | [nixpkgs platform-notes.chapter.md#L3-L27](https://github.com/NixOS/nixpkgs/blob/3ed67ec0a4d3c7ab4ae1f04f8ee8df07bfa506a2/doc/stdenv/platform-notes.chapter.md#L3-L27) | partial | Unverified |
| 33. gh extensions (`run_onchange_after_12`) | `programs.gh.extensions` takes packages; `gh-attach` would need a `buildGoModule` in `packages/`. | [HM gh.nix#L139-L145](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/programs/gh.nix#L139-L145) | full once packaged | Holds |
| 34. mise runtimes and `latest` AI CLIs (ADR 0005) | Keep mise; its `conf.d/*.toml` are `home.file`. Or move runtimes to nixpkgs and lose `latest`. | prior doc, N12 | partial by policy | Holds |
| 35. zsh startup with a custom `ZDOTDIR` | `programs.zsh.dotDir` writes `$HOME/.zshenv` that exports `ZDOTDIR` and sources `$ZDOTDIR/.zshenv`, which matches the repo's bootstrap rule. Or manage the files verbatim with `home.file`. | [HM zsh default.nix#L150-L169](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/programs/zsh/default.nix#L150-L169), [#L530-L540](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/programs/zsh/default.nix#L530-L540) | full | Holds |
| 36. `[data]` xdg paths and `dotfiles_dir` | `config.xdg.configHome` and friends; `home.sessionVariables`. | [HM home-environment.nix#L289](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/home-environment.nix#L289); [HM xdg module](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/misc/xdg/default.nix) | full | Inherited-choice |
| 37. `onepasswordRead` at render time for three license files (`home/Library/Application Support/BetterTouchTool/private_license.bttlicense.tmpl:16-21`; [licenses.toml:10-14](../../home/.chezmoidata/licenses.toml)) | No evaluation-time secret read is safe: it lands in the store. opnix, sops-nix, and agenix all decrypt at activation or in a launchd service and expose a runtime path. See Problem C. | [sops-nix README#L1010-L1016](https://github.com/Mic92/sops-nix/blob/fbf759290e0cb0a98dfc813a4eb7d53ad1dacb57/README.md#L1010-L1016); [agenix README#L479-L489](https://github.com/ryantm/agenix/blob/b027ee29d959fda4b60b57566d64c98a202e0feb/README.md#L479-L489) | partial | Holds |
| 38. `chezmoi status`, `diff`, `managed`, `verify`, the drift banner | `home-manager build` then `nix store diff-closures` or `nvd`; `home-manager switch -n` and `darwin-rebuild --dry-run`. No per-file report against `$HOME`; collisions with unmanaged files surface only at switch time. | [Nix diff-closures.md](https://github.com/NixOS/nix/blob/d3bf40359442360b5cf93397d042b34ac0b4fb07/src/nix/diff-closures.md); [HM cli#L1229-L1230](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/home-manager/home-manager#L1229-L1230); [ND darwin-rebuild.sh#L19-L22](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/pkgs/nix-tools/darwin-rebuild.sh#L19-L22); [HM check-link-targets.sh#L18-L40](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/files/check-link-targets.sh#L18-L40) | partial | Holds |
| 39. `[[textconv]]` plist-as-XML diffs | Nothing comparable. Closure diffs show packages, not preference content. | [.chezmoi.toml.tmpl:61-67](../../home/.chezmoi.toml.tmpl) today | none | Inherited-choice |
| 40. Pre-existing file at a managed path | HM errors with "Existing file ... would be clobbered" unless `-b <ext>`, `home-manager.backupFileExtension`, or `force = true`. Identical content is skipped. | [HM check-link-targets.sh#L18-L40](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/files/check-link-targets.sh#L18-L40), [#L96-L110](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/files/check-link-targets.sh#L96-L110); [HM nixos/common.nix#L110-L122](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/nixos/common.nix#L110-L122) | full | Holds |
| 41. `work x linux` headless DevPod profile (`machines-composite.toml:10-18` (removed on master with the DevPod revert, 2026-09-05); [runbook](../runbooks/linux-work-devpod-orca.md)) | Standalone HM on Ubuntu. Needs Nix on the image: a multi-user install needs root and systemd; `--init none` limits Nix to root or sudo users. | [HM standalone.md](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/docs/manual/installation/standalone.md); [DSI README#L140-L154](https://github.com/DeterminateSystems/nix-installer/blob/a0b0252e916a0fde9c89fd7917de6134093db944/README.md#L140-L154) | partial, blocked on the image | Holds |
| 42. Tart lanes and CI dry-run ([install-smoke.yml](../../.github/workflows/install-smoke.yml)) | `nix build .#darwinConfigurations.<host>.system` per host on a macOS runner. Activation still needs a real machine. | prior doc, N11 | partial | Holds |

## Appendix B: Review Re-Verification

Rows the adversarial review marked wrong, and what happened when they were
re-checked.

- **Row 23, "home-manager's `defaults import` can clobber a domain."** Not
  reproduced. On this machine on 2026-09-03: `defaults write` two keys into a
  throwaway domain, `defaults import` a plist carrying one of them changed
  plus a new key, then `defaults read` showed all three with the untouched
  key intact. The pinned home-manager module runs exactly that command per
  domain
  ([user-defaults#L15-L29](https://github.com/nix-community/home-manager/blob/693e8ce0fb240a73c116a03cfd7b19269c87af88/modules/targets/darwin/user-defaults/default.nix#L15-L29)).
  The row stands. The review's residual points, no delete of removed keys
  and a running app can still overwrite, were already in rows 23 and 25.
- **Row 24, "nine apps are one problem."** Confirmed wrong. Corrected in the
  per-app table: two mergers disappear, one splits, six remain.
- **Rows 31 and 32.** The review marked the `ray build` sandbox claim and
  several "pure builds become derivations" claims unverified. They were
  already hedged and stay unverified.
