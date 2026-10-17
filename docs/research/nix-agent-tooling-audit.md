---
status: active
doc_type: research
summary: "2026-10-15 reuse audit: llm-agents.nix and other package sets, skill/plugin frameworks, upstream Home Manager Claude/Codex modules (#9906, mutableSettings), and personal configs; feeds the agent-skills split plan."
owner: Prateek
created: 2026-10-15
updated: 2026-10-15
related:
  - ../plans/agent-skills-repo-split-plan.md
  - nix-agent-skills-packaging-research.md
status_detail: "Read-only source audit via gh api on 2026-10-15; nothing built or activated, and Nix is not installed on this machine."
---

# Nix agent tooling audit

This audit asks which public Nix projects for AI agent CLIs, skills, and plugins
the [agent-skills split](../plans/agent-skills-repo-split-plan.md) should reuse,
and which patterns it should borrow. It follows up the September
[skill-packaging survey](nix-agent-skills-packaging-research.md).

## Method

All sources were read through `gh api` at the commits linked below. Nothing was
evaluated, built, or switched. Claims about runtime behaviour come from reading
code, issue threads, and strings in the Claude binary. Star counts are as of
2026-10-15.

## Verdict

- **Package agent CLIs with numtide's `llm-agents.nix`.** Take it as an input,
  without `nixpkgs.follows`.
- **Write our own plugin library.** No skill or plugin framework covers native
  Claude and Codex manifests, both catalogs, paired human-only controls, and the
  hand-off to Home Manager's plugin options.
- **Build on upstream Home Manager's client modules, from master,** with the
  workarounds noted below.

## Agent CLI package sets

