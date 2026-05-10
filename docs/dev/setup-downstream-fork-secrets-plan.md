# setup-downstream-fork — pluggable secret resolver

Status: draft
Owner: Prateek
Skill path: `~/dotfiles/.agents/skills/setup-downstream-fork/`
Related: [setup-downstream-fork-plan.md](setup-downstream-fork-plan.md)

## Problem

The skill needs four secrets at setup time: `ANTHROPIC_API_KEY` (or `OPENAI_API_KEY`), `FORK_SYNC_PAT` (optional, for the PAT-based sync path), and `FORK_APP_ID` + `FORK_APP_PRIVATE_KEY` (for the GitHub App-based sync path, once that lands). Today they're read from `os.environ`. That forces the operator to either:

- prefix every invocation with `export` lines, leaking values into shell history, OR
- keep the secrets in `.envrc`/`~/.zshenv` as plaintext.

Neither meshes with how secrets actually live on Prateek's machine. He keeps them in 1Password. Other users will have other stores: `pass`, Bitwarden, Vault, AWS Secrets Manager, a shell pipeline out of a hardware key.

We want one abstraction that covers all of these, does not involve the LLM, and is straightforward enough that someone with a non-listed backend can plug in without editing the skill.

## Goals

- Zero plaintext secrets in env, shell history, or repo files.
- Built-in ergonomic support for **env**, **flat file**, and **1Password (`op` CLI)** in v1. This is the set Prateek uses; it covers the "just works" case.
- Universal escape hatch via arbitrary shell command, so any store with a CLI is supported without a skill change.
- No LLM call anywhere in the resolver path. Secret retrieval is fully deterministic.
- New skill subcommand to bootstrap and validate the config interactively.

## Non-goals

- Not building native clients for every secret store. Built-ins exist to make the common path painless; `command:` is the long tail.
- Not managing secret rotation, auditing, or store-side ACLs — whatever the user's store does is what they get.
- Not encrypting the resolver config at rest. It holds references (pointers), not values.
- Not pulling secrets into the generated fork repo. Only `setup_fork.py` reads them; they're then pushed as GitHub repo secrets via `gh secret set` and flushed.

## Architecture

One interface, three chained layers.

```
┌─────────────────────────────────────────────────────┐
│ caller: setup_fork.py                               │
│   resolver.resolve("anthropic_api_key")  → "sk-..." │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
        ┌─────────────────────────────────┐
        │ ChainResolver                   │
        │  1. EnvResolver   (ANTHROPIC…)  │
        │  2. ConfigResolver (TOML file)  │
        │  3. None → caller decides       │
        └─────────────────────────────────┘
                        │
      ┌─────────────────┼─────────────────────┐
      ▼                 ▼                     ▼
   env var         TOML lookup            dispatch to
   match?          matches a key?         the declared provider
                                          │
                      ┌───────────────────┼───────────────┐
                      ▼                   ▼               ▼
                  EnvProvider       OpProvider      CommandProvider
                  (reads env var)   (`op read …`)   (arbitrary shell)
                                                          │
                                                 FileProvider
                                                 (reads path, strips trailing \n)
```

Env wins over config. That keeps CI-in-a-container and ad-hoc `export` overrides working without touching the config file.

## Config file

Location: `~/.config/setup-downstream-fork/config.toml`. Standard XDG path. Created by the new `--init-config` mode.

Shape:

```toml
# Default provider for entries in [secrets] that use reference-string form.
# v1 built-ins: env, op, file, command
default_provider = "op"

[secrets]
# Reference-string form — dispatched to default_provider.
anthropic_api_key    = "op://Personal/Anthropic/credential"
fork_sync_pat        = "op://Personal/GitHub Fork Sync PAT/credential"
fork_app_id          = "op://Personal/Fork Sync Bot/app_id"
fork_app_private_key = "op://Personal/Fork Sync Bot/private_key"

# Inline form — overrides default_provider for a single entry.
# openai_api_key = { provider = "file", path = "~/.config/openai/key" }
# some_secret    = { provider = "command", command = "bw get password 'Name'" }
```

Keys are lowercase; the resolver maps `anthropic_api_key` → env lookup of `ANTHROPIC_API_KEY` before hitting the config.

## Built-in providers (v1)

| Provider  | Reference form                  | What it runs                                               |
|-----------|---------------------------------|------------------------------------------------------------|
| `env`     | `$VAR` or bare `VAR`            | `os.environ[VAR]`                                          |
| `file`    | `/abs/path` or `~/rel/path`     | `Path(p).read_text().rstrip("\n")`, mode check ≤ 0o600     |
| `op`      | `op://vault/item/field`         | `op read op://vault/item/field`                            |
| `command` | arbitrary string                | runs under `/bin/sh -c <cmd>`, captures stdout, strips `\n`|

The `command` provider is the escape hatch. Any store with a CLI is one line of config: Bitwarden, Vault, AWS Secrets Manager, gopass, a hardware key wrapped in a shell script, an SSH-to-another-host retrieval. No skill change required.

## New mode: `--init-config`

`setup_fork.py --init-config` runs an interactive bootstrapper:

