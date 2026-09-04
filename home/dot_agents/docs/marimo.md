# marimo Conventions

Use this document when creating, editing, running, or publishing a marimo
notebook. The Python and uv defaults in [python-and-uv.md](python-and-uv.md)
also apply.

## Choose a dependency lane

### Standalone notebook

Use a sandboxed notebook with PEP 723 metadata:

```sh
uvx marimo edit --sandbox notebook.py
uv add --script notebook.py polars
uv run notebook.py
```

Dependencies installed through marimo's package UI should persist in the
notebook metadata. Confirm the metadata changed before relying on them.

### Project notebook

Use the repository's existing uv project:

```sh
uv add marimo
uv run marimo edit notebooks/analysis.py
```

Add notebook dependencies with `uv add` so they persist in `pyproject.toml` and
`uv.lock`. `uv run --with marimo ...` is suitable for a temporary editor but
does not persist packages installed through marimo's UI into the project.

Avoid an ad-hoc `.venv` lane. Convert a notebook to standalone metadata or put
it in a uv project.

## Secrets and untrusted notebooks

- Supply provider credentials through environment variables or marimo's
  settings; keep them out of notebook source and output.
- Treat notebooks loaded from URLs as untrusted code. Use marimo's sandbox and
  container isolation only after verifying the source and understanding what
  will execute.

## Publishing

Prefer a WebAssembly export for a shareable notebook that does not need a
backend. Use the command for the notebook's dependency lane:

```sh
# Standalone notebook
uvx marimo export html-wasm notebook.py -o dist --mode run

# uv project
uv run marimo export html-wasm notebook.py -o dist --mode run
```

Check marimo's current exporting documentation before choosing flags or a
hosting-specific mode. Pyodide cannot run every native extension; move
unsupported computation to a local run or an explicit backend.

Primary references:

- <https://docs.astral.sh/uv/guides/integration/marimo/>
- <https://docs.marimo.io/guides/package_management/using_uv/>
- <https://docs.marimo.io/guides/exporting/>

## Completion

- The notebook runs through `uv` without depending on system Python.
- Dependencies persist in PEP 723 metadata or the project's
  `pyproject.toml` and `uv.lock`.
- Notebook source and generated output contain no credentials.
- A published export loads and exercises its important interactions in the
  target browser.