[numtide/llm-agents.nix@4e80fdc](https://github.com/numtide/llm-agents.nix/tree/4e80fdc9b04f4531a78c89f6dff66e0a4d920b3f)
(2,136★):

- **Churn.** It lands about 100 commits a day. An updater runs four times daily,
  and dependency PRs merge automatically.
- **Builds.** The build method varies per package: prebuilt binaries
  (claude-code, cursor-agent, orca), `buildNpmPackage` (skills, pi), bun2nix
  (agent-slack, omp, qmd), Go (crit), Rust (codex, herdr, agent-browser), and
  Python (apm).
- **Updates.** These run through `nix-update` or a declarative `passthru.updater`.
- **Platforms.** x86_64-linux, aarch64-linux, and aarch64-darwin. No
  x86_64-darwin.
- **Binary cache.** It's self-hosted at `https://cache.numtide.com`, with key
  `niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=`. A
  consuming flake has to repeat it in its own `nixConfig`, or each host sets it.
- **Outputs.** `packages`, plus `overlays.shared-nixpkgs`, which only hits the
  cache when the consumer's nixpkgs revision matches. It has no Home Manager
  modules and no skill or plugin handling.
- **Wrappers.**
  [claude-code](https://github.com/numtide/llm-agents.nix/blob/4e80fdc9b04f4531a78c89f6dff66e0a4d920b3f/packages/claude-code/package.nix)
  sets `DISABLE_AUTOUPDATER=1`, and on darwin it uses `__noChroot`, so a local
  rebuild needs a relaxed sandbox.
  [codex](https://github.com/numtide/llm-agents.nix/blob/4e80fdc9b04f4531a78c89f6dff66e0a4d920b3f/packages/codex/package.nix)
  patches out self-update.
- **Coverage.** None of our seven missing CLIs (acpx, ask, bird, shortcut-cli,
  rootly-cli, absurdctl, obsidian-wiki) are present. The request policy is
  "packages we personally use, or you maintain it", and a workflow checks that
  each package names a maintainer.

Others:

- [natsukium/mcp-servers-nix@8443d67](https://github.com/natsukium/mcp-servers-nix/tree/8443d67297538436b6c87b8c9039709003b8e3d8)
  (308★) feeds Home Manager's `programs.mcp.servers`. It's only relevant if
  MCP configuration moves to Home Manager.
- [kissgyorgy/coding-agents@75b0b3e](https://github.com/kissgyorgy/coding-agents/tree/75b0b3ecb03b09d0a238be7f1d08dcaa5b046dbd)
  is a single-maintainer package set with an `mkOutOfStoreSymlink` toggle for
  editing skills live. Not worth taking as an input.
- [dryvist/nix-ai@6d1cd57](https://github.com/dryvist/nix-ai/tree/6d1cd57bc9f940d916769575000a695df6f3f254)
  shows `llm-agents` used without `follows`, with the cache set in `nixConfig`.
  Its
  [plugin cache rules](https://github.com/dryvist/nix-ai/blob/6d1cd57bc9f940d916769575000a695df6f3f254/.claude/rules/plugin-cache-architecture.md)
  are to store-link whole marketplace directories, never use `force`, and leave
  `~/.claude/plugins/cache` to Claude. Its
  [plugin scoping](https://github.com/dryvist/nix-ai/blob/6d1cd57bc9f940d916769575000a695df6f3f254/docs/architecture/plugin-scoping.md)
  splits user-level and per-repo `enabledPlugins` to stay under the
  skill-listing budget.

## Skill and plugin frameworks

| Need | agent-skills-nix | agent-plugins-nix | rigup.nix | Shochraos/agent-skills-nix |
| --- | --- | --- | --- | --- |
| Native Claude plugin tree | no | yes | partial | no |
| Native Codex plugin tree | skills only | yes | no | no |
| Both marketplace catalogs | no | no | reads only | no |
| Ordered patches or overlays | `transform` function | no | partial | `--replace-fail` needles |
| Paired human-only controls | rejected by export | no | no | no |
| Per-skill CLI deps | yes | MCP paths | yes, wrapped | n/a |
| Feeds Home Manager plugin options | no | no | no | n/a |

- [Kyure-A/agent-skills-nix@2948865](https://github.com/Kyure-A/agent-skills-nix/tree/2948865044b2af55c8c4e4eb2abda7de79d60f0e)
  (268★, MIT). Since the September snapshot it has added per-skill `agents = [ … ]`
  targeting
  ([targets.nix](https://github.com/Kyure-A/agent-skills-nix/blob/2948865044b2af55c8c4e4eb2abda7de79d60f0e/lib/targets.nix))
  and selection by final ID. Its plugin
  [export](https://github.com/Kyure-A/agent-skills-nix/blob/2948865044b2af55c8c4e4eb2abda7de79d60f0e/README.md#agent-plugin-export-experimental)
  is still Codex-only and rejects `packages`, `transform`, and
  `disable-model-invocation`.
- [Kyure-A/agent-plugins-nix@324168d](https://github.com/Kyure-A/agent-plugins-nix/tree/324168d2afbb7a50a5c87bed2b59d97291b23512)
  has been unchanged since August. It hard-depends on agent-skills-nix bundles
  and installs by copying. Its
  [Claude](https://github.com/Kyure-A/agent-plugins-nix/blob/324168d2afbb7a50a5c87bed2b59d97291b23512/lib/adapters/claude.nix)
  and
  [Codex](https://github.com/Kyure-A/agent-plugins-nix/blob/324168d2afbb7a50a5c87bed2b59d97291b23512/lib/adapters/codex.nix)
  adapters are useful references for manifest fields.
- [YPares/rigup.nix@ddc116b](https://github.com/YPares/rigup.nix/tree/ddc116bfa215f630ea496a19eff4fd525623ce6b)
  (95★). A riglet module bundles tools, docs, and config, and can `imports`
  other riglets. A rig then wraps the harness for one session. The
  [Claude entrypoint](https://github.com/YPares/rigup.nix/blob/ddc116bfa215f630ea496a19eff4fd525623ce6b/riglets/claude-code.nix#L79-L129)
  passes `--plugin-dir` and `--append-system-prompt`. That's a different model
  from global activation, and I found no Codex riglet.
- [Shochraos/agent-skills-nix@33cb899](https://github.com/Shochraos/agent-skills-nix/tree/33cb899)
  (0★, MIT) is the closest fit for drift handling:
  - `--replace-fail` patches, so upstream drift breaks the build;
  - post-build checks for banned patterns and for whether references resolve;
  - every skill sliced out as its own package, joined by an `mkSkillset` that
    errors on unknown names;
  - a weekly "update, check, push only if green" job.
- Not relevant to us:
  - bitbloxhub/skills-flake has no license.
  - z1-0/skills-nix uses import-from-derivation over the skills.sh registry.
  - mreimbold/claude-plugins-nix is archived.
  - olafkfreund/nix-skills is a content repo.

## Upstream Home Manager client modules

Read at
[home-manager@6407259](https://github.com/nix-community/home-manager/tree/640725978b99076e18e069f6e7d2959124584f8f/modules/programs).

**Claude:**

- **Version detection.** With `package = null`, the module treats the CLI as
  current and uses personal plugins, linking each one to
  `~/.claude/skills/<name>` through a wrapper derivation with per-entry links.
- **Open bug.** [home-manager #9906](https://github.com/nix-community/home-manager/issues/9906)
  is still open. Claude 2.1.257 and later reject those per-entry links as paths
  escaping the plugin, which silently drops manifest-declared components such as
  hooks. The workaround is a whole-directory `home.file` link.
- **Marketplaces.** `marketplaces` emits only local `directory` sources.
  Declaring it as well as `settings.extraKnownMarketplaces` overwrites the
  latter.
- **Disabled plugins.** There's no way to declare one.

**Codex:**

- **Plugins.** `plugins` links into
  `~/.codex/plugins/cache/home-manager/<name>/<version>`. The module owns
  `~/.agents/plugins/marketplace.json`.
- **No disabled state.** It always writes `enabled = true`, which overrides any
  declared `false`.
- **Cache path.** For packages, the path comes from `pname` and version.

**`mutableSettings`** landed on master in October 2026 (#10031, `acd21c5a`).
It isn't in `release-26.05`.

- **How it merges.** An activation step after `linkGeneration` runs a jq
  `$dynamic * $static` merge. Undeclared keys survive, declared arrays are
  replaced, removed declarations leave stale keys, and comments are dropped.
- **Codex.** The merge round-trips TOML through JSON.
- **Pi.** `programs.pi-coding-agent.settings` writes an immutable store link.

There is no upstream OMP module, and #9247 (a shared `programs.agent-skills`
option) is still open.

## Third-party modules and personal configurations

- [tienedev/harnix@faff0df1](https://github.com/tienedev/harnix/tree/faff0df1)
  merges per-project `enabledPlugins` into `.claude/settings.local.json`, adds
  it to `.git/info/exclude`, and removes keys it previously managed but no
  longer declares.
  [pr0d1r2/nix-home-manager-claude-code@e7635f93](https://github.com/pr0d1r2/nix-home-manager-claude-code/tree/e7635f93)
  keeps a similar managed-key ledger.
- The Claude binary (2.1.301) has strings suggesting it skips a skills-dir
  plugin when the merged `enabledPlugins["<name>@skills-dir"]` is `false`. That
  would allow installed-but-disabled Claude plugins without a wrapper.
  Unverified.
- [wimpysworld/nix-config@cfbeedd4](https://github.com/wimpysworld/nix-config/tree/cfbeedd4)
  renders native files for each client from one skill tree, vendors upstream
  skills by copying them, and uses an owned-files ledger to remove stale output.
- [joshsymonds/nix-config@3697691d](https://github.com/joshsymonds/nix-config/tree/3697691d)
  injects a flake-pinned directory marketplace into `extraKnownMarketplaces`.
- [wenjinnn/.dotfiles@96b8960c](https://github.com/wenjinnn/.dotfiles/tree/96b8960c)
  pins official marketplaces with `fetchFromGitHub`, links skills into
  `~/.omp/skills` during activation, and transforms skills to add
  `disable-model-invocation`.
- [ryan4yin/nix-config@643984e1](https://github.com/ryan4yin/nix-config/tree/643984e1)
  links authored skills out of the store, so edits take effect without a
  switch, and asserts against name collisions with upstream inputs.
- None of the four personal configurations declares CLI dependencies per skill.
  All of them use plain `home.packages`.

## Patterns adopted into the plan

- Packaging: `llm-agents.nix` as an input without `follows`; the seven missing
  CLIs packaged locally in its `buildNpmPackage` and `passthru.updater` style.
- Plugin loading: whole-directory personal-plugin links for Claude until #9906
  is fixed; per-repo `settings.local.json` profiles (harnix), pending gate 5.
- Settings: a ledger of managed keys.
- Upstream drift: `--replace-fail` patches, post-build reference checks, and a
  green-only updater.
- Authoring: out-of-store links (ryan4yin, kissgyorgy).