1. Check for `~/.config/setup-downstream-fork/config.toml`. If present, offer `--force` behavior and exit otherwise.
2. Ask for `default_provider`. Default: `op` if `op` is on `$PATH`, else `env`.
3. For each required secret (`anthropic_api_key`, `fork_sync_pat`, `fork_app_id`, `fork_app_private_key`):
   - Prompt for a reference. Show a per-provider example.
   - Immediately invoke the resolver to validate — catch typos, missing 1Password items, stale file paths at config time, not at fork time.
   - On failure, re-prompt or let the user skip (optional secrets only).
4. Write the file with mode `0o600`.
5. Print a summary: which secrets are configured, which are optional and skipped, next command to run (`setup_fork.py --upstream … --fork-name …`).

Non-interactive form: `setup_fork.py --init-config --from-env` writes a config that points every secret at the corresponding env var. Useful for CI, or for migrating from the current env-only flow.

A twin validator — `setup_fork.py --validate-config` — resolves every secret in the config and reports which ones work. No side effects. Safe to run anytime.

## Integration with existing flow

Call sites to change (setup_fork.py + _ci_gates.py):

- `os.environ.get("ANTHROPIC_API_KEY")` → `resolver.resolve("anthropic_api_key")` (CI-audit LLM call, llm_resolve.py env pass-through).
- `os.environ.get("OPENAI_API_KEY")` → `resolver.resolve("openai_api_key")`.
- `os.environ.get("FORK_SYNC_PAT")` → `resolver.resolve("fork_sync_pat")`.
- `os.environ.get("FORK_APP_ID")` / `FORK_APP_PRIVATE_KEY` → same pattern (lands with GitHub App support).

Existing fail-closed behavior is unchanged: if the resolver returns `None` for `anthropic_api_key` and upstream has workflows, setup aborts unless `--allow-empty-ci-gates` is set. The resolver just widens where the key can come from.

## Security

- **Never log resolved values.** Existing `_log` stays redacted. Resolver returns a bare string; only the `gh secret set` / LLM SDK call sites see it.
- **`0o600` enforced on the config and on any file-provider target.** Refuse to read a secret file that's world-readable; print the `chmod` command.
- **Command provider runs in a minimal env.** Carry through `PATH`, `HOME`, `USER`, and any store-specific allowlist declared in config (e.g., `OP_SESSION_*` for 1Password). Strip everything else. Prevents a compromised resolver from exfiltrating unrelated env.
- **30-second timeout on every command resolver.** A hung `op read` shouldn't wedge setup.
- **No caching across phases.** Resolve on demand; don't stash values in the `SetupContext` dataclass (which gets serialized to the debug log).
- **Reference strings are safe to log.** `op://Personal/Anthropic/credential` is a pointer, not a secret. Include those in the audit log for debuggability.

## Implementation plan

New file: `scripts/_secrets.py` (~180 lines).

- `SecretResolver` abstract base.
- `EnvResolver(key_map: dict)`.
- `ConfigResolver(config_path: Path)` that internally dispatches to:
  - `OpProvider` (shells to `op read`).
  - `FileProvider` (reads file, 0o600 check).
  - `CommandProvider` (sh -c, 30s timeout, empty env + allowlist).
- `ChainResolver(*resolvers)`.
- `load_config(path) -> dict` (tomllib, stdlib-only, Python 3.11+).
- `build_default_resolver() -> SecretResolver` — one-call factory that picks up the XDG config.

Wiring:

- `scripts/setup_fork.py`: import `_secrets`; construct resolver once in `main()`, pass through to preflight/configure_gh. Add `--init-config`, `--validate-config`, `--force` flags.
- `scripts/_ci_gates.py`: `analyze_workflows` takes an optional `api_key` parameter so it doesn't need to know about the resolver. `setup_fork.py` resolves the key and passes it in. Keeps `_ci_gates` reusable by `doctor.py` without dragging in config.
- `scripts/doctor.py`: same pattern — construct resolver in `main()`, pass `api_key` into the drift check.
- `SKILL.md`: document `--init-config` as the recommended first-run step.
- `tests/fixtures/`: add a mock op shim (`MOCK_OP_RESPONSE` env → stub `op` binary) so CI can exercise the `op` path without real 1Password.

## Follow-ups (not v1)

- Native Bitwarden, Vault, AWS Secrets Manager providers. Covered by `command:` in v1; promote to built-ins if usage patterns justify.
- Per-fork secret overrides (e.g., different PAT per fork). Would be a per-repo `.fork/config.toml`; not needed yet.
- Integration with macOS Keychain via `security find-generic-password`. Plausible v2 built-in; `command:` covers it meanwhile.
- Encrypted-at-rest config (age, sops). Deferred — the config holds references, not secrets, so the value is questionable.

## Open questions

- Should `fork_app_private_key` be resolved as a path rather than a value? The file is multi-line PEM; `op read` can return it as a string, but `gh secret set --body` vs `gh secret set < file` wants different shapes. Lean toward: resolver always returns the value; `configure_gh` writes it to a tempfile with 0o600 when a command line needs a path, deletes after.
- Where to put `--init-config` interactively — dedicated Python module or a tiny shell wrapper? Lean Python so the validation round-trip is in-process.
