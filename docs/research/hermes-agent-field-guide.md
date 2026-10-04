---
status: active
doc_type: research
owner: Prateek
created: 2026-10-02
updated: 2026-10-02
related:
  - self-improving-agents.md
status_detail: "Primary-source field guide to NousResearch hermes-agent at bed0d535 (v0.21.5 line): install paths, ~/.hermes layout, providers, skills, memory, ACP/MCP, gateway, security, and how it would fit this repo's agent catalogue."
---

# Hermes Agent Field Guide

Every claim below links to the owning file in
[NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent),
pinned to commit `bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1` (tip of `main` on
2026-10-02). Docs links point at the Markdown sources under `website/docs/`,
which the docs site renders. Release metadata comes from the GitHub releases
API, and two package-index observations come from local `pip` and `brew`
queries run on 2026-10-02. Those are labelled where they appear.

## 1. What it is

Hermes Agent is a Python agent runtime from Nous Research that pitches itself
as "the self-improving AI agent" with a built-in learning loop
([README L19][readme-19]). One `AIAgent` core (`run_agent.py`) sits behind
several entry points: the CLI (`cli.py`), the messaging gateway
(`gateway/run.py`), the ACP adapter (`acp_adapter/`), a batch runner, an API
server, and a Python library ([architecture.md L9-L36][arch]). The loop talks
to models in three API modes, `chat_completions`, `codex_responses`, and
`anthropic_messages`, chosen from the provider and base URL
([agent-loop.md L41-L58][agentloop]). One gateway process serves Telegram,
Discord, Slack, WhatsApp, Signal, and the CLI ([README L25][readme-25]), and
the docs tree carries adapters for about 35 platforms including Teams, Matrix,
Email, and Home Assistant ([messaging/][msg-dir]). The learning loop has
three parts. The agent curates bounded memory files with periodic nudges, it
creates skills after complex tasks, and it searches past sessions through
SQLite FTS5 ([README L26][readme-26]). A memory nudge fires every 10 user turns
and a skill-creation nudge every 15 tool-calling iterations by default
([cli-config.yaml.example L1014-L1016][cfgex-mem],
[L1150-L1156][cfgex-skills]). A separate curator ages agent-created skills
through `active → stale → archived` on a 7-day interval
([curator.md L9-L24][curator]). Scheduling is a built-in cron whose ticker runs
inside the gateway every 60 seconds. A plain CLI session does not fire jobs
([cron-troubleshooting.md L37-L41][crontrouble]). Jobs live in
`~/.hermes/cron/jobs.json` ([cron.md L28][cron-28]).

**Version and cadence.** The committed project version is always `0.0.0`.
Release jobs stamp the real version at build time
([stable-releases.md L8-L10][stable], [pyproject.toml L1-L3][pyproj-1]). The
latest GitHub release is **Hermes Agent v0.21.5**, tagged `v2026.9.24` and
published 2026-09-24. It rolled up about 460 PRs since v0.21.4
(releases API). The repo has 36 releases on the
calendar-tag scheme, shipping every 3 to 7 days through August and September
2026 (`v2026.8.31`, `9.7`, `9.11`, `9.14`, `9.21`, `9.24`). No release has
any attached assets (releases API, `assets=[]` on all recent releases).

## 2. Install paths

| Path | Support tier | Code | Launcher | User data |
|---|---|---|---|---|
| `curl -fsSL https://hermes-agent.nousresearch.com/install.sh \| bash` | Tier 1 (macOS Apple Silicon, Linux) | `~/.hermes/hermes-agent/` git checkout | `~/.local/bin/hermes` wrapper | `~/.hermes/` |
| Desktop DMG/ZIP (`Hermes.app`) | Tier 1 | inside the app bundle | packaged launchers | platform default home |
| Docker `nousresearch/hermes-agent` | Tier 1 | `/opt/hermes/` | image entrypoint | mounted `/opt/data/` |
| Nix flake (`nix profile install github:NousResearch/hermes-agent`, NixOS and Home Manager modules) | Tier 2, best effort | Nix store | `hermes`, `hermes-agent`, `hermes-acp` | `~/.hermes/` |
| PyPI (`pip`/`uv tool`/`pipx install hermes-agent`) | **Unsupported** | n/a | n/a | n/a |
| Homebrew (`brew install hermes-agent`) | **Unsupported** | n/a | n/a | n/a |

Sources: [platform-support.md L13-L62][platsup],
[installation.md L96-L104][install-layout], [nix-setup.md L66-L81][nix],
[docker.md L14, L51-L53][docker]. The flake also exports
`homeManagerModules.default` ([flake.nix L49-L52][flake]).

**Binaries.** `hermes` (main CLI), `hermes-agent` (legacy entry), and
`hermes-acp` (ACP server) ([pyproject.toml L566-L569][pyproj-scripts]).

**Python.** `requires-python = ">=3.11,<3.15"`, but current first-party
installs run only on Python 3.14. The wider range exists so old installs can
get through the updater ([pyproject.toml L6-L11][pyproj-1],
[installation.md L157-L162][install-prereq]). The installer never uses a `uv`
or Python from `PATH`. It downloads a pinned uv and lets Hermes' own package
manager, "PM", provision Python 3.14, Node, npm, ripgrep, and FFmpeg from
`pm/lock.json` ([installation.md L66-L77][install-what],
[install.sh L264-L275][is-uv]).

**What the installer writes.**

- Clones `main` into `$HERMES_HOME/hermes-agent` by default. Flags:
  `--branch`, `--commit SHA`, `--dir`, `--hermes-home`, `--non-interactive`,
  `--skip-browser`, `--skip-computer-use`, `--include-desktop`
  ([install.sh L23-L79][is-flags]).
- Creates `cron/ sessions/ logs/ pairing/ hooks/ image_cache/ audio_cache/
  memories/ skills/` under `~/.hermes`. Copies `.env.example` to `.env`
  (mode 600) and `cli-config.yaml.example` to `config.yaml`, but only when
  each file is absent ([install.sh L761-L772][is-config]).
