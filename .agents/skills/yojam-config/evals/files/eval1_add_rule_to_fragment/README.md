# Fixture: add-rule-to-fragment

Happy-path eval: user wants to route github.com to Work Chrome via
Yojam. Tests that the agent edits the desired fragment (mints a UUID,
keeps the entry sparse) and runs `chezmoi apply` — NOT `chezmoi
re-add` and NOT a direct edit of the live target.

Canonical prompt + expectations live in `evals/evals.json`.
