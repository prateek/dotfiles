# Eval 1 Fixture: Drift Resolution (Edited Target)

Simulated state:

- `home/dot_zshrc` is the chezmoi source of truth (plain file, not a `.tmpl`).
- `simulated_target_zshrc` represents what currently lives at `~/.zshrc` — drifted from source by one extra alias (`alias gst='git status'`).

The agent is asked to reconcile so the source captures the edit. Expected resolution: `chezmoi re-add ~/.zshrc`, then `chezmoi diff` to confirm.

This fixture intentionally does NOT initialize a real chezmoi state directory — the eval tests the agent's reasoning and command choice, not chezmoi binary invocation.