- Appends a `~/.local/bin` PATH line to `$HOME/.zshrc` **and**
  `$HOME/.zprofile` when the login shell is zsh. It skips a file only when a
  line matching `PATH=.*\.local/bin` is already present
  ([install.sh L693-L731][is-path]). It writes to `$HOME`, not `$ZDOTDIR`.
- By default installs `agent-browser` with a pinned Chromium plus
  `cua-driver`, the computer-use driver. The skip flags are remembered across
  updates ([installation.md L70-L83][install-what]).
- Interactive runs launch `hermes setup` and then
  `hermes gateway install --if-missing`. `--non-interactive` skips both
  ([install.sh L780-L797][is-setup]).
- Writes `.hermes-bootstrap-complete` with the pinned commit
  ([install.sh L799-L808][is-complete]) and logs to
  `~/.hermes/logs/install.log` ([installation.md L90-L94][install-what]).

**Updates.** `hermes update` tracks `origin/main` by default.
`hermes update --set-channel stable` makes it follow published release commits
instead ([updating.md L33-L35, L78-L92][updating]). Docker installs do not
support `hermes update` ([platform-support.md L22][platsup]).

**Is there a pinned artifact mise can consume?** No usable one.

- **`github:` backend.** Ruled out. Releases carry no assets (releases API).
- **`pipx:`/`uv` backend from PyPI.** Ruled out. Upstream lists PyPI installs
  as unsupported ([platform-support.md L61][platsup]). A local
  `pip index versions hermes-agent` on 2026-10-02 returned 0.15.2 as the
  newest PyPI version, six minor releases behind v0.21.5.
- **`pipx:git+https://…` from source.** Ruled out. `setup.py` raises on any
  `bdist_wheel` or `sdist` outside a Nix build (`HERMES_NIX_BUILD=1`), so
  `uv build`, `pip wheel`, and therefore a uv/pipx tool install from git all
  fail by design ([setup.py L1-L25, L49-L73][setup]).
- **Homebrew.** A local `brew info hermes-agent` showed a homebrew-core
  formula at 2026.9.21. Upstream calls brew installs unsupported and will not
  accept fixes for them ([platform-support.md L56-L62][platsup]).

The supported unattended path for this repo is the shell installer driven by a
`native-hook` script, pinned with `--commit` (see section 10).

## 3. Filesystem layout

`HERMES_HOME` selects the data root. The default is `~/.hermes`, or
`%LOCALAPPDATA%\hermes` on Windows. `HERMES_DATA_DIR_SUFFIX` appends a suffix
([hermes_constants.py L50-L57][hc-home], [L111-L117][hc-get]). Profiles live
under `~/.hermes/profiles/<name>/`, and the sticky choice is stored in
`~/.hermes/active_profile` ([faq.md L666][faq-profiles]). Each profile has its
own memory, sessions, and skills ([faq.md L674][faq-profiles]).

| Path under `~/.hermes` | Owner | Notes |
|---|---|---|
| `config.yaml` | user **and** runtime | Settings. Rewritten by `hermes config set`, `hermes model`, setup, `hermes skills trust`, and runtime approvals (below). |
| `.env` | user **and** runtime | Secrets. `hermes config set UPPER_SNAKE …` writes here ([configuration.md L54][cfg-manage]). |
| `auth.json` | runtime | OAuth credentials (Nous Portal and others) ([configuration.md L19-L32][cfg-tree]). |
| `SOUL.md` | user | Global identity prompt. Seeded with a default when missing ([context-files.md L106-L115][ctx-soul]). |
| `memories/MEMORY.md`, `memories/USER.md` | runtime (agent) | Bounded memory ([memory.md L11-L20][memory]). |
| `skills/` | runtime (agent, hub, bundled sync) | Agent-created, hub-installed, and bundled skills. `.usage.json` sidecar and `.archive/` for the curator ([skill_usage.py L1-L2][skillusage], [curator.md L11][curator]). |
| `state.db` | runtime | SQLite sessions, messages, gateway routing, FTS5 ([configuration.md L94-L98][cfg-db], [memory.md L218-L222][memory-search]). |
| `sessions/`, `logs/`, `cron/`, `pairing/`, `hooks/`, `image_cache/`, `audio_cache/` | runtime | Created by the installer ([install.sh L761-L763][is-config]). |
| `checkpoints/store/` | runtime | Shadow git store for `/rollback` ([checkpoints-and-rollback.md L25][ckpt]). |
| `backups/config/`, `state-snapshots/`, `backups/` | runtime | Automatic config copies and pre-update snapshots ([configuration.md L210-L214][cfg-update]). |
| `pending/skills/`, `cache/` | runtime | Staged skill writes and caches ([configuration.md L831-L840][cfg-skills], [skills.md L494][skills-project]). |
| `tools/`, `installs/<key>/environments/` | PM | Tool store and Python generations. Do not edit ([package-management.md L104-L122][pm]). |
| `hermes-agent/` | installer / `hermes update` | Source checkout (POSIX script install). |

**Config format.** YAML. `cli-config.yaml.example` is the 2,323-line annotated
template ([cli-config.yaml.example][cfgex]). The authoritative defaults live in
`DEFAULT_CONFIG` ([config_defaults.py][cfgdef]), currently at
`_config_version: 49` ([config_defaults.py L2719][cfgdef-ver]). Top-level
sections that matter for integration:

