"""Pluggable secret resolver for the setup-downstream-fork skill.

Lets the operator keep secret values in whatever store they prefer (env
var, local file, 1Password via ``op``, or any CLI via ``command:``) and
have ``setup_fork.py`` and ``doctor.py`` pull them without leaking
values to shell history or log files.

No LLM call is ever made by this module. Resolution is deterministic.

Chain: ``env`` → ``config file`` → ``None``. Env wins so ad-hoc
``export`` overrides and CI-container injection keep working without
touching the config.

See ``docs/plans/setup-downstream-fork-secrets-plan.md``.
"""
from __future__ import annotations

import os
import subprocess
import sys
import tomllib
from pathlib import Path
from shutil import which
from typing import Any


DEFAULT_CONFIG_PATH = Path.home() / ".config" / "setup-downstream-fork" / "config.toml"

# Logical name → env var. Env wins over config, so an exported
# ``ANTHROPIC_API_KEY`` always beats what the TOML says.
ENV_KEY_MAP: dict[str, str] = {
    "anthropic_api_key": "ANTHROPIC_API_KEY",
    "openai_api_key": "OPENAI_API_KEY",
    "fork_sync_pat": "FORK_SYNC_PAT",
    "fork_app_id": "FORK_APP_ID",
    "fork_app_private_key": "FORK_APP_PRIVATE_KEY",
    "fork_app_installation_id": "FORK_APP_INSTALLATION_ID",
}

# Secrets the skill asks about during --init-config. ``required=True`` means
# setup_fork.py's fail-closed preflight will abort unless the secret resolves.
REQUIRED_SECRETS: list[tuple[str, str, bool]] = [
    ("anthropic_api_key", "Anthropic API key (LLM CI audit + conflict resolver)", True),
    ("openai_api_key", "OpenAI API key (alternative to anthropic_api_key)", False),
    ("fork_sync_pat", "GitHub PAT for sync workflow", False),
    ("fork_app_id", "GitHub App ID (alternative to fork_sync_pat)", False),
    ("fork_app_private_key", "GitHub App private key (PEM contents)", False),
    ("fork_app_installation_id", "GitHub App installation ID on your account", False),
]

_COMMAND_TIMEOUT_SECS = 30
_COMMAND_ENV_ALLOWLIST = ("PATH", "HOME", "USER", "LANG", "LC_ALL", "LOGNAME", "TMPDIR")

_EXAMPLES: dict[str, str] = {
    "op": "op://Personal/Anthropic/credential",
    "file": "~/.config/anthropic/api-key",
    "env": "$ANTHROPIC_API_KEY",
    "command": "bw get password 'Anthropic API'",
}


class SecretResolutionError(RuntimeError):
    """Provider-side failure (bad op reference, unreadable file, command failed).

    A missing env var is *not* a resolution error; the resolver returns
    ``None`` for that case so the chain can fall through. This exception
    is reserved for cases the operator needs to act on.
    """


# --------------------------------------------------------------------------- #
# Resolver classes                                                            #
# --------------------------------------------------------------------------- #


class SecretResolver:
    def resolve(self, key: str) -> str | None:
        raise NotImplementedError


class EnvResolver(SecretResolver):
    """Read from ``os.environ`` using ``ENV_KEY_MAP``."""

    def __init__(self, key_map: dict[str, str] | None = None) -> None:
        self.key_map = key_map or ENV_KEY_MAP

    def resolve(self, key: str) -> str | None:
        var = self.key_map.get(key)
        if not var:
            return None
        return os.environ.get(var) or None


class ConfigResolver(SecretResolver):
    """Read ``~/.config/setup-downstream-fork/config.toml`` and dispatch."""

    def __init__(self, config_path: Path) -> None:
        self.config_path = config_path
        self._config: dict[str, Any] | None = None

    def _load(self) -> dict[str, Any]:
        if self._config is not None:
            return self._config
        if not self.config_path.is_file():
            self._config = {}
            return self._config
        mode = self.config_path.stat().st_mode & 0o777
        if mode & 0o077:
            raise SecretResolutionError(
                f"{self.config_path} has insecure mode {oct(mode)}; "
                f"run `chmod 600 {self.config_path}`"
            )
        with self.config_path.open("rb") as fh:
            self._config = tomllib.load(fh)
        return self._config

    def resolve(self, key: str) -> str | None:
        config = self._load()
        entries = config.get("secrets") or {}
        entry = entries.get(key)
        if entry is None:
            return None
        default_provider = config.get("default_provider", "env")

        if isinstance(entry, str):
            provider = default_provider
        elif isinstance(entry, dict):
            provider = entry.get("provider", default_provider)
        else:
            raise SecretResolutionError(
                f"secrets.{key}: unrecognized shape {type(entry).__name__}"
            )

        return _dispatch(provider, key, entry)


