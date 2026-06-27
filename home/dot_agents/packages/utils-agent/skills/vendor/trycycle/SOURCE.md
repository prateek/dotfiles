# Source

- Upstream: https://github.com/danshapiro/trycycle/tree/229b6764cc7f4ee6b7d9a9ec01c9f69a31407d70
- APM dependency: `danshapiro/trycycle`
- Ref: `229b6764cc7f4ee6b7d9a9ec01c9f69a31407d70`
- License: MIT.
- Notes: Moved from local source to vendored package source after public source matching.
- chezmoi rename: `orchestrator/run_phase.py` is checked in as `literal_run_phase.py` to escape chezmoi's `run_` script-prefix interpretation. The projector at `agent_skill_lib.py::copy_skill_tree` strips `literal_` so the rendered file lands as `run_phase.py`. Known gap: `vendor-agent-package` does not yet apply the inverse rename, so an upstream re-import will reintroduce `run_phase.py` and break `chezmoi apply` until the file is renamed back.