| Key | Default and meaning | Source |
|---|---|---|
| `model` (`default`, `provider`, `base_url`, `context_length`) | empty, so the provider is resolved | [config_defaults.py L34][cfgdef-34], [providers.md L754-L782][prov-ollama] |
| `providers.<id>` | per-provider `request_timeout_seconds`, `stale_timeout_seconds` | [configuration.md L162-L168][cfg-envsub] |
| `toolsets`, `platform_toolsets`, `agent.disabled_toolsets` | `["hermes-cli"]` | [config_defaults.py L42][cfgdef-34], [acp.md L41-L56][acp-tools] |
| `terminal.backend` | `local`; also `docker`, `ssh`, `modal`, `daytona`, `vercel`, `singularity` | [README L29][readme-29], [configuration.md L221-L285][cfg-term] |
| `approvals` (`mode`, `timeout`, `deny`, `cron_mode`, `single_query_mode`) | `smart`, 300 s, `[]`, `deny`, `deny` | [config_defaults.py L1668-L1690][cfgdef-appr] |
| `command_allowlist` | written by "allow always" approvals | [approval.py L460-L474][approval] |
| `security` (`redact_secrets`, `protected_instruction_files`, `tirith_*`, `allow_lazy_installs`, `acked_advisories`) | on, on, on, on, `[]` | [config_defaults.py L1762-L1795][cfgdef-sec] |
| `auth.adopt_external_logins` | `true` | [config_defaults.py L1753][cfgdef-auth] |
| `skills` (`external_dirs`, `create_dir`, `auto_load`, `guard_agent_created`, `write_approval`, `trusted_project_dirs`, `project_discovery`, `creation_nudge_interval`) | `[]`, `""`, n/a, `false`, `false` | [config_defaults.py L1451-L1490][cfgdef-skills], [skills.md L477-L484][skills-project] |
| `memory` (`memory_char_limit`, `user_char_limit`, `nudge_interval`, `write_approval`, `provider`) | 2200, 1375, 10, `false`, `""` | [config_defaults.py L1314-L1329][cfgdef-mem] |
| `curator` | 7-day interval, 2 h idle | [curator.md L17-L22][curator] |
| `mcp_servers` | none | [mcp.md L479-L503][mcp-keys] |
| `secrets.onepassword` | disabled | [onepassword.md L100-L125][op] |
| `updates.check` | `true`: passive GitHub API check at most once a day | [config_defaults.py L2347-L2350][cfgdef-upd], [configuration.md L172-L183][cfg-update] |
| `model_catalog` | fetches `hermes-agent.nousresearch.com/docs/api/model-catalog.json`, 20 min TTL | [config_defaults.py L2037-L2045][cfgdef-cat] |
| `telemetry.shared_metrics` | `enabled: false`, `send: false` | [config_defaults.py L2330-L2340][cfgdef-tel] |
| `context_file_max_chars` | null, so a dynamic 20K to 500K cap | [configuration.md L855-L870][cfg-ctx] |
| `checkpoints.enabled` | off | [secure-hermes-on-a-work-machine.md L109-L125][work] |

`config.yaml` supports `${VAR}` and `${env:VAR}` substitution. Bare `$VAR` is
not expanded ([configuration.md L140-L160][cfg-envsub]). Precedence, highest
first: CLI args, `config.yaml`, `.env`, built-in defaults
([configuration.md L57-L69][cfg-prec]). For env vars, `~/.hermes/.env`
**overrides** existing shell exports
([env_loader.py L455-L462][envloader]). The shipped `.env.example` leaves
every API key commented out, so shell-exported keys survive a fresh install
([.env.example][envex]).

**Declarative vs runtime-mutated.** Hermes writes `config.yaml` at runtime, not
only during setup:

- "Allow always" on an approval prompt, including ACP's `allow_always`,
  persists `command_allowlist` ([approval.py L460-L474][approval],
  [acp.md L383-L397][acp-appr]).
- `hermes doctor --ack` appends to `security.acked_advisories`
  ([security_advisories.py L137-L149][advis]).
- `hermes skills trust` writes `skills.trusted_project_dirs`
  ([skills.md L477-L484][skills-project]). `/skills approval on|off` and
  `/memory approval on|off` toggle at runtime ([configuration.md L831-L852][cfg-skills]).
- `hermes model`, `hermes config set`, `hermes tools`, plugin enable and
  disable, and updates that disable incompatible plugins all call
  `save_config` (about 40 call sites across `hermes_cli/` and `tools/`).
  Updates add disabled plugins to `plugins.disabled`
  ([updating.md L139][updating-steps]).

A plain chezmoi-managed `config.yaml` would therefore show drift and could
discard approvals on every apply. Hermes offers a supported declarative layer
instead. **Managed scope** reads `config.yaml` and `.env` from `/etc/hermes`,
or from `$HERMES_MANAGED_DIR` when that is set to an existing directory. Those
values deep-merge on top of the user files per leaf key and win even over shell
env. Hermes then refuses `hermes config set` on a pinned key
([managed-scope.md L26-L90][managed], [managed_scope.py L45-L59, L124-L149][managed-py]).
Lists count as leaves, so a managed list replaces the user's list whole
([managed_scope.py L152-L160][managed-py-flat]). Enforcement rests only on
filesystem permissions, and v1 is "Linux/POSIX-first"
([managed-scope.md L135-L150][managed-limits]).

Safe to manage declaratively:

- a managed-scope `config.yaml` with the keys you want pinned;
- `SOUL.md`, if you accept that it replaces the default persona;
- an `.env` holding **no** secrets, or nothing at all, with keys coming from
  1Password via `secrets.onepassword`.

Never clobber: `config.yaml` (user layer), `.env`, `auth.json`, `memories/`,
`skills/`, `state.db*`, `sessions/`, `cron/`, `pairing/`, `checkpoints/`,
`backups/`, `tools/`, `installs/`, `hermes-agent/`, `profiles/`.

**Env vars worth knowing** ([environment-variables.md][envref]):

| Variable | Purpose |
|---|---|
| `HERMES_HOME` | data root |
| `HERMES_MANAGED_DIR` | managed-scope directory |
| `HERMES_WRITE_SAFE_ROOT` | `:`-separated prefixes `write_file`/`patch` may touch |
| `HERMES_YOLO_MODE` | bypass approvals; refused by `hermes config set` |
| `HERMES_MODEL` | process-level model override |
| `ANTHROPIC_API_KEY`, `ANTHROPIC_BASE_URL`, `ANTHROPIC_TOKEN` | Anthropic |
| `OPENAI_API_KEY`, `OPENAI_BASE_URL` | OpenAI or a custom endpoint |
| `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL` | OpenRouter |
| `GOOGLE_API_KEY` / `GEMINI_API_KEY` | Gemini (AI Studio) |
| `VERTEX_CREDENTIALS_PATH`, `GOOGLE_APPLICATION_CREDENTIALS`, `VERTEX_PROJECT_ID`, `VERTEX_REGION` | Vertex |
| `NOUS_BASE_URL`, `NOUS_INFERENCE_BASE_URL`, `HERMES_PORTAL_BASE_URL` | Nous overrides (dev only) |
| `OP_SERVICE_ACCOUNT_TOKEN` | 1Password bootstrap |
| `TELEGRAM_BOT_TOKEN`, `SLACK_BOT_TOKEN`, `SLACK_APP_TOKEN`, `DISCORD_BOT_TOKEN`, `*_ALLOWED_USERS`, `GATEWAY_ALLOWED_USERS` | gateway |
| `TERMINAL_SSH_HOST`, `TERMINAL_SSH_USER`, `TERMINAL_SSH_KEY` | ssh backend |

