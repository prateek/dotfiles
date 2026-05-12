---
status: current
doc_type: research
created: 2026-05-10
updated: 2026-05-11
related:
  - chezmoi-agent-skills-plan.md
---

# Agent Skill Management Research

## Scope

This report covers how agent skill ecosystems manage context pressure as skill
counts grow. It is intentionally tool-agnostic except where a tool's behavior
affects OpenAI Codex, Claude Code, or shared `.agents/skills` layouts.

The companion dotfiles implementation plan is
[chezmoi-agent-skills-plan.md](chezmoi-agent-skills-plan.md).

## Summary

The current ecosystem has no single clean answer to "skill groups." Codex has
global and project scopes, plugin enablement, and per-skill config overrides.
Claude Code has user and project skill directories plus plugins. Third-party
tools add package management, audits, token accounting, compaction, and graph
retrieval.

The two primary agents have similar high-level behavior but different control
surfaces. Codex has a hard startup budget for the initial skills list and
uses `[[skills.config]]` plus plugin enablement to remove skills from view.
Claude Code exposes more frontmatter and settings controls: automatic
invocation can be disabled per skill, a skill can be collapsed to name-only,
and plugin skills are namespaced and managed through `/plugin`.

The practical pattern is layered:

- Use package-owned APM manifests, then generate root core projections and
  plugin packages from those package sources.
- Keep package-manager output as reviewed source or vendored content, not as
  live active trees.
- Keep root skill scopes small.
- Use plugin enablement for non-core skill groups.
- Audit duplicate names, duplicate realpaths, description overlap, and token
  cost.
- Merge related micro-skills into one skill with references.
- Use graph retrieval only when the library is too large for a simple active
  allowlist.

For this dotfiles repo, the companion plan now treats APM packages as the source
unit. Package source lives under `home/dot_agents/packages/`, per-package
`apm.yml` files resolve remote skills, vendored remote content stays readable
inside each package, and `chezmoi apply` renders core projections into
`~/.agents/skills` and `~/.claude/skills` plus a local plugin marketplace under
`~/.agents/plugins`. `gh skill` and `npx skills` remain useful discovery and
preview tools. `skills-janitor`, `skill-scanner`, and a local validator are
advisory checks. For a large skill library, Graph of Skills is the serious
retrieval candidate. For a large codebase, `/graphify` is a separate
context-saving tool: it maps the project being edited, not the skills available
to the agent.

## Loading Mechanics

This section distinguishes four surfaces that get conflated in discussions:

- skills: reusable instructions and optional resources;
- plugins: installable packages that can bundle skills and integrations;
- MCP/app/LSP/tool connections: runtime tool surfaces;
- project memory or instruction files: always-on guidance such as `AGENTS.md`
  and `CLAUDE.md`.

Context pressure comes from more than one layer. The skill-description warning
is only one symptom.

### Codex Skills