class ChainResolver(SecretResolver):
    """Try resolvers in order. First non-``None`` wins. Errors propagate."""

    def __init__(self, *resolvers: SecretResolver) -> None:
        self.resolvers = resolvers

    def resolve(self, key: str) -> str | None:
        for r in self.resolvers:
            val = r.resolve(key)
            if val:
                return val
        return None


def build_default_resolver(config_path: Path = DEFAULT_CONFIG_PATH) -> ChainResolver:
    return ChainResolver(EnvResolver(), ConfigResolver(config_path))


# --------------------------------------------------------------------------- #
# Provider dispatch                                                           #
# --------------------------------------------------------------------------- #


def _dispatch(provider: str, key: str, entry: Any) -> str:
    if provider == "env":
        return _provider_env(key, entry)
    if provider == "file":
        return _provider_file(key, entry)
    if provider == "op":
        return _provider_op(key, entry)
    if provider == "command":
        return _provider_command(key, entry)
    raise SecretResolutionError(
        f"secrets.{key}: unknown provider {provider!r} "
        f"(known: env, file, op, command)"
    )


def _arg(entry: Any, string_field: str, dict_field: str | None = None) -> str | None:
    """Pull the provider's primary argument out of either shape.

    Reference-string form: the whole entry is the argument.
    Inline-dict form: the argument lives under ``dict_field`` (or
    ``string_field`` as a fallback).
    """
    if isinstance(entry, str):
        return entry
    if isinstance(entry, dict):
        return entry.get(dict_field or string_field) or entry.get(string_field)
    return None


def _provider_env(key: str, entry: Any) -> str:
    raw = _arg(entry, "var", "var") or ""
    var = raw.lstrip("$").strip()
    if not var:
        raise SecretResolutionError(f"secrets.{key}: env provider needs a variable name")
    val = os.environ.get(var)
    if not val:
        raise SecretResolutionError(
            f"secrets.{key}: env provider references {var} which is unset"
        )
    return val


def _provider_file(key: str, entry: Any) -> str:
    raw = _arg(entry, "path") or ""
    if not raw:
        raise SecretResolutionError(f"secrets.{key}: file provider needs `path`")
    path = Path(raw).expanduser()
    if not path.is_file():
        raise SecretResolutionError(f"secrets.{key}: file {path} does not exist")
    mode = path.stat().st_mode & 0o777
    if mode & 0o077:
        raise SecretResolutionError(
            f"secrets.{key}: file {path} has insecure mode {oct(mode)}; "
            f"run `chmod 600 {path}`"
        )
    return path.read_text(encoding="utf-8").rstrip("\n")


def _provider_op(key: str, entry: Any) -> str:
    ref = _arg(entry, "reference", "ref") or ""
    if not ref:
        raise SecretResolutionError(f"secrets.{key}: op provider needs a reference")
    if not ref.startswith("op://"):
        raise SecretResolutionError(
            f"secrets.{key}: op reference must start with op:// (got {ref!r})"
        )
    if not which("op"):
        raise SecretResolutionError(
            f"secrets.{key}: `op` CLI not found on PATH; install with "
            f"`brew install 1password-cli`"
        )
    return _run(key, ["op", "read", ref], shell=False)


def _provider_command(key: str, entry: Any) -> str:
    cmd = _arg(entry, "command") or ""
    if not cmd:
        raise SecretResolutionError(f"secrets.{key}: command provider needs `command`")
    extra_env: list[str] = []
    if isinstance(entry, dict):
        extra_env = list(entry.get("env_allowlist") or [])
    return _run(key, cmd, shell=True, extra_env=extra_env)