Sources for rows not cited elsewhere: [environment-variables.md L15-L25, L81-L83, L123-L127, L141][envref],
[configuration.md L54][cfg-manage], [secure-hermes-on-a-work-machine.md L62-L102][work],
[google-vertex.md][vertex].

## 4. Model providers

`hermes model` is the interactive switch. `/model provider:model` switches
mid-session among providers that are already configured
([providers.md L11-L15][prov-table]).

- **Anthropic.** `ANTHROPIC_API_KEY` bills per token. OAuth through
  `hermes model` routes "as Claude Code" and needs Claude Max with extra-usage
  credits. Hermes can also borrow Claude Code's own credential store
  ([providers.md L160-L208][prov-anth]). The native `anthropic_messages` mode
  is used ([agent-loop.md L47-L58][agentloop]). The `anthropic` SDK is an
  opt-in extra that installs on first use ([pyproject.toml L229][pyproj-anth]).
- **OpenAI.** `OPENAI_API_KEY` selects provider `openai-api`, with optional
  `OPENAI_BASE_URL`. A ChatGPT or Codex subscription goes through `hermes model`
  OAuth ([providers.md L18, L63][prov-table]).
- **OpenRouter.** `OPENROUTER_API_KEY` in `.env`, or
  `hermes auth add openrouter --type oauth` ([providers.md L22][prov-table]).
- **Nous Portal.** `hermes model` OAuth, or `hermes setup --portal`, which also
  turns on the Tool Gateway for web search, image generation, TTS, and a cloud
  browser ([providers.md L17][prov-table], [README L126-L141][readme-portal]).
- **Local (Ollama, vLLM, llama-server, LM Studio).** Provider `custom` with
  `model.base_url: http://localhost:11434/v1` for Ollama or
  `http://localhost:8000/v1` for vLLM ([providers.md L754-L850][prov-ollama]).
  Hermes refuses to fall back to a cloud key when a local alias has no endpoint
  ([local-ollama-setup.md L273][ollama]).
- **Google Vertex.** Provider `vertex`, authenticated from
  `VERTEX_CREDENTIALS_PATH` → `GOOGLE_APPLICATION_CREDENTIALS` → ADC. Project
  and region live in `vertex:` in `config.yaml`, and the env vars override them
  ([google-vertex.md][vertex]). It targets Vertex's **OpenAI-compatible**
  endpoint `…/endpoints/openapi` and documents only Gemini models
  ([vertex_adapter.py L186-L187][vertexpy]). A search for `AnthropicVertex`,
  `rawPredict`, and `publishers/anthropic` across the source returned nothing,
  so **Claude on Vertex is not supported natively**.
- **Bedrock** is supported, and so is an implicit fallback. When no provider is
  configured, the bedrock extra is installed, and AWS credentials are present,
  provider resolution picks Bedrock ([auth.py L1710-L1717][auth-bedrock]).

How keys arrive: env vars in `~/.hermes/.env` or the shell (`.env` wins), OAuth
grants in `auth.json` and the credential pool (`hermes auth add …`), or
1Password references resolved at every start ([onepassword.md L1-L13][op]).

## 5. Skills and memory

**Format.** Skills are directories holding a `SKILL.md` with YAML frontmatter
(`name`, `description`, optional `version`, `platforms`, and
`metadata.hermes.{tags,category,fallback_for_toolsets,requires_toolsets,config}`).
The docs call them compatible with the agentskills.io standard
([skills.md L9, L184-L219][skills-format]). Loading uses progressive
disclosure ([skills.md L172][skills-format]).

**Where they live.** `~/.hermes/skills/` is the primary read-write store.
Bundled skills are copied in at install, and hub installs and agent-created
skills land there too ([skills.md L11][skills-format]). Discovery tiers by
precedence: project (`<git-root>/.hermes/skills/` and `<git-root>/.agents/skills/`,
loaded only after `hermes skills trust`), then local, then `skills.external_dirs`
([skills.md L457-L490][skills-project]).

**External directories.** Supported through `skills.external_dirs`, with `~`
and `${VAR}` expansion. Missing paths are skipped silently, and local names
shadow external ones ([skills.md L396-L436][skills-ext],
[skill_utils.py L356-L382][su-ext]). The scan is a recursive `os.walk` with
`followlinks=True` that collects every `SKILL.md` and prunes support dirs
under a skill root ([skill_utils.py L781-L800][su-walk]). So a single entry
`~/.agents/plugins` would pick up
`~/.agents/plugins/plugins/<pkg>/skills/<name>/SKILL.md` without listing each
package. Skills are looked up by directory name
([skill_manager_tool.py L219-L245][smt]).

Write safety for external dirs is inconsistent between docs and code. The
example config says "External dirs are read-only"
([cli-config.yaml.example L1158-L1165][cfgex-skills]). The skills page and the
code disagree: a foreground `skill_manage` patch, edit, or delete modifies the
skill **in place** wherever it lives, and "External dirs are not a
write-protection boundary" ([skills.md L414-L415][skills-ext],
[skill_manager_tool.py L219-L245][smt]). Only the background review and
curator are blocked from external skills
([skill_manager_guards.py L164-L183][smg]). Use filesystem permissions or
`skills.write_approval: true` if shared skills must stay untouched.

