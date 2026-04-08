# Using marimo (via uv) — Field Guide for Claude Code

> **Purpose:** A drop‑in prompt (field guide) for Claude Code to build, run, and share **marimo** notebooks using **uv**; export to **Pyodide/WASM** HTML; and use **LLM features** safely and reproducibly. Modeled after Harper Reed’s `using-uv.md`.

---

## Golden rules (read me, robot 🫡)

- **Always use **``**.** Do **not** call `pip` or touch system Python.
  - Add deps to a project: `uv add PKG`\
    Remove: `uv remove PKG`
  - Add deps to a single notebook (inline metadata): `uv add --script notebook.py PKG`
  - Ad‑hoc edit: `uvx marimo edit …`\
    In‑project edit: `uv run marimo edit …`
- Prefer **sandboxed** notebooks (`--sandbox`) or a **uv project**; avoid ad‑hoc venvs.
- **Secrets** (API keys): set via env vars or marimo settings; **never** commit them.
- **Publishing**: prefer **WASM (Pyodide) export** for zero‑backend sharing; only add a server if you truly need one.

---

## Quickstart (pick a lane)

### A) One‑off (isolated) edit session

```bash
uvx marimo edit --sandbox my_notebook.py
# Add a dep while editing (UI) OR from CLI:
uv add --script my_notebook.py polars
```

### B) Inside a uv project

```bash
uv init marimo-demo && cd marimo-demo
uv add marimo
uv run marimo edit notebooks/analysis.py
# later
uv add duckdb polars altair
```

### C) Run notebook as a script (no UI)

```bash
uv run my_notebook.py
```

---

## The three dependency modes (from marimo + uv docs)

> marimo supports three ways to manage deps; **inline** requires `uv`.

1. **Inline deps (recommended for single-file notebooks)**

```bash
uvx marimo edit --sandbox my_notebook.py
# marimo will record deps into the file via inline script metadata
```

- Packages installed from marimo’s UI are persisted **into the notebook’s metadata**.
- Run as a script later with `uv run my_notebook.py`.
- **From URLs (secure):** you can run a sandboxed notebook hosted online:

```bash
uvx marimo edit --sandbox https://<trusted-url>/notebook.py
# You may be prompted: "Run in a secure Docker container? [Y/n]"
# Install & run Docker, then press Y for isolation.
```

2. **Project deps (recommended for repos/apps)**

```bash
uv init cool-app && cd cool-app
uv add marimo
uv run marimo edit notebooks/app.py
```

- marimo’s UI package manager will **edit your **`` (no manual `uv add` needed).
- You can also omit marimo as a dep and run it ad‑hoc **with project access**:

```bash
uv run --with marimo marimo edit notebooks/app.py
```

- ⚠️ **Caveat:** when using `--with marimo`, packages installed via marimo’s UI are **not** added to your project and may disappear on the next run. Prefer `uv add`.

3. **Non‑project env (legacy-style)**

```bash
uv venv
uv pip install marimo
uv run marimo edit
```

- marimo’s UI will install packages into `.venv` via `uv pip`.

---

## LLM superpowers in marimo

- **Text → notebook (CLI):**

```bash
marimo new "Plot an interactive 3D surface with matplotlib."
# or
marimo new prompts/idea.txt
```

- **In the editor:**
  - **Generate with AI** (new cells / whole sections)
  - **Refactor cell**: `Cmd/Ctrl+Shift+E`
  - **Chat panel** for code/data help; insert generated cells

### Configure providers (recommended)

Use marimo’s settings UI **or** environment variables.

**Anthropic (Claude)**

```bash
export ANTHROPIC_API_KEY=sk-ant-...
# Then select Claude in marimo's AI settings
```

**OpenAI**

```bash
export OPENAI_API_KEY=sk-proj-...
# Optional for self-hosted/OpenAI-compatible endpoints:
export OPENAI_BASE_URL=http://127.0.0.1:11434/v1  # e.g., Ollama/LM Studio/TGI
```

**Local (OpenAI-compatible)**

```bash
export OPENAI_API_KEY=dummy
export OPENAI_BASE_URL=http://127.0.0.1:11434/v1
```

