# Source

- Upstream: https://github.com/danshapiro/trycycle/tree/eb25b5141187b667096d948198617075f8e8e55a
- APM dependency: `danshapiro/trycycle`
- Ref: `eb25b5141187b667096d948198617075f8e8e55a`
- License: MIT.
- Notes: Moved from local source to vendored package source after public source matching. chezmoi rename: `orchestrator/run_phase.py` is checked in as `literal_run_phase.py` to escape chezmoi's `run_` script-prefix interpretation; the projector at `agent_skill_lib.py::copy_skill_tree` strips `literal_` so the rendered file lands as `run_phase.py`. Known gap: `vendor-agent-package` does not apply the inverse rename, so an upstream re-import reintroduces `run_phase.py`; `validate-agent-packages` flags it until the file is renamed back.
