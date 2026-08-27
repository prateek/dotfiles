# Source

- Upstream: https://github.com/199-biotechnologies/claude-deep-research-skill/tree/f2f2c0fa4e7617ca84c86b63f4bb40f77a746933
- APM dependency: `199-biotechnologies/claude-deep-research-skill`
- Ref: `f2f2c0fa4e7617ca84c86b63f4bb40f77a746933`
- License: upstream README says MIT; no GitHub license metadata is declared.
- Notes: Vendored source is kept under the local skill id `deep-research`. chezmoi rename: `schemas/run_manifest.schema.json` is checked in as `literal_run_manifest.schema.json` to escape chezmoi's `run_` script-prefix interpretation; chezmoi's `literal_` attribute and the plugin projector both strip the prefix so the file lands under its real name. Re-apply after re-vendoring.