def _run(
    key: str,
    command: list[str] | str,
    *,
    shell: bool,
    extra_env: list[str] | None = None,
) -> str:
    env_names = list(_COMMAND_ENV_ALLOWLIST) + list(extra_env or [])
    # Carry through anything starting with OP_ by default so biometric-unlocked
    # op sessions work without explicit allowlisting.
    for k in os.environ:
        if k.startswith("OP_"):
            env_names.append(k)
    env = {k: os.environ[k] for k in env_names if k in os.environ}
    try:
        proc = subprocess.run(
            command,
            shell=shell,
            env=env,
            capture_output=True,
            text=True,
            timeout=_COMMAND_TIMEOUT_SECS,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        raise SecretResolutionError(
            f"secrets.{key}: command timed out after {_COMMAND_TIMEOUT_SECS}s"
        ) from exc
    except FileNotFoundError as exc:
        raise SecretResolutionError(
            f"secrets.{key}: command not found: {exc.filename}"
        ) from exc
    if proc.returncode != 0:
        stderr = (proc.stderr or "").strip()[:200]
        raise SecretResolutionError(
            f"secrets.{key}: command exited {proc.returncode}: {stderr}"
        )
    out = proc.stdout.rstrip("\n")
    if not out:
        raise SecretResolutionError(f"secrets.{key}: command returned empty output")
    return out


# --------------------------------------------------------------------------- #
# --init-config / --validate-config                                           #
# --------------------------------------------------------------------------- #


def init_config(
    path: Path = DEFAULT_CONFIG_PATH,
    *,
    force: bool = False,
    from_env: bool = False,
) -> None:
    """Bootstrap the config file interactively.

    With ``from_env=True``, skip interaction and write a config that
    points every known secret at its corresponding env var (useful for
    migrating an existing env-driven setup, or for CI).
    """

    if path.exists() and not force:
        raise RuntimeError(f"{path} already exists; pass --force to overwrite")
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)

    if from_env:
        body = _build_from_env_config()
        path.write_text(body, encoding="utf-8")
        path.chmod(0o600)
        print(f"wrote {path} (provider=env for every secret)", file=sys.stderr)
        return

    default_provider = _pick_default_provider()
    print(
        f"default provider: {default_provider} (press Enter to accept, or type "
        f"env / file / op / command to change)",
        file=sys.stderr,
    )
    override = input("> ").strip()
    if override:
        if override not in {"env", "file", "op", "command"}:
            raise RuntimeError(f"unknown provider {override!r}")
        default_provider = override

    lines = [
        f'default_provider = "{default_provider}"',
        "",
        "[secrets]",
    ]
    for key, desc, required in REQUIRED_SECRETS:
        print(f"\n--- {key}: {desc}", file=sys.stderr)
        example = _EXAMPLES.get(default_provider, "")
        hint = f"example: {example}" if example else ""
        print(f"    {hint}", file=sys.stderr)
        prompt = "> " if required else "> (blank to skip) "
        ref = input(prompt).strip()
        if not ref:
            if required:
                print(f"  {key} is required — retry:", file=sys.stderr)
                ref = input("> ").strip()
                if not ref:
                    raise RuntimeError(f"{key} is required; cannot proceed")
            else:
                lines.append(f"# {key} = ...  # skipped")
                continue
        lines.append(f'{key} = "{ref}"')

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    path.chmod(0o600)
    print(f"\nwrote {path}", file=sys.stderr)

    # Validate immediately so typos fail here rather than during a fork setup.
    try:
        validate_config(path)
    except SecretResolutionError as exc:
        print(f"WARN: validation found an issue: {exc}", file=sys.stderr)


def _build_from_env_config() -> str:
    lines = [
        "# Generated by setup_fork.py --init-config --from-env.",
        "# Each secret resolves from the listed env var.",
        'default_provider = "env"',
        "",
        "[secrets]",
    ]
    for key, _, _ in REQUIRED_SECRETS:
        var = ENV_KEY_MAP.get(key)
        if var:
            lines.append(f'{key} = "${var}"')
    return "\n".join(lines) + "\n"


def _pick_default_provider() -> str:
    if which("op"):
        return "op"
    return "env"


def validate_config(path: Path = DEFAULT_CONFIG_PATH) -> None:
    """Resolve every known secret and report status. Raise on any required miss."""

    resolver = build_default_resolver(path)
    print("\nconfig validation:", file=sys.stderr)
    hard_fail = False
    for key, _, required in REQUIRED_SECRETS:
        try:
            val = resolver.resolve(key)
            ok = bool(val)
            err = None
        except SecretResolutionError as exc:
            ok = False
            err = str(exc)
        mark = "✓" if ok else ("✗" if required else "·")
        detail = f"  ({err})" if err else ("" if ok else "  (not configured)")
        print(f"  {mark} {key}{detail}", file=sys.stderr)
        if required and not ok:
            hard_fail = True
    if hard_fail:
        raise SecretResolutionError(
            "one or more required secrets could not be resolved"
        )
