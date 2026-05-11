# Eval 12 Fixture: chezmoi diff Direction Sense

Simulated state:

- `home/dot_zshrc` is the chezmoi source (target state). Has `alias gs='git status'`.
- `simulated_target_zshrc` represents the current `~/.zshrc` (destination). Has `alias gst='git status'` — the user edited it manually.

The `chezmoi diff` output in the prompt shows:
```
-alias gst='git status'    (current dest)
+alias gs='git status'     (computed target / source)
```

Per the direction convention (- dest, + target), `chezmoi apply` will REMOVE the `gst` alias from the dest and ADD the `gs` alias from source. The user's manual edit will be lost.

Expected behavior:
- Agent correctly identifies `-` as current dest content and `+` as target content.
- Agent states explicitly that apply will replace `gst` with `gs` — the user's alias WILL be lost.
- Agent offers resolution: re-add to capture `gst` into source, accept apply, or merge.
- Agent does NOT invert the direction (does NOT say apply will preserve `gst`).
