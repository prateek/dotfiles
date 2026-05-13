# Python and uv Conventions

## Defaults

Prefer `uv` over `pip`, `pipx`, `poetry`, and `pyenv`. Scripts and projects
pin their own interpreter and dependencies so the same `uv` invocation
works on a fresh machine, in CI, or on a Tart VM.

Pick one of two forms:

- **Project form** (`pyproject.toml` + `uv.lock`). Use for multi-file
  packages, apps with multiple entry points, anything with tests, anything
  that other code imports as a library, or anything that needs a stable
  lockfile across contributors and CI. `uv init` to start, `uv add` for
  deps, `uv run` to execute, commit `uv.lock`.
- **Single-file script form** (PEP 723 inline metadata + `uv run --script`
  shebang). Use for standalone scripts, one-off tools, chezmoi `modify_*`
  scripts, and utilities under `scripts/`. The script declares its
  interpreter and dependencies inline; no surrounding project required.

Default to the single-file script form. Reach for the project form when
you need a lockfile, tests, or library importability.

## Exceptions

Hold the line on `uv` unless one of the patterns below applies. When you
add a new exception, append it here with the file path and the reason.

- **Files git considers out of scope.** Anything `.gitignore`d or marked
  in `.gitattributes` as `linguist-vendored=true` or `linguist-generated=true`.
  Use this for third-party / vendored scripts and for fixture trees that
  simulate code in the wild (e.g. eval inputs).

Inline `python3 -c '…'` in shell scripts isn't an exception. Promote any
Python you need into a `uv run --script` file. A snippet too small to
deserve its own file is a snippet you can write in shell or `jq`. If you
need a chezmoi `modify_*` stub to share Python logic with sibling stubs,
extract the shared logic into a real PEP 723 script (e.g.
`scripts/macos/plist-merge`) and have the stubs invoke it via a small
bash shim — don't splice Python fragments mid-file.

Add new exceptions only when they recur; "I felt like it" doesn't count.

## Single-file script form (PEP 723)

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
```

The shebang and `# /// script` block must sit on line 1 of the rendered
file. Chezmoi template fragments are not used to splice Python mid-file
in this repo; if you need to share logic across `modify_` stubs, see the
positive rule under Exceptions above.

Pin `requires-python` to the minimum your script needs; `>=3.14` is the
default in this repo (the latest stable CPython at time of writing). Add dependencies to the `dependencies` list when
needed (or via `uv add --script <file> <pkg>`); don't assume system Python
ships anything beyond stdlib. In the dotfiles repo, `uv` is bootstrapped
in `home/.chezmoiscripts/run_once_before_05-core-tools.sh.tmpl`, so it's
available before chezmoi's file phase runs the modify scripts on a fresh
machine.

## Project form

For multi-file projects, run `uv init` once. Use `uv add` for dependencies
(it updates `pyproject.toml` and `uv.lock` together), `uv run` to execute,
and commit `uv.lock` so collaborators and CI install the same versions.
See the field manual below for the full command reference.

---

## uv Field Manual (Code-Gen Ready, Bootstrap-free)

*Assumption: `uv` is already installed and available on `PATH`.*

### 0 — Sanity Check

```bash
uv --version               # verify installation; exits 0
```

If the command fails, halt and report to the user.

### 1 — Daily Workflows

#### 1.1 Project ("cargo-style") Flow

```bash
uv init myproj                     # create pyproject.toml + .venv
cd myproj
uv add ruff pytest httpx           # fast resolver + lock update
uv run pytest -q                   # run tests in project venv
uv lock                            # refresh uv.lock (if needed)
uv sync --locked                   # reproducible install (CI-safe)
```

#### 1.2 Script-Centric Flow (PEP 723)

For shebang and metadata conventions, see the "Single-file script form"
section above. Transient dependencies without embedding:

```bash
uv run --with rich hello.py        # transient deps, no state
```

#### 1.3 CLI Tools (pipx Replacement)

```bash
uvx ruff check .                   # ephemeral run
uv tool install ruff               # user-wide persistent install
uv tool list                       # audit installed CLIs
uv tool update --all               # keep them fresh
```

#### 1.4 Python Version Management

```bash
uv python install 3.10 3.11 3.12
uv python pin 3.12                 # writes .python-version
uv run --python 3.10 script.py
```

#### 1.5 Legacy Pip Interface

```bash
uv venv .venv
source .venv/bin/activate
uv pip install -r requirements.txt
uv pip sync   -r requirements.txt   # deterministic install
```

### 2 — Performance-Tuning Knobs

