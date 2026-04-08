# ABOUTME: Python, uv, and Docker conventions — preferences, field manual, and container recipes.
# ABOUTME: Merged from python.md, using-uv.md, and docker-uv.md.

# Python and uv Conventions

## Preferences

- Use uv for everything (uv add, uv run, etc).
- Do not use old fashioned methods for package management like poetry, pip or easy_install.
- Make sure that there is a pyproject.toml file in the root directory.
- If there isn't a pyproject.toml file, create one using uv by running uv init.

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

```bash
echo 'print("hi")' > hello.py
uv run hello.py                    # zero-dep script, auto-env
uv add --script hello.py rich      # embeds dep metadata
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