**Self-written skills.** New skills go to `~/.hermes/skills/`, or to
`skills.create_dir` if set ([skills.md L438-L455][skills-create]). The curator
manages only agent-created skills. It never deletes. The worst case is a move
to `~/.hermes/skills/.archive/` ([curator.md L9-L13][curator]).

**Memory.** `~/.hermes/memories/MEMORY.md` holds agent notes with a 2,200-char
cap, and `USER.md` holds the user profile with a 1,375-char cap. Entries are
`§`-delimited and injected as a frozen snapshot at session start
([memory.md L11-L20, L36-L54][memory]). Writes go through the `memory` tool and
are scanned for injection and exfiltration ([memory.md L214-L216][memory-search]).
Past sessions are searchable through `session_search` over `state.db` FTS5
([memory.md L218-L222][memory-search]). External memory providers (Honcho,
mem0, and others) are plugins, one at a time ([config_defaults.py L1324-L1328][cfgdef-mem]).

## 6. Instruction files

The project context loader runs once per session and loads only the first
match from `.hermes.md`/`HERMES.md` (walks up to the git root) →
`AGENTS.override.md` → `AGENTS.md` → `CLAUDE.md` → `.cursorrules` /
`.cursor/rules/*.mdc` ([context-files.md L11-L26][ctx]). `AGENTS.md` loads as a
merged chain from the git root down to the cwd, and more subdirectory files
are discovered as the agent touches them ([context-files.md L28-L70][ctx-chain],
[prompt_builder.py L1700-L1731][pb-agents]). `CLAUDE.md` is read from the cwd
only ([prompt_builder.py L1728-L1731][pb-agents]). Outside a git repo only the
cwd is checked, so an `AGENTS.md` in `$HOME` is never inherited
([context-files.md L46-L47][ctx-chain]).

There is **no machine-wide AGENTS.md slot**. The only global instruction file
is `$HERMES_HOME/SOUL.md`, which always loads as identity slot #1
([context-files.md L99-L115][ctx-soul], [prompt_builder.py L1626-L1642][pb-soul]).
`hermes import-agent claude-code` copies a global `~/.claude/CLAUDE.md` into
`MEMORY.md` entries once ([import-from-other-agents.md L7-L24][import]), but
the 2,200-char memory cap makes that a poor carrier for a 4.4 KB AGENTS.md.
Writes to instruction files (`AGENTS.md`, `CLAUDE.md`, `SOUL.md`, `.cursorrules`)
always need human approval, even under yolo
([config_defaults.py L1777-L1781][cfgdef-sec]).

## 7. MCP, ACP, permissions, sandboxing

**MCP client.** Servers are configured under `mcp_servers` in `config.yaml`,
either stdio (`command`, `args`, `env`, `cwd`) or HTTP (`url`, `headers`,
mTLS, OAuth). Per-server tool filtering and lazy start are available
([mcp.md L308-L346, L479-L503][mcp-keys]). **MCP server:** `hermes mcp serve`
exposes Hermes over stdio only ([mcp.md L1075-L1087][mcp-serve]).

**ACP.** Hermes is an ACP agent over stdio, started by `hermes acp`,
`hermes-acp`, or `python -m acp_adapter` ([acp.md L7-L99][acp-intro]). It uses
`agent-client-protocol==0.9.0` ([pyproject.toml L422][pyproj-acp]), and the
`all` extra that the source installer selects includes it
([pyproject.toml L503-L532][pyproj-all], [installation.md L70-L71][install-what]).
It advertises `load_session` ([server.py L529-L545][acp-server]) and sends
`session/request_permission` for dangerous commands and edits
([permissions.py L78-L82][acp-perm]). The ACP toolset `hermes-acp` drops
messaging and cron tools. `platform_toolsets.acp` replaces it
([acp.md L28-L60][acp-tools]). The documented Zed config is
`{"command": "hermes", "args": ["acp"]}` ([acp.md L221-L240][acp-zed]).
acpx can therefore drive it as a custom agent. The local acpx 0.15.0 install
has no built-in `hermes` entry (grep of the mise install, 2026-10-02). Note
that an ACP host which auto-answers permission requests turns approvals into
unattended execution ([acp.md L366-L381][acp-appr]).

**Approvals** ([security.md L34-L62][sec-modes], [config_defaults.py L1668-L1690][cfgdef-appr]):

- `approvals.mode` takes `smart` (the default: an auxiliary LLM auto-approves
  low risk, denies danger, and escalates the rest), `manual`, or `off`
  (same as `--yolo` / `HERMES_YOLO_MODE=1`).
- An unanswered prompt is denied after 300 s.
- A hardline blocklist plus user `approvals.deny` globs apply even under yolo.
- Cron, single-query (`-q`), and unattended surfaces default to deny.

**File guards.** `write_file`/`patch` cannot touch `~/.ssh`, `~/.aws`, `.env`,
`auth.json`, and similar paths. `HERMES_WRITE_SAFE_ROOT` narrows writes further.
These guards do not constrain the `terminal` tool, which runs as your user
([secure-hermes-on-a-work-machine.md L15-L31, L62-L74, L139-L145][work]).

**Terminal backends.** `local`, `docker`, `ssh`, `modal`, `daytona`,
`vercel`, `singularity` ([README L29][readme-29]). Docker runs hardened with
all capabilities dropped and `no-new-privileges`, and it skips the
dangerous-command checks because the container is the boundary
([secure-hermes-on-a-work-machine.md L76-L95][work]). Tirith pre-exec scanning
is on by default and fails open ([security.md L807-L833][sec-tirith]).

## 8. Gateway and daemon

Setup runs through `hermes gateway setup`. `hermes gateway install` installs a
systemd user unit on Linux or a launchd agent on macOS. `start`, `stop`,
`status`, and `restart` manage it. `hermes gateway run` stays in the
foreground ([messaging/index.md L164-L179][msg-cmds]). On macOS the plist is
`~/Library/LaunchAgents/ai.hermes.gateway.plist`, or
`ai.hermes.gateway-<profile>.plist` for a profile
([gateway_launchd.py L25-L28][gw-label], [gateway.py L2921-L2929][gw-plist]).
It sets `RunAtLoad` and `KeepAlive` and bakes in `PATH` (captured at install
time), `VIRTUAL_ENV`, and `HERMES_HOME`. It launches the gateway through
`/usr/bin/osascript` (JXA `system()`) to get past macOS Local Network Privacy.
Logs go to `~/.hermes/logs/gateway.log` ([messaging/index.md L657-L688][msg-launchd]).
`hermes update` restarts service-managed gateways itself
([updating.md L142][updating-steps]).

