# Python and uv Conventions

Use this document for Python scripts and projects on this machine. Read uv's
version-matched documentation for its full command surface; this file records
local choices and chezmoi-specific gotchas.

## Defaults

Prefer `uv` over `pip`, `pipx`, `poetry`, and `pyenv`. Pin the interpreter and
dependencies so the same invocation works on a fresh machine, in CI, and in a
Tart VM.

Choose one form:

- **Single-file script:** PEP 723 inline metadata and a
  `uv run --script` shebang. Use for standalone scripts, one-off tools,
  chezmoi `modify_*` scripts, and utilities under `scripts/`.
- **Project:** `pyproject.toml` plus `uv.lock`. Use for multi-file programs,
  libraries, multiple entry points, tests, or work needing a stable lockfile.

Default to a single-file script until the project criteria apply.

## Single-file scripts

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
```

- Keep the shebang on line 1 and the metadata block immediately below it.
- Pin `requires-python` to the minimum the script needs; `>=3.14` is the
  machine-wide default for new scripts.
- Declare every non-stdlib import in `dependencies`, using
  `uv add --script <file> <package>` when convenient.
- Keep user-invoked scripts verbose so first-run dependency installation is
  visible.

For chezmoi `modify_*` scripts, use:

```python
#!/usr/bin/env -S uv run --quiet --script
```

Chezmoi evaluates modify scripts during read-only commands such as `status` and
`diff`; `--quiet` suppresses routine installation chatter while preserving
errors.

Do not splice shared Python fragments into multiple modify templates. Put the
logic in one PEP 723 script, such as `scripts/macos/plist-merge`, and call it
from small shell stubs.

## Projects

- Start with `uv init`.
- Add dependencies with `uv add`.
- Run commands with `uv run`.
- Commit `uv.lock`.
- Use locked or frozen sync behavior in CI according to the project's existing
  convention.

## Exceptions

Generated, vendored, ignored, and fixture files that intentionally model
external code may follow their source format. Treat an exception as durable
only when it recurs, and record the path and reason here.

Inline `python3 -c '…'` in shell is not a separate Python form. Express tiny
logic in shell or `jq`; promote substantial logic to a PEP 723 script.

## Completion

- Run the script or the project's relevant checks through `uv`.
- Confirm every imported dependency is declared.
- Confirm a project lockfile changed when dependency resolution changed.
- Confirm chezmoi modify scripts stay quiet during a read-only chezmoi command.
