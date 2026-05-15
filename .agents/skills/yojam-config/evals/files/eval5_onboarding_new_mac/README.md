# Fixture: onboarding-new-mac

Happy-path eval: fresh Mac, dotfiles applied, Yojam cask installed.
Tests that the agent walks through `chezmoi apply` (modify_ stub
emits the fragment re-serialized through `json.dumps` with 2-space
indent into the empty live target — not byte-identical to the source
fragment) → launch Yojam → approve the default-browser prompt → Yojam
imports + auto-discovers browsers/email. Mentions the `.chezmoiignore`
cask-presence gate as the opt-out for hosts that should NOT inherit.

Canonical prompt + expectations live in `evals/evals.json`.