Platform credentials are env vars in `.env`: `TELEGRAM_BOT_TOKEN`,
`TELEGRAM_ALLOWED_USERS` ([telegram.md L271-L272][tg]), `SLACK_BOT_TOKEN` and
`SLACK_APP_TOKEN` over Socket Mode ([slack.md L9, L211-L212][slack]), and
`DISCORD_BOT_TOKEN`, `DISCORD_ALLOWED_USERS` ([discord.md L269-L270][discord]).
Default authorization is deny-all. Unknown DMs get a pairing code that you
approve with `hermes pairing approve`
([secure-hermes-on-a-work-machine.md L97-L107][work]).

## 9. Security notes for a work laptop

- **What it executes.**
  - A full source checkout plus PM-managed toolchains: Python 3.14, Node,
    ripgrep, FFmpeg, Chromium through agent-browser, and cua-driver
    ([installation.md L66-L83][install-what]).
  - PyPI packages lazy-installed at first use of a backend
    (`security.allow_lazy_installs: true`) ([config_defaults.py L1791-L1794][cfgdef-sec]).
  - A tirith binary that startup requests in the background
    ([security.md L813-L818][sec-tirith]).
  - Agent shell commands as your user under `smart` approvals.
- **Launch chain.** The macOS gateway spawns `osascript` → `stderr_timestamp`
  → Python ([messaging/index.md L682][msg-launchd]). That is an unusual
  chain for an EDR. Cortex XDR's "SOC - AI Apps BTP Mac" BIOC already killed
  `omp` on the work Mac (see the comment above `[machines.type.work]` in
  `home/.chezmoidata/machines.toml`). Expect similar risk here. This is
  untested.
- **Default network endpoints.**
  - The configured model provider.
  - GitHub REST API for update checks, at most once every 24 h
    ([configuration.md L172-L183][cfg-update]).
  - `hermes-agent.nousresearch.com/docs/api/model-catalog.json`, refreshed on
    a 20-minute TTL ([config_defaults.py L2037-L2045][cfgdef-cat]).
  - PyPI and the PM artifact sources for lazy installs.
  - The Nous Portal and Tool Gateway only when you opt in.
- **Telemetry.** The docs say Hermes "does not collect telemetry, usage data,
  or analytics" ([faq.md L58][faq-data]). The code has an opt-in
  `telemetry.shared_metrics` sender to `telemetry.nousresearch.com` with both
  `enabled` and `send` false by default
  ([config_defaults.py L2330-L2340][cfgdef-tel]). cua-driver's PostHog
  telemetry is forced off unless `computer_use.cua_telemetry` opts in
  ([cua_backend.py L33-L69][cua]). The local "skill usage telemetry" is a
  sidecar file, not a network call ([skill_usage.py L1-L2][skillusage]).
- **Credential borrowing.** With `auth.adopt_external_logins: true` (the
  default), Hermes reads and **refreshes** Claude Code's
  `~/.claude/.credentials.json` or Keychain entry and Codex's
  `~/.codex/auth.json`. Their rotating refresh tokens then invalidate each
  other ([security.md L669-L678][sec-borrow]).
- **TLS inspection.** Trust comes from the OS certificate store through
  `truststore`, so a corporate root installed in the system keychain should
  work without `NODE_EXTRA_CA_CERTS`-style hacks for the Python side
  ([pyproject.toml L37-L43][pyproj-tls]).
- The docs' recommended work posture is `approvals.mode: manual`, `deny`
  globs, `checkpoints.enabled: true`, a docker or ssh terminal backend, and
  `HERMES_WRITE_SAFE_ROOT` ([secure-hermes-on-a-work-machine.md L147-L175][work]).

## 10. Dotfiles integration notes

Grounded in `home/.chezmoidata/agents.toml`, `machines.toml`, and
`secrets.toml` at this repo's `prateek/hermes-agent` branch. Nothing here has
been built or tested.

1. **Catalogue entry.** Use `install = "native-hook"`, because mise has no
   viable backend (section 2). A sketch:

   ```toml
   [agents.hermes]
   binary = "hermes"
   install = "native-hook"   # run_after_07-hermes-agent (new)
   config_paths = [".hermes"]
   orca = ""                 # unknown whether Orca has a hermes agent id
   harness = ""              # acpx would need a custom agent: hermes acp
   ```

   The hook would run
   `install.sh --commit <sha> --non-interactive --skip-browser --skip-computer-use`.
   Pin the commit to a release tag's SHA and bump it like any other pin. Or
   leave `hermes update --set-channel stable` to move it, which hands version
   ownership to Hermes. Pick one owner.
2. **Shell rc side effect.** The installer appends a PATH line to
   `$HOME/.zprofile` and `$HOME/.zshrc` because its regex looks for
   `PATH=.*\.local/bin`, and this repo's `zprofile` uses a `path=(…)` array
   that already includes `$HOME/.local/bin`
   (`home/dot_config/zsh/dot_zprofile.tmpl` L51). Under `ZDOTDIR` zsh never
   reads those `$HOME` files, and `remove_dot_zshrc` deletes `~/.zshrc` on the
   next apply. `~/.zprofile` is unmanaged and would keep the appended line.
   The hook should strip it afterwards, or run the installer with a `SHELL`
   whose basename is not `zsh`. The second option redirects the write to
   `~/.bashrc` and `~/.profile`.