> Tip: prefer provider selection inside marimo’s settings to keep source secret‑free.

---

## Share as a single‑file WASM (Pyodide) app

```bash
# Read‑only “app” or editable playground variants:
marimo export html-wasm my_notebook.py -o dist --mode run
marimo export html-wasm my_notebook.py -o dist --mode edit
```

- **Watch while you edit:**

```bash
# terminal 1: live edit
marimo edit my_notebook.py --watch
# terminal 2: live export
marimo export html-wasm my_notebook.py -o dist --watch --mode run
# terminal 3: serve locally
cd dist && python -m http.server
```

- **Hosting**: push `dist/` to GitHub Pages or Cloudflare Pages.
  - Cloudflare‑friendly export: add `--include-cloudflare`.
- **Static assets**: place files under `public/` next to the notebook; marimo includes them in the export.

```python
import marimo as mo, polars as pl
path = mo.notebook_location() / "public" / "data.csv"
df = pl.read_csv(str(path))
```

- **Pyodide notes**: pure‑Python packages generally work; binary wheels often don’t. Use `micropip` inside WASM for pure‑Python libs; heavy compute → run locally or add a thin backend.

---

## Guardrails for Claude Code (copy‑pasta for agents)

- If you propose `pip install`, **stop** and rewrite using `uv`.
- When adding deps from the editor, ensure they persist to the right place:
  - **Inline** → notebook’s script metadata (via `uv add --script`)
  - **Project** → `pyproject.toml` (via `uv add` or the UI)
  - `` → **don’t** rely on UI installs; use `uv add` so it persists
- Prefer `` (inline) or `` (project).
- For shareable demos, export to WASM HTML; avoid ad‑hoc servers.

---

## Troubleshooting

- **Package missing in WASM** → check Pyodide support; try `micropip` for pure‑Python; else run locally or add an API.
- **LLM keys not detected** → set env vars then restart editor; check provider selection in settings.
- **Resolver hiccups** → `uv cache clean` and retry; ensure you’re using `uv run`/`uvx` (not system Python).
- **Project vs **``** confusing deps** → if packages “disappear,” you probably launched with `uv run --with marimo …`; add them with `uv add`.
- **Security when running from URL** → trust the source; choose Docker isolation when prompted.

---

## Upstream docs (read these)

- **marimo × uv integration (Astral):** [https://docs.astral.sh/uv/guides/integration/marimo/](https://docs.astral.sh/uv/guides/integration/marimo/)
- **marimo + uv (package mgmt & sandbox):** [https://docs.marimo.io/guides/package\_management/using\_uv/](https://docs.marimo.io/guides/package_management/using_uv/)
- **Exporting (**``**):** [https://docs.marimo.io/guides/exporting/](https://docs.marimo.io/guides/exporting/)
- **Publish to GitHub Pages:** [https://docs.marimo.io/guides/publishing/github\_pages/](https://docs.marimo.io/guides/publishing/github_pages/)
- **WebAssembly / Pyodide notebooks:** [https://docs.marimo.io/guides/wasm/](https://docs.marimo.io/guides/wasm/)
- **AI features (editor & providers):** [https://docs.marimo.io/guides/editor\_features/ai\_completion/](https://docs.marimo.io/guides/editor_features/ai_completion/)
- **Chat UI component:** [https://docs.marimo.io/api/inputs/chat/](https://docs.marimo.io/api/inputs/chat/)
- **Text‑to‑notebook (**``**):** [https://docs.marimo.io/guides/generate\_with\_ai/text\_to\_notebook/](https://docs.marimo.io/guides/generate_with_ai/text_to_notebook/)
- **marimo **``** (read & follow):** [https://docs.marimo.io/llms.txt](https://docs.marimo.io/llms.txt)

---

### Notes for the agent

- Inline‑deps require `uv`; prefer `uvx marimo edit --sandbox` (inline) or `uv run marimo edit` (project).
- `uv run --with marimo` is fine for quick runs but **does not** persist UI‑installed packages to the project.
- WASM exports run fully in‑browser via Pyodide; use `html-wasm` (add `--include-cloudflare` if deploying to Cloudflare Pages).
- Configure LLMs via settings or env (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, optional `OPENAI_BASE_URL`).

