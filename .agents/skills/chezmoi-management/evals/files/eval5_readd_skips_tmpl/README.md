# Eval 5 Fixture: re-add Skips .tmpl Source

Simulated state:

- `home/dot_zshrc.tmpl` is the chezmoi source — a real Go template with a host-conditional block.
- `simulated_target_zshrc` represents the current `~/.zshrc` after the user edited it directly to add `alias k=kubectl`.

The user's intent is to capture the live edit into source. `chezmoi re-add ~/.zshrc` SKIPS templates (it will not overwrite a `.tmpl` source) and silently exits 0 — the alias is not captured.

Expected behavior: the agent runs `chezmoi source-path ~/.zshrc` as a pre-check, sees the source is `.tmpl`, refuses `re-add`, refuses `add --force` (would clobber the template), and recommends manually porting `alias k=kubectl` into the `.tmpl` outside the host-conditional block. Then `chezmoi diff ~/.zshrc` to confirm.
