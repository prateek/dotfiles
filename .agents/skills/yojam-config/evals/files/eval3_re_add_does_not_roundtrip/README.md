# Fixture: re-add-does-not-roundtrip

Pitfall eval: user reached for `chezmoi re-add` to capture a Yojam GUI
change — muscle memory from the plain-file flow. With the modify_
stub as source, re-add either errors or clobbers the stub with raw
JSON. Tests that the agent explains the pattern incompatibility, says
to hand-edit the fragment instead, and (if the stub got overwritten)
recommends restoring from git rather than rebuilding by hand.

Canonical prompt + expectations live in `evals/evals.json`.