OpenAI's Codex skills docs define a skill as a directory with `SKILL.md` plus
optional `scripts/`, `references/`, `assets/`, and `agents/openai.yaml`. Codex
starts with each skill's name, description, and file path. It reads the full
`SKILL.md` only after the skill triggers. The startup list is capped at roughly
2% of the model context window, or 8,000 characters when the window is unknown.
When too many skills are installed, Codex shortens descriptions and can omit
skills from the initial list. The budget applies only to the initial list; a
selected skill still loads its full instructions. See [OpenAI Codex skills](https://developers.openai.com/codex/skills).

Codex activates skills in two ways:

- explicit invocation: `/skills` or `$skill-name` in CLI/IDE;
- implicit invocation: the user request matches the skill `description`.

That makes `description` the routing surface. Descriptions should front-load the
trigger words and boundaries because they may be shortened under budget
pressure.

Codex reads skills from repository, user, admin, and system locations. For a
repository, it scans `.agents/skills` from the working directory up to the repo
root. It also reads user skills from `$HOME/.agents/skills`, admin skills from
`/etc/codex/skills`, and bundled system skills. If two skills share the same
`name`, Codex does not merge them; both can appear. Codex follows symlinked
skill folders.

Codex supports per-skill config:

```toml
[[skills.config]]
path = "/path/to/skill"
enabled = false
```

This is the native hook for an active-set renderer. It disables a skill without
deleting it, but it is path-oriented rather than group-oriented. Codex docs say
to restart after changing `~/.codex/config.toml`. See [OpenAI Codex config
reference](https://developers.openai.com/codex/config-reference).

`agents/openai.yaml` adds Codex-specific metadata and behavior. It can configure
display metadata, `policy.allow_implicit_invocation`, and tool dependencies such
as an MCP server. `allow_implicit_invocation: false` keeps explicit `$skill`
invocation available while preventing description-based automatic activation.
This is useful for destructive or expensive workflows that should never trigger
because a prompt vaguely matched the description.

Local verification on 2026-05-10:

```sh
codex --version
codex --help
codex plugin --help
codex features list
```

This Mac has `codex-cli 0.130.0`. The local feature list reports `plugins`,
`multi_agent`, `skill_mcp_dependency_install`, `tool_search`, and `hooks` as
stable and enabled. That does not replace the docs, but it confirms that the
plugin and skill dependency surfaces are live in the installed CLI.

### Codex Plugins

Codex plugins can bundle skills, app integrations, and MCP servers. Plugins are
a distribution unit, not a fine-grained profile system. A plugin can contain:

- skills, which Codex can load when needed;
- apps, such as GitHub, Slack, Gmail, or Google Drive integrations;
- MCP servers, which expose tools or shared data to Codex.

The Codex app and CLI have plugin browsers. In the CLI, `/plugins` opens the
plugin list, grouped by marketplace. Installed plugins can be toggled. A user
can ask for the desired outcome and let Codex select the installed tools, or use
`@` to invoke a specific plugin or bundled skill. See [OpenAI Codex plugins](https://developers.openai.com/codex/plugins).

Installed plugin workflows become available to Codex, but normal approval
settings still apply. If the plugin bundles apps, Codex may prompt for
authentication during setup or first use. If the plugin bundles MCP servers,
those servers may need setup or authentication before use. Uninstalling a plugin
removes the bundle from Codex, but bundled apps may remain installed until
managed in ChatGPT. To keep a plugin installed but disabled, set:

```toml
[plugins."plugin-id@marketplace"]
enabled = false
```

Codex plugin authoring uses a `.codex-plugin/plugin.json` manifest. A minimal
plugin can package one skill by pointing `"skills"` at a skills directory. For
local distribution, Codex supports repo and personal marketplaces:

- repo marketplace: `$REPO_ROOT/.agents/plugins/marketplace.json`, with plugin
  folders under `$REPO_ROOT/plugins/`;
- personal marketplace: `~/.agents/plugins/marketplace.json`; local catalog
  entries can point at generated plugin source roots, and Codex installs or
  caches plugin copies under its own plugin directories.

Marketplace sources can be GitHub shorthand, git URLs, local roots, or sparse
checkout paths. See [OpenAI Codex build plugins](https://developers.openai.com/codex/plugins/build).

Practical implication: use local skill folders for iteration and repo-specific
workflows. Use plugins when a workflow should be installed, versioned, bundled
with apps or MCP, or distributed beyond one repo.

### Claude Code Skills

Claude Code skills also use the open Agent Skills standard, but Claude exposes
more behavior through frontmatter and settings. Claude says a skill body loads
only when used, while the description and invocation metadata let Claude decide
whether to use it. Skills can be invoked directly as `/skill-name`. Custom
commands now share the same model: `.claude/commands/deploy.md` and
`.claude/skills/deploy/SKILL.md` both create `/deploy`, but skills are the
recommended shape for supporting files and richer behavior. See [Claude Code
skills](https://code.claude.com/docs/en/skills).

Claude Code reads skills from:

- enterprise or managed settings;
- personal skills at `~/.claude/skills/<skill-name>/SKILL.md`;
- project skills at `.claude/skills/<skill-name>/SKILL.md`;
- plugin skills at `<plugin>/skills/<skill-name>/SKILL.md`.

Precedence differs from Codex. When standalone skills share a name, enterprise
overrides personal and personal overrides project. Plugin skills are namespaced
as `plugin-name:skill-name`, so they do not collide with standalone skills.
Claude also discovers nested `.claude/skills/` directories for monorepos, and
skills under directories passed with `--add-dir`.

Claude watches existing skill directories during a session. Adding, editing, or
removing skills under watched locations takes effect without a restart, but
creating a top-level skills directory that did not exist at startup requires a
restart so Claude can watch it.

Important frontmatter controls:

- `description`: recommended routing text. Claude truncates combined
  `description` plus `when_to_use` at 1,536 characters in the skill listing.
- `when_to_use`: extra routing guidance that counts against that same cap.
- `disable-model-invocation: true`: prevents Claude from automatic loading.
  The description is not listed to Claude, but the user can still invoke it.
- `user-invocable: false`: hides from the `/` menu, but does not block
  programmatic invocation.
- `allowed-tools`: pre-approves listed tools while the skill is active, subject
  to broader permission rules.
- `context: fork` and `agent`: run the skill in an isolated subagent context.
- `paths`: limit automatic activation to matching file paths.

Claude's lifecycle detail matters for context planning. When a skill is invoked,
the rendered `SKILL.md` enters the conversation and stays there for the rest of
the session. Auto-compaction re-attaches recent invoked skills within budget,
keeping the first 5,000 tokens of each and using a combined 25,000-token budget
for re-attached skills. Older invoked skills can be dropped after compaction if
many skills have been used in the same session.

Claude supports dynamic context injection inside skills with `!` shell syntax.
Those commands run before the model sees the skill content, and their output is
substituted into the prompt. This is powerful but security-sensitive. Managed
settings can disable shell execution for user, project, plugin, or
additional-directory skills with `disableSkillShellExecution`.

Claude skill access can be restricted in several ways:

- deny the `Skill` tool in permissions;
- allow or deny specific `Skill(name)` or `Skill(name *)` entries;
- set `disable-model-invocation: true` in the skill;
- use `skillOverrides` in settings.

`skillOverrides` has four states: `"on"` lists name and description,
`"name-only"` lists the name only, `"user-invocable-only"` hides it from Claude
but keeps it in the menu, and `"off"` hides it entirely. Plugin skills are not
affected by `skillOverrides`; manage plugin skills through `/plugin`.

Local verification on 2026-05-10:

```sh
claude --version
claude --help
claude plugin --help
```

This Mac has Claude Code `2.1.138`. The local CLI exposes `--plugin-dir`,
`--plugin-url`, `--disable-slash-commands`, `--bare`, and `plugin` commands for
enable, disable, install, list, update, validate, and marketplace management.
`--bare` skips hooks, LSP, plugin sync, attribution, auto-memory, background
prefetches, keychain reads, and CLAUDE.md auto-discovery, while skills still
resolve via explicit `/skill-name`.

### Claude Code Plugins

Claude Code plugins package skills, agents, hooks, MCP servers, LSP servers,
monitors, output styles, and themes. Standalone `.claude/` configuration is for
personal workflows, project-specific customizations, and experiments. Plugins
are for sharing, versioned releases, marketplaces, and cross-project reuse. See
[Claude Code create plugins](https://code.claude.com/docs/en/plugins).

Plugin skills live in the plugin root under `skills/`. The plugin manifest lives
at `.claude-plugin/plugin.json`; skills are namespaced by plugin name, such as
`/my-plugin:hello`. Claude can invoke plugin skills automatically based on task
context, and users can invoke them directly.

Plugin marketplaces are catalogs. Adding a marketplace only registers a source;
users still install individual plugins from that catalog. The official
Anthropic marketplace is `claude-plugins-official`; Claude also supports custom
marketplaces from GitHub, other git hosts, local paths, remote URLs, and
team-required marketplace settings. See [Claude Code plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces)
and [discover plugins](https://code.claude.com/docs/en/discover-plugins).

Claude plugin components affect context and runtime in different ways:

- Skills and commands are discovered when a plugin is installed. Claude can
  invoke them automatically based on task context.
- Plugin agents appear in `/agents`, can be manually or automatically invoked,
  and support a defined frontmatter set.
- Plugin hooks respond to lifecycle events such as `UserPromptSubmit`,
  `PreToolUse`, `PostToolUse`, `PreCompact`, `PostCompact`, and
  `InstructionsLoaded`.
- Plugin MCP servers start automatically when the plugin is enabled and appear
  as standard MCP tools.
- Plugin LSP servers provide diagnostics and code navigation, but the language
  server binary must be installed separately.
- Plugin monitors can run persistent background commands in interactive CLI
  sessions and deliver notifications to Claude.

See [Claude Code plugins reference](https://code.claude.com/docs/en/plugins-reference).

Practical implication: a plugin is more than a skill bundle. Enabling a plugin
may add skills, tool surfaces, hooks, background monitors, and server processes.
Treat plugin enablement as an operational change, not just a context change.

### Codex vs Claude Code: Loading Differences

| Surface | Codex | Claude Code |
| --- | --- | --- |
| User skills | `$HOME/.agents/skills` | `~/.claude/skills` |
| Project skills | `.agents/skills` from CWD up to repo root | `.claude/skills`, plus nested and `--add-dir` skill dirs |
| Duplicate standalone names | Not merged; both can appear | Enterprise overrides personal; personal overrides project |
| Plugin skill names | Invoked through plugin/bundled skill UI, `@` for specificity | Namespaced as `/plugin-name:skill-name` |
| Startup budget | Initial skill list capped around 2% of context or 8,000 chars | Description listing truncated; `description + when_to_use` cap is 1,536 chars |
| Disable skill | `[[skills.config]] enabled = false` by path | `disable-model-invocation`, `skillOverrides`, or Skill permissions |
| Hide from model but keep manual use | `allow_implicit_invocation: false` in `agents/openai.yaml` | `disable-model-invocation: true` or `skillOverrides = "user-invocable-only"` |
| Full skill body lifetime | Loaded when selected | Rendered skill stays in conversation; compaction reattaches recent skills under budget |
| Plugin MCP behavior | Plugins can bundle MCP servers that may need setup/auth | Plugin MCP servers start automatically when plugin is enabled |
| Local iteration | Skill folders for authoring; plugins for distribution | Standalone `.claude/` first, plugin when sharing or versioning |

### Implications For Skill Management

For context-budget management, count four things separately:

1. startup skill metadata;
2. full invoked skill bodies;
3. plugin-provided tools, hooks, servers, monitors, and app surfaces;
4. always-on instruction files.

Do not assume disabling automatic invocation is equivalent across tools. In
Codex, `allow_implicit_invocation: false` changes routing but still leaves the
skill explicitly available. In Claude Code, `disable-model-invocation: true`
keeps manual invocation while removing the skill from Claude's context listing.
In Claude Code, `skillOverrides` can further collapse a skill to name-only or
turn it off without editing `SKILL.md`.

For plugin management, audit runtime side effects as well as context cost. A
plugin can be cheap in description tokens while expensive in hooks, monitors,
MCP servers, auth prompts, or background LSP diagnostics.

## Community Signal

Hacker News discussion around skills mostly agrees on the mechanical model:
skill bodies load on demand, but skill names and descriptions still add startup
context and routing noise. See the HN thread under ["You need to rewrite your
CLI for AI agents"](https://news.ycombinator.com/item?id=47258780).

Reddit discussion in `r/ClaudeCode` shows the user-facing version of the same
problem. People install broad skill packs, notice large metadata or startup
cost, then consolidate related skills and remove unused ones. The numbers are
anecdotal, but the behavior matches the official docs. See [How many Claude
skills are too many?](https://www.reddit.com/r/ClaudeCode/comments/1p8wipb/how_many_claude_skills_are_too_many/).

A trailing 30-day sweep across Reddit, TikTok, and GitHub (run 2026-05-10 via
the `last30days` skill) surfaced more concrete evidence:

- [r/ClaudeCode, "I audited 30 days of my Claude Code sessions and 80% of
  installed skills had zero invocations"](https://www.reddit.com/r/ClaudeCode/comments/1syx4tr/i_audited_30_days_of_my_claude_code_sessions_and/)
  (2026-04-29). The author parsed `~/.claude/projects/*.jsonl` and reported
  65 skills installed, 13 ever invoked, 52 idle, roughly 500k tokens spent on
  descriptions that never routed to anything. Comments are mostly "share the
  script." This is the most concrete usage data in the window and it confirms
  that the audit step in `skills-janitor` is solving a real, measured problem.
- [r/ClaudeAI, "Your Claude Code agent is always working from stale
  context"](https://www.reddit.com/r/ClaudeAI/comments/1t3du61/your_claude_code_agent_is_always_working_from/)
  (2026-05-04, 61 upvotes, 44 comments). Reframes the visible "2% skills
  budget" warning as a symptom: the dominant pain is what gets re-loaded
  outside skills (re-read files, repeated grep, forgotten call sites), not
  the skill-description slice itself. Useful framing for prioritization.
- [r/ClaudeAI, "Lessons from building a coding agent for 8k context
  windows"](https://www.reddit.com/r/ClaudeAI/comments/1sydf0t/lessons_from_building_a_coding_agent_for_8k/)
  (2026-04-28). Treats subagent isolation as the architectural fix: delegate
  token-heavy subtasks into a clean window, return only the result. The 8k
  crowd has the most worked-out version of the pattern, but it generalizes
  to any agent that wants to keep the main thread small.
- [r/ClaudeAI, "Feature suggestion: proactive context-rot detection and
  task-scoped handoff"](https://www.reddit.com/r/ClaudeAI/comments/1t8batc/feature_suggestion_proactive_contextrot_detection/)
  (2026-05-09). Active feature request, not shipped. Notable as evidence
  that users want the harness to detect drift across unrelated tasks rather
  than rely on the user to remember `/compact`.
- [TikTok, @thinkingloud66, "5 hidden Claude Code commands"](https://www.tiktok.com/@thinkingloud66/video/7637492290277100814)
  (2026-05-08). Highlights `/compact`, `/btw`, `ultrathink`, and `#` as the
  in-session levers most users do not know exist. These are runtime knobs,
  not skills, but they reduce demand for skills and are the highest-ROI
  starting point.

Searches across X/Twitter produced mostly anecdotes, reposts, and launch posts.
I did not find a mature grouping tool there that was stronger than the GitHub
projects below. Note that the 30-day social discourse named only `/graphify`
and the audit-your-own-jsonl pattern; none of `skills-janitor`, `claude-trim`,
or `skill-compact` surfaced in trending posts. They exist on GitHub with
documentation but have not yet broken into the social conversation, so users
are reinventing the audit step with one-off scripts rather than reaching for
the existing tools.

## Package Managers

### APM

Microsoft's APM is an agent-configuration dependency manager. It uses
`apm.yml` as the manifest and `apm.lock.yaml` as the generated lockfile, then
deploys skills, prompts, instructions, plugins, MCP servers, hooks, and related
agent primitives into the targets it detects. It supports Codex, Claude Code,
GitHub Copilot, Cursor, OpenCode, Gemini, Windsurf, and a generic
`agent-skills` target. See [APM](https://microsoft.github.io/apm/) and
[APM install](https://microsoft.github.io/apm/reference/cli/install/).

APM is stronger than `gh skill` or `npx skills` when reproducibility matters:
it resolves transitive dependencies, writes exact commits and content hashes to
`apm.lock.yaml`, supports frozen installs, and has built-in audit and policy
surfaces. The dependency syntax covers GitHub shorthand, arbitrary git hosts,
subdirectories, single primitive files, local paths, aliases, and pinned refs.
See [APM dependency management](https://microsoft.github.io/apm/consumer/manage-dependencies/)
and [APM lockfile spec](https://microsoft.github.io/apm/reference/lockfile-spec/).

The native behavior also creates an ownership problem for chezmoi. APM wants to
deploy files into tool-native paths such as `.agents/skills/` and
`.claude/skills/`, and it tracks those deployed files in the lockfile. This repo
already needs `home/dot_agents/` to be the readable source of truth and
`$HOME/.agents/skills` to be a generated projection. Direct `apm install`
against the live tree would mix resolver output, runtime projection, and human
policy in the same place.

Recommended role in this repo:

1. Edit the relevant `home/dot_agents/packages/<package>/apm.yml`.
2. Run APM in a staging tree with `--only=apm --target agent-skills`, not
   directly against live projections.
3. Commit that package's `apm.lock.yaml` as the resolved dependency record.
4. Copy expanded remote skills into
   `home/dot_agents/packages/<package>/skills/vendor/` for review.
5. Let local renderers generate the core skill projections and shared plugin
   marketplace. Chezmoi materializes those generated outputs into `$HOME`.

Local verification on 2026-05-11:

```sh
command -v apm
apm --version
apm targets --json --all
apm install --dry-run --only=apm --target agent-skills
apm audit --ci --no-policy --format json
```

This Mac has APM `0.13.0`. A temporary `apm init --yes` project confirmed that
`agent-skills` is a recognized meta-target, dry-run install works without
mutating files, and `apm audit --ci --no-policy --format json` reports a
passing no-dependency baseline.

### GitHub CLI `gh skill`

GitHub launched `gh skill` in public preview on 2026-04-16. It can search,
preview, install, update, and publish agent skills from GitHub repositories. It
supports multiple agents, including Codex and Claude Code, and can pin installs
to tags or commits. GitHub warns that skills are not verified, so previewing
before install is part of the operating model. See [GitHub changelog: Manage
agent skills with GitHub CLI](https://github.blog/changelog/2026-04-16-manage-agent-skills-with-github-cli/).

Local verification on 2026-05-10:

```sh
gh --version
gh skill --help
```

This Mac has `gh 2.91.0`, and `gh skill` is available.

Use this when the source is a GitHub repo and provenance matters.

### `npx skills`

`npx skills` is the skills.sh-oriented CLI. It supports `add`, `remove`, `list`,
`find`, `update`, `init`, project and global installs, target-agent flags,
target-skill flags, and symlink versus copy installs. It supports Codex and many
other agents. See [vercel-labs/skills](https://github.com/vercel-labs/skills).

Local verification on 2026-05-10:

```sh
npx --yes skills --help
```

Use this for skills.sh discovery and multi-agent install workflows. It is a
package manager, not a context optimizer.

## Audit And Cleanup Tools

### `skills-janitor`

`skills-janitor` is the most directly useful existing audit tool for this
problem. It advertises support for Claude Code and OpenAI Codex, scans installed
skills, reports broken skills and duplicates, tracks usage, estimates context
token cost, searches GitHub, and checks overlap before install. See
[khendzel/skills-janitor](https://github.com/khendzel/skills-janitor).

The v1.2 README is particularly relevant because it addresses problems that
show up in shared agent setups:

- name collisions at different real paths;
- symlink shadows that should be deduped by realpath;
- token-cost double counting caused by symlinks;
- pre-install overlap checks;
- usage reports for unused skills.

This maps well to a chezmoi-managed skill tree, but the path assumptions need
testing. `skills-janitor` knows about `~/.claude/skills/` and
`~/.agents/skills/`. In this plan, canonical skill content lives under
`home/dot_agents/packages/<package>/skills/local/` and
`home/dot_agents/packages/<package>/skills/vendor/`; `$HOME/.agents/skills` and
`$HOME/.claude/skills` are generated materialized output. The first experiment
should run on a copied projection, not on the canonical source tree.

Recommended use:

- Run `/janitor-audit`, `/janitor-report`, and `/janitor-tokens` as advisory
  checks.
- Treat `/janitor-fix` as read-only until its patch behavior is inspected on a
  copy.
- Use `/janitor-precheck` before adding third-party skills.
- Do not let it delete skills that are managed by chezmoi; deletion should be a
  repo change.

### `claude-trim`

`claude-trim` is a static analyzer for Claude Code startup token cost. It scans
Claude config, counts token cost for skills and MCP servers, and flags
conflicts. It is Claude-oriented, but the accounting model is useful for Codex
because Codex has the same startup metadata pressure. See
[d0d012/claude-trim](https://github.com/d0d012/claude-trim).

This is best treated as a reference implementation unless its path model can be
adapted cleanly.

### `skill-compact`

`skill-compact` scans installed skills, groups overlap, writes compacted output,
validates against the agent skills spec, and records source provenance. Its
strategy vocabulary is useful: merge, absorb, extract shared boilerplate,
refactor a monolith into references, or leave the skill alone. See
[JuanJoseGonGi/skill-compact](https://github.com/JuanJoseGonGi/skill-compact).

The repo is young and low-star. It should run only against a copied tree. The
workflow is still valuable even if the implementation is not adopted wholesale.

### `skill-scanner`

`skill-scanner` detects prompt injection, exfiltration patterns, and suspicious
code in agent skills. It supports Codex and Cursor skill formats and has CI and
pre-commit examples. See [cisco-ai-defense/skill-scanner](https://github.com/cisco-ai-defense/skill-scanner).

This belongs in the third-party import path. It is not a proof of safety, but it
is a cheap guard before enabling a marketplace skill.

### Audit-your-own-jsonl (DIY pattern)

The most common workflow surfacing on Reddit in the last 30 days is not a
packaged tool. It is a short script that walks `~/.claude/projects/*.jsonl`,
counts tool/skill invocations per session, and prints skills with zero hits over
the trailing window. See the [r/ClaudeCode audit
post](https://www.reddit.com/r/ClaudeCode/comments/1syx4tr/i_audited_30_days_of_my_claude_code_sessions_and/)
for a concrete result on a 65-skill install.

This is the same job `skills-janitor` already does (the `/janitor-tokens` and
usage report commands), but the social signal suggests users either do not know
about it or do not trust an opaque tool to delete from `~/.claude/`. A 30-line
script with visible output and no write side effects is winning the discourse.

Operational implication for this dotfiles repo: a small home-grown auditor that
emits a list and lets the user prune by editing chezmoi source is more aligned
with the repo model than running `skills-janitor --fix` against the materialized
tree. The auditor should read jsonl, not just the skills directory, so it
captures real usage rather than presence.

## Graph And Retrieval Tools

### `/graphify`

`/graphify` is the user-facing skill command from `safishamsi/graphify`. The
project describes itself as an AI coding assistant skill for Claude Code,
Codex, OpenCode, Cursor, Gemini CLI, and other agents. It turns a folder of
code, SQL schemas, scripts, docs, papers, images, or videos into a queryable
knowledge graph. See [safishamsi/graphify](https://github.com/safishamsi/graphify).

It is the only context-saving skill that broke through to broad social signal
in the last 30 days: the [author's launch
post](https://www.reddit.com/r/ClaudeAI/comments/1t18eeh/i_built_graphify_26_days_450k_downloads_40k_stars/)
(2026-05-01, 1.7k upvotes, 208 comments) reported 450k+ PyPI downloads and
~40k GitHub stars in 26 days, and claims 71x fewer tokens per query versus
reading raw files. Take the multiplier as marketing, but the adoption curve is
real and matches the engagement signal.

As of 2026-05-10, live GitHub metadata reported roughly 46k stars, 5k forks,
MIT license, and recent updates. The README says the official PyPI package is
`graphifyy`, while the CLI command is `graphify`. It installs into Codex with:

```sh
uv tool install graphifyy
graphify install --platform codex
```

The project says Codex invokes the skill as `$graphify`, while Claude-style
interfaces use `/graphify`. It also says Codex users need `multi_agent = true`
under `[features]` in `~/.codex/config.toml`.

Graphify outputs:

```text
graphify-out/
  graph.html
  GRAPH_REPORT.md
  graph.json
```

It can also install a small assistant integration that tells the agent to read
`GRAPH_REPORT.md` before answering project questions. On platforms with hooks,
the hook can fire before file-read calls so the assistant consults the graph
before grepping the repo.

Important distinction: Graphify solves source-context churn, not the skill-list
startup warning. It maps the project being edited. It does not select which
skills Codex should see at startup. It is still relevant because both problems
come from the same pressure: agents repeatedly spend context discovering
structure.

Good uses:

- Large unfamiliar codebases.
- Architecture archaeology.
- Repeated repo questions where agents keep re-reading the same files.
- Cross-document maps when code, docs, schemas, and diagrams all matter.

Risks and operational notes:

- `graphify-out/` is generated state. Decide per repo whether to commit it.
- The README recommends committing some output for teams, but local dotfiles
  should not blindly commit generated graphs.
- Code extraction is described as local via tree-sitter. Non-code inputs can
  use model APIs or optional transcription/OCR paths, so privacy depends on
  flags and file types.
- Hooks that influence file-read behavior should be explicit and reversible.
- Third-party install should be scanned and reviewed before global activation.

Recommendation: keep Graphify out of the core skill-management path. Document
it as a project-context tool and pilot it in one large repo before making it a
default dotfiles capability.

### Graph of Skills

Graph of Skills is the directly relevant retrieval system for large skill
libraries. It builds an offline graph from `SKILL.md` documents, then retrieves
a small ranked skill bundle at task time. The repository describes a pipeline of
semantic and lexical candidate seeding, graph-based reranking, and
context-budgeted hydration. See [davidliuk/graph-of-skills](https://github.com/davidliuk/graph-of-skills).

The associated paper, [Graph of Skills: Dependency-Aware Structural Retrieval
for Massive Agent Skills](https://arxiv.org/abs/2604.05333), argues that large
skill libraries create two problems: loading everything saturates context, and
simple vector retrieval misses dependency structure. Their reported results on
SkillsBench and ALFWorld show higher reward than vanilla full skill loading and
simple vector retrieval, with lower token use than vanilla loading.

As of 2026-05-10, the GitHub repo reported MIT license, recent updates, and a
Claude Code MCP plugin. It requires Python 3.10-3.12, `uv` or `pip`, and an
embedding provider key for indexing unless using a compatible prebuilt
workspace.

Important distinction: Graph of Skills maps the skill library. Graphify maps
the target project. GoS is therefore closer to a replacement for broad skill
discovery. A practical integration would expose one small "skill retriever"
skill or MCP, then keep the long tail of skills outside the normal startup
scanner.

Good uses:

- Hundreds or thousands of skills.
- Skills with real dependencies or prerequisites.
- Benchmarked experiments around skill routing.
- A future "search my skill library" assistant.

Risks and operational notes:

- It adds embeddings, a workspace, and retrieval infrastructure.
- It is research-grade compared with simpler active allowlists.
- It does not automatically fix Codex startup metadata unless the active skill
  set is changed to expose only the retriever.
- Its benchmark setup may not match personal dotfiles workflows.

Recommendation: do not make Graph of Skills the first implementation. Revisit
after basic allowlisting and compaction if active descriptions still exceed the
Codex budget or if the skill library grows beyond what an allowlist can handle.

### In-Session Context Levers (built-ins, not skills)

These are not part of the skill-management surface, but they reduce demand for
skills and surfaced repeatedly in the last 30 days as the highest-ROI lever
most users do not know exists. See the [TikTok
walkthrough](https://www.tiktok.com/@thinkingloud66/video/7637492290277100814)
(2026-05-08) for the cleanest summary:

- `/compact` compresses the running chat while keeping load-bearing context.
  Use before a long task transitions to a new task.
- `/btw` opens a side overlay for quick questions without polluting the main
  conversation.
- `ultrathink` (plain text, not a slash command) unlocks the maximum thinking
  budget (~32K tokens).
- `#` saves an arbitrary snippet to the long-term scratch.

[Subagents](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/subagents)
are the architectural complement: delegate a token-heavy subtask into a clean
window and return only the result. The [r/ClaudeAI 8k-window
post](https://www.reddit.com/r/ClaudeAI/comments/1sydf0t/lessons_from_building_a_coding_agent_for_8k/)
is the most worked-out community example.

These belong in the operating model before any retrieval or pointer system.
Most "skill sprawl" reports turn out to be context fatigue from accumulated
chat state, not from skill descriptions.

### SkillPointer And Other Pointer Systems

SkillPointer moves raw skills outside active scanner paths and replaces them
with lightweight category pointer skills. See [blacksiders/SkillPointer](https://github.com/blacksiders/SkillPointer).

This is the same architectural idea as Graph of Skills, but simpler: expose a
small router or pointer layer, then hydrate real skills later. It can reduce
startup metadata quickly, but it also creates another routing layer that has to
stay accurate.

Use pointer systems only when grouping and compaction are not enough.

## Comparison

| Tool | Primary job | Solves skill startup warning? | Best local role |
| --- | --- | --- | --- |
| APM | Resolve and lock agent config dependencies | Partly | Third-party resolver and lockfile layer |
| `gh skill` | Install and publish GitHub-hosted skills | No | Provenance-aware package manager |
| `npx skills` | Install skills.sh and GitHub skills | No | Discovery and multi-agent install |
| `skills-janitor` | Audit, token cost, usage, duplicates | Partly | First health check |
| `claude-trim` | Static startup token analysis | Partly | Reference for token accounting |
| `skill-compact` | Merge and dedupe skills | Partly | Run on copied tree for compaction ideas |
| `skill-scanner` | Security and prompt-injection scan | No | Third-party import guard |
| `/graphify` | Project knowledge graph | No | Repo-context accelerator |
| Graph of Skills | Skill-library retrieval | Yes, with integration | Future large-library retriever |
| SkillPointer | Category pointer layer | Yes, with discipline | Lightweight retriever alternative |

## Recommended Operating Model

For a personal dotfiles-managed skill library, in steady state after the plan's
package and plugin phases:

1. Keep package-owned source under `home/dot_agents/packages/<package>/`, with
   local skills under `skills/local/`, vendored remote skills under
   `skills/vendor/`, and desired state in that package's `package.toml`.
2. Do not move package source under `home/.chezmoidata/`; use chezmoi data only
   for structured template inputs, not skill and plugin source trees.
3. Keep one `apm.yml` per package. Commit that package's `apm.lock.yaml` when
   it has remote APM dependencies.
4. Render `~/.agents/skills` and `~/.claude/skills` from the `core` package at
   `chezmoi apply` time. Do not commit generated source copies.
5. Render `~/.agents/plugins` as the shared local marketplace for non-core
   packages, carrying both Codex and Claude plugin manifests.
6. Use agent config files for desired marketplace registration and plugin
   enablement, and use native CLIs for tool-owned plugin caches.
7. Put repo-specific skills in repo scope, not global scope.
8. Teach the in-session levers first (`/compact`, `/btw`, `ultrathink`,
   subagent delegation). They beat any skill-management work on ROI and most
   users are not using them.
9. Audit real usage from `~/.claude/projects/*.jsonl` before pruning by name.
   A skill that loads its description on every request but never invokes is
   the canonical waste; only jsonl reveals it.
10. Use `gh skill preview`, `npx skills add --list`, or
   `apm install --dry-run --only=apm --target agent-skills` before accepting a
   third-party skill.
11. Scan third-party skills before activation.
12. Run a janitor-style report before enabling a new package.
13. Collapse related skills into one skill with references.
14. Revisit Graph of Skills only when skill count is too large for package
    enablement to manage.
15. Treat Graphify as a per-repo context tool, not a skill manager.

## Bibliography

- OpenAI, [Agent Skills](https://developers.openai.com/codex/skills).
- OpenAI, [Configuration Reference](https://developers.openai.com/codex/config-reference).
- OpenAI, [Plugins](https://developers.openai.com/codex/plugins).
- OpenAI, [Build plugins](https://developers.openai.com/codex/plugins/build).
- Microsoft, [APM](https://microsoft.github.io/apm/).
- Microsoft, [APM dependency management](https://microsoft.github.io/apm/consumer/manage-dependencies/).
- Microsoft, [APM install](https://microsoft.github.io/apm/reference/cli/install/).
- Microsoft, [APM lockfile specification](https://microsoft.github.io/apm/reference/lockfile-spec/).
- Anthropic, [Agent Skills overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview).
- Anthropic, [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).
- Anthropic, [Claude Code skills](https://code.claude.com/docs/en/skills).
- Anthropic, [Claude Code create plugins](https://code.claude.com/docs/en/plugins).
- Anthropic, [Claude Code discover plugins](https://code.claude.com/docs/en/discover-plugins).
- Anthropic, [Claude Code plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces).
- Anthropic, [Claude Code plugins reference](https://code.claude.com/docs/en/plugins-reference).
- GitHub, [Manage agent skills with GitHub CLI](https://github.blog/changelog/2026-04-16-manage-agent-skills-with-github-cli/).
- Vercel Labs, [`skills`](https://github.com/vercel-labs/skills).
- Khendzel, [`skills-janitor`](https://github.com/khendzel/skills-janitor).
- d0d012, [`claude-trim`](https://github.com/d0d012/claude-trim).
- JuanJoseGonGi, [`skill-compact`](https://github.com/JuanJoseGonGi/skill-compact).
- Cisco AI Defense, [`skill-scanner`](https://github.com/cisco-ai-defense/skill-scanner).
- Safi Shamsi, [`graphify`](https://github.com/safishamsi/graphify).
- Dawei Liu et al., [`graph-of-skills`](https://github.com/davidliuk/graph-of-skills).
- Dawei Liu et al., [Graph of Skills paper](https://arxiv.org/abs/2604.05333).
- blacksiders, [`SkillPointer`](https://github.com/blacksiders/SkillPointer).
- Hacker News, [discussion of skill loading behavior](https://news.ycombinator.com/item?id=47258780).
- Reddit, [`r/ClaudeCode`: How many Claude skills are too many?](https://www.reddit.com/r/ClaudeCode/comments/1p8wipb/how_many_claude_skills_are_too_many/).
- Reddit, [`r/ClaudeCode`: 30-day audit of installed skills with zero invocations](https://www.reddit.com/r/ClaudeCode/comments/1syx4tr/i_audited_30_days_of_my_claude_code_sessions_and/).
- Reddit, [`r/ClaudeAI`: stale-context rewind/replay](https://www.reddit.com/r/ClaudeAI/comments/1t3du61/your_claude_code_agent_is_always_working_from/).
- Reddit, [`r/ClaudeAI`: 8k-window subagent isolation lessons](https://www.reddit.com/r/ClaudeAI/comments/1sydf0t/lessons_from_building_a_coding_agent_for_8k/).
- Reddit, [`r/ClaudeAI`: proactive context-rot detection request](https://www.reddit.com/r/ClaudeAI/comments/1t8batc/feature_suggestion_proactive_contextrot_detection/).
- Reddit, [`r/ClaudeAI`: graphify launch and adoption](https://www.reddit.com/r/ClaudeAI/comments/1t18eeh/i_built_graphify_26_days_450k_downloads_40k_stars/).
- TikTok, [@thinkingloud66 on `/compact`, `/btw`, `ultrathink`, `#`](https://www.tiktok.com/@thinkingloud66/video/7637492290277100814).