3. **Paths to manage.** Manage at most:
   - a managed-scope dir, say `~/.config/hermes/managed/config.yaml`, with
     `HERMES_MANAGED_DIR` exported from `$ZDOTDIR/.zshenv`;
   - optionally `~/.hermes/SOUL.md` as a symlink to `../.agents/AGENTS.md`.

   The launchd gateway plist carries only `PATH`, `VIRTUAL_ENV`, and
   `HERMES_HOME`, so a launchd-run gateway will **not** see
   `HERMES_MANAGED_DIR` ([messaging/index.md L667-L671][msg-launchd]). Either
   `launchctl setenv` it, or accept that the gateway runs without the managed
   layer. `/etc/hermes` avoids both problems but needs root, which the work
   Mac lacks outside a Jamf grant. The fallback is a `modify_` script that
   merges a desired YAML fragment into `~/.hermes/config.yaml`, mirroring the
   plist merge pattern.
4. **Paths to ignore.** Everything else under `~/.hermes` (section 3). Add
   `.hermes` to `config_paths` so machines without the agent ignore any
   managed targets there.
5. **Keys.** Prefer Hermes' native 1Password resolver. Set
   `secrets.onepassword.enabled: true` and map `env:` entries to `op://` refs
   in the managed config, and pin `binary_path` to the `op` binary. The refs
   would come from `home/.chezmoidata/secrets.toml`, rendered in
   ([onepassword.md L100-L125][op]). The desktop-session path works on a
   laptop. The service-account path needs `OP_SERVICE_ACCOUNT_TOKEN` in the
   process env, and this repo keeps that token in the login keychain, not in
   any file. `cache_ttl_seconds: 0` keeps resolved values off disk. Keys
   exported from the shell also work, because `.env.example` sets none, but a
   later `hermes config set KEY` would write `.env`, and `.env` overrides the
   shell.
6. **Sharing skills.** Set `skills.external_dirs: ["~/.agents/plugins"]`. The
   recursive walk finds every package's `skills/*/SKILL.md`. Also set
   `skills.write_approval: true`, or make the plugin tree read-only. Without
   that, a foreground `skill_manage patch` edits the chezmoi-materialized
   files in place, and the next apply reverts them. Self-written skills stay
   in `~/.hermes/skills/`. Point `skills.create_dir` at a tracked directory
   only if you want to review them in git.
7. **Instructions.** Hermes won't read `~/.agents/AGENTS.md`. Repos with an
   `AGENTS.md` work as they do for other agents. For machine-wide guidance,
   the only automatic global slot is `SOUL.md`. Symlinking it to
   `~/.agents/AGENTS.md` (4.4 KB, under the 20K floor) replaces the default
   Hermes persona. Hermes gates its own writes to `SOUL.md` behind approval.
8. **Recommended managed keys for the work Mac:**
   - `auth.adopt_external_logins: false`, to protect the Claude Code and Codex
     logins;
   - `approvals.mode: manual`, plus a `deny` list;
   - `security.allow_lazy_installs: false`, if runtime PyPI pulls are
     unwanted;
   - `updates.check: false`, if the GitHub API ping matters;
   - `telemetry.shared_metrics.enabled: false`, already the default.

   Do not pin `command_allowlist`, `skills.trusted_project_dirs`, or
   `plugins.disabled`. Hermes writes those at runtime, and a managed list
   replaces the user's list whole.
9. **acpx route.** `hermes acp` speaks ACP over stdio with real
   `session/request_permission` calls. That makes it a better fit for acpx
   permission modes than adapters that never ask. It would need a custom
   agent definition and a new harness value in `agents.toml`.
10. **Gateway.** Leave it uninstalled on the work Mac
    (`--non-interactive` skips `hermes gateway install`). Cron only fires
    while a gateway runs, so a CLI-only install has no scheduler.

## 11. Open questions and unverified points

- Whether Cortex XDR tolerates `hermes`, Python 3.14 from the PM store, or the
  osascript-launched gateway on the work Mac. Not tested.
- Whether name collisions *between* two external dirs, or two packages under
  one external dir, resolve deterministically. The walk is sorted, but the
  first-wins rule across externals is not documented.
- How Hermes treats Claude-specific frontmatter (`allowed-tools`,
  `disable-model-invocation`, `user-invocable`) in shared skills. Probably
  ignored, but not verified.
- Whether `secrets.onepassword` with a desktop session triggers a biometric
  prompt on each process start once the cache expires.
