# Package layout

The [isolated project README](../../../../agent-marketplace/README.md#edit-a-package)
owns the source layout and just recipes. One root APM project acquires inputs
for every plugin: one manifest, one lock, and one committed cache. Each directory
under `packages/` defines a native plugin without a separate APM project.

The plugin's `.codex-plugin/plugin.json` owns its identity, version, and common
metadata. The builder derives temporary APM publication manifests from it,
generates native metadata and catalogs, then removes those temporary manifests.

`publish.toml` maps a curated directory to an APM lock identity and a path inside
its shared native cache root. It also selects complete hooks and supporting trees. It
contains no repository URLs or revision pins beyond the producer's dependency
identity. Authored skills live directly under `skills/<directory>/`.
For a subdirectory selection, explicitly include omitted upstream root licenses
and notices under `licenses/<owner>/<repo>/`; cached notices alone do not reach
native installs. Keep those selections alongside the skill selections.
Each authored or selected skill must publish as a directory with `SKILL.md` at
its root. Removing the entrypoint through a patch is invalid; remove the selection
to retire an imported skill. The builder checks expected roots even when a patch
removes the entire directory. Overlays that add skills follow the same contract.

Python `__pycache__` entries are omitted from the source fingerprint and all copied
payload trees without following cache symlinks. Other symlinks are rejected.

Package policy is separate: `home/.chezmoidata/agent_plugins.toml` requires explicit
boolean `default_loaded`, `claude`, and `codex` entries for every published package.
A package remains in both catalogs when host eligibility is false. There is no
implicit enabled default. Pi uses Claude eligibility and default loading; Cursor
retains its marketplace registration behavior.

The library reads built payloads for effective content and source selections for
edit ownership. Imported edits belong in patches/overlays; no reader infers origin
from `SOURCE.md`. Names such as directory `orca-stration` and skill `orchestration`
remain distinct, as do `deep-research` and its frontmatter name.