| Env Var                   | Purpose                 | Typical Value |
| ------------------------- | ----------------------- | ------------- |
| `UV_CONCURRENT_DOWNLOADS` | saturate fat pipes      | `16` or `32`  |
| `UV_CONCURRENT_INSTALLS`  | parallel wheel installs | `CPU_CORES`   |
| `UV_OFFLINE`              | enforce cache-only mode | `1`           |
| `UV_INDEX_URL`            | internal mirror         | `https://...` |
| `UV_PYTHON`               | pin interpreter in CI   | `3.11`        |
| `UV_NO_COLOR`             | disable ANSI coloring   | `1`           |

Other handy commands:

```bash
uv cache dir && uv cache info      # show path + stats
uv cache clean                     # wipe wheels & sources
```

### 3 — CI/CD Recipes

#### 3.1 GitHub Actions

```yaml
# .github/workflows/test.yml
name: tests
on: [push]
jobs:
  pytest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v5       # installs uv, restores cache
      - run: uv python install            # obey .python-version
      - run: uv sync --locked             # restore env
      - run: uv run pytest -q
```

#### 3.2 Docker (Multistage with uv)

```dockerfile
# Stage 1: Build dependencies
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim as builder

WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-cache

# Stage 2: Runtime
FROM debian:bookworm-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv
WORKDIR /app
COPY --from=builder /app/.venv /app/.venv
COPY . .
ENV PATH="/app/.venv/bin:$PATH"
CMD ["uv", "run", "python", "main.py"]
```

Key benefits:
- **Smaller final image**: Build dependencies aren't included in the final image
- **Faster builds**: UV's speed advantage for dependency resolution
- **Better caching**: Dependency installation is cached separately from code changes
- **Security**: No build tools in production image

Essential commands:
```dockerfile
# Use UV's Python images directly
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

# Or install UV on minimal base
FROM debian:bookworm-slim
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

# Sync dependencies
RUN uv sync --frozen --no-cache

# For production-only dependencies
RUN uv sync --frozen --no-cache --no-dev
```

Advanced example (non-root user):
```dockerfile
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim as builder
RUN apt-get update && apt-get install -y build-essential && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-cache --no-dev

FROM debian:bookworm-slim
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv
RUN useradd --create-home --shell /bin/bash app
WORKDIR /app
COPY --from=builder /app/.venv /app/.venv
COPY --chown=app:app . .
USER app
ENV PATH="/app/.venv/bin:$PATH"
EXPOSE 8000
CMD ["uv", "run", "python", "main.py"]
```

Docker tips:
1. **Order matters**: Copy `pyproject.toml` and `uv.lock` before application code for better caching
2. **Use `--frozen`**: Ensures exact dependency versions from lockfile
3. **Use `--no-cache`**: Prevents UV cache from bloating the image
4. **Consider `--no-dev`**: Skip development dependencies in production
5. **Set PATH**: Ensure the virtual environment is activated properly

### 4 — Migration Matrix

| Legacy Tool / Concept | One-Shot Replacement        | Notes                 |
| --------------------- | --------------------------- | --------------------- |
| `python -m venv`      | `uv venv`                   | 10x faster create     |
| `pip install`         | `uv pip install`            | same flags            |
| `pip-tools compile`   | `uv pip compile` (implicit) | via `uv lock`         |
| `pipx run`            | `uvx` / `uv tool run`       | no global Python req. |
| `poetry add`          | `uv add`                    | pyproject native      |
| `pyenv install`       | `uv python install`         | cached tarballs       |

### 5 — Troubleshooting Fast-Path

| Symptom                    | Resolution                                                     |
| -------------------------- | -------------------------------------------------------------- |
| `Python X.Y not found`     | `uv python install X.Y` or set `UV_PYTHON`                     |
| Proxy throttling downloads | `UV_HTTP_TIMEOUT=120 UV_INDEX_URL=https://mirror.local/simple` |
| C-extension build errors   | `unset UV_NO_BUILD_ISOLATION`                                  |
| Need fresh env             | `uv cache clean && rm -rf .venv && uv sync`                    |
| Still stuck?               | `RUST_LOG=debug uv ...` and open a GitHub issue                |

### 6 — Agent Cheat-Sheet

```bash
# new project
uv init myproj && cd myproj && uv add requests rich

# test run
uv run python -m myproj ...

# lock + CI restore
uv lock && uv sync --locked

# adhoc script
uv add --script tool.py httpx
uv run tool.py

# manage CLI tools
uvx ruff check .
uv tool install pre-commit

# Python versions
uv python install 3.12
uv python pin 3.12
```