- Whether managed scope works when `HERMES_MANAGED_DIR` points into `$HOME`
  on macOS (docs say v1 is POSIX-first and doesn't mention macOS homes).
- Whether Orca's agent picker has or will get a `hermes` id.
- Who maintains the homebrew-core formula (2026.9.21) and how it builds,
  given the wheel guard. Not investigated. Upstream won't support it either
  way.
- Claude via Vertex would need a proxy (for example a custom OpenAI-compatible
  or Anthropic-compatible `base_url`). No first-party path exists.
- The docs disagree on whether the ACP extra needs a separate
  `pm.sync_venv(['acp'])` step ([acp.md L62-L74][acp-intro]). The `all` extra
  the installer selects already contains it.
- The release notes for v0.21.1 through v0.21.5 defer the curated changelog to
  v0.22.0, so this guide could not check feature-level changes against
  release notes.

[readme-19]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/README.md#L19
[readme-25]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/README.md#L25
[readme-26]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/README.md#L26
[readme-29]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/README.md#L29
[readme-portal]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/README.md#L126-L141
[arch]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/developer-guide/architecture.md#L9-L36
[agentloop]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/developer-guide/agent-loop.md#L41-L58
[msg-dir]: https://github.com/NousResearch/hermes-agent/tree/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/messaging
[cfgex]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/cli-config.yaml.example
[cfgex-mem]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/cli-config.yaml.example#L1003-L1016
[cfgex-skills]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/cli-config.yaml.example#L1150-L1165
[curator]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/features/curator.md#L9-L24
[crontrouble]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/guides/cron-troubleshooting.md#L37-L41
[cron-28]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/features/cron.md#L28
[stable]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/developer-guide/stable-releases.md#L8-L10
[pyproj-1]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/pyproject.toml#L1-L11
[pyproj-tls]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/pyproject.toml#L37-L43
[pyproj-anth]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/pyproject.toml#L229
[pyproj-acp]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/pyproject.toml#L422
[pyproj-all]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/pyproject.toml#L503-L532
[pyproj-scripts]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/pyproject.toml#L566-L569
[setup]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/setup.py#L1-L73
[platsup]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/getting-started/platform-support.md#L13-L62
[install-what]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/getting-started/installation.md#L66-L94
[install-layout]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/getting-started/installation.md#L96-L113
[install-prereq]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/getting-started/installation.md#L151-L162
[nix]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/getting-started/nix-setup.md#L66-L81
[flake]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/flake.nix#L49-L52
[docker]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/docker.md#L14-L53
[is-flags]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/scripts/install.sh#L23-L79
[is-uv]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/scripts/install.sh#L264-L275
[is-path]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/scripts/install.sh#L693-L731
[is-config]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/scripts/install.sh#L761-L772
[is-setup]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/scripts/install.sh#L780-L797
[is-complete]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/scripts/install.sh#L799-L808
[updating]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/getting-started/updating.md#L33-L92
[updating-steps]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/getting-started/updating.md#L137-L142
[hc-home]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/hermes_constants.py#L50-L57
[hc-get]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/hermes_constants.py#L111-L117
[faq-profiles]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/reference/faq.md#L664-L686
[faq-data]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/reference/faq.md#L56-L58
[cfg-tree]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/configuration.md#L19-L32
[cfg-manage]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/configuration.md#L34-L55
[cfg-prec]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/configuration.md#L57-L69
[cfg-db]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/configuration.md#L94-L98
[cfg-envsub]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/configuration.md#L140-L168
[cfg-update]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/configuration.md#L170-L214
[cfg-term]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/configuration.md#L221-L285
[cfg-skills]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/configuration.md#L782-L852
[cfg-ctx]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/configuration.md#L855-L870
[cfgdef]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/hermes_cli/config_defaults.py
[cfgdef-34]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/hermes_cli/config_defaults.py#L34-L42
[cfgdef-mem]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/hermes_cli/config_defaults.py#L1314-L1329
[cfgdef-skills]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/hermes_cli/config_defaults.py#L1451-L1490
[cfgdef-appr]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/hermes_cli/config_defaults.py#L1668-L1690
[cfgdef-auth]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/hermes_cli/config_defaults.py#L1753
[cfgdef-sec]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/hermes_cli/config_defaults.py#L1762-L1795
[cfgdef-cat]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/hermes_cli/config_defaults.py#L2037-L2045
[cfgdef-tel]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/hermes_cli/config_defaults.py#L2330-L2340
[cfgdef-upd]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/hermes_cli/config_defaults.py#L2347-L2350
[cfgdef-ver]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/hermes_cli/config_defaults.py#L2719
[approval]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/tools/approval.py#L460-L474
[advis]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/hermes_cli/security_advisories.py#L137-L149
[managed]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/managed-scope.md#L26-L90
[managed-limits]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/managed-scope.md#L135-L157
[managed-py]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/hermes_cli/managed_scope.py#L45-L149
[managed-py-flat]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/hermes_cli/managed_scope.py#L152-L160
[envloader]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/hermes_cli/env_loader.py#L455-L462
[envex]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/.env.example
[envref]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/reference/environment-variables.md
[pm]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/reference/package-management.md#L104-L122
[ckpt]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/checkpoints-and-rollback.md#L25
[skillusage]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/tools/skill_usage.py#L1-L2
[prov-table]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/integrations/providers.md#L11-L65
[prov-anth]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/integrations/providers.md#L160-L208
[prov-ollama]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/integrations/providers.md#L754-L850
[ollama]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/guides/local-ollama-setup.md#L273
[vertex]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/guides/google-vertex.md
[vertexpy]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/agent/vertex_adapter.py#L186-L187
[auth-bedrock]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/hermes_cli/auth.py#L1710-L1717
[op]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/secrets/onepassword.md#L1-L125
[skills-format]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/features/skills.md#L9-L219
[skills-ext]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/features/skills.md#L396-L436
[skills-create]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/features/skills.md#L438-L455
[skills-project]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/features/skills.md#L457-L494
[su-ext]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/agent/skill_utils.py#L356-L382
[su-walk]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/agent/skill_utils.py#L781-L800
[smt]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/tools/skill_manager_tool.py#L219-L245
[smg]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/tools/skill_manager_guards.py#L164-L183
[memory]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/features/memory.md#L11-L54
[memory-search]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/features/memory.md#L214-L222
[ctx]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/features/context-files.md#L11-L26
[ctx-chain]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/features/context-files.md#L28-L70
[ctx-soul]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/features/context-files.md#L99-L115
[pb-soul]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/agent/prompt_builder.py#L1626-L1642
[pb-agents]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/agent/prompt_builder.py#L1700-L1731
[import]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/import-from-other-agents.md#L7-L24
[mcp-keys]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/features/mcp.md#L308-L503
[mcp-serve]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/features/mcp.md#L1075-L1087
[acp-intro]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/features/acp.md#L7-L99
[acp-tools]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/features/acp.md#L28-L60
[acp-zed]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/features/acp.md#L221-L240
[acp-appr]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/features/acp.md#L366-L397
[acp-server]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/acp_adapter/server.py#L529-L545
[acp-perm]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/acp_adapter/permissions.py#L78-L82
[sec-modes]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/security.md#L34-L87
[sec-borrow]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/security.md#L669-L678
[sec-tirith]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/security.md#L807-L833
[work]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/guides/secure-hermes-on-a-work-machine.md#L13-L175
[cua]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/tools/computer_use/cua_backend.py#L33-L69
[msg-cmds]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/messaging/index.md#L164-L179
[msg-launchd]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/messaging/index.md#L657-L688
[gw-label]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/hermes_cli/gateway_launchd.py#L25-L28
[gw-plist]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/hermes_cli/gateway.py#L2921-L2929
[tg]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/messaging/telegram.md#L271-L272
[slack]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/messaging/slack.md#L9-L212
[discord]: https://github.com/NousResearch/hermes-agent/blob/bed0d535556b5b0a2bdd6fd3a74162ad5f860ca1/website/docs/user-guide/messaging/discord.md#L269-L270
