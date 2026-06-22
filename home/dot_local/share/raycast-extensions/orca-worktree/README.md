# Orca Worktree (Raycast)

Local Raycast extension that clones a GitHub repo with `ohc` and starts a new
Orca worktree. It is a personal, unpublished extension managed by chezmoi.

## Layout

It lives at `~/.local/share/raycast-extensions/orca-worktree`, **not** under
`~/.config/raycast/extensions` — that directory is reserved for Raycast's own
installed extensions, and Raycast refuses to import development sources from it
("Invalid development sources location").

## Install

`chezmoi apply` materializes the source, installs dependencies, and builds the
command bundle (see `run_onchange_after_21-raycast-extensions.sh.tmpl`). That
part is automatic.

Registration is **not** automatable — Raycast only loads a development
extension after a one-time import, which writes to Raycast's own store. Once per
machine:

```sh
cd ~/.local/share/raycast-extensions/orca-worktree
npm run dev   # start, then stop with Ctrl-C
```

The "Create Orca Worktree" command then appears in Raycast and stays available
after the dev server stops (hot-reload only needs the server running).

## Develop

- `npm run dev` — dev mode with hot reload.
- `npm run build` — production build / validation.
- `npm test` — unit tests for the pure helpers in `src/orca.mjs`.
- `npm run typecheck` — `tsc --noEmit`.

`tsconfig.json` must use `"moduleResolution": "Bundler"`. With `NodeNext`, the
build resolves `react` through Node's ESM `exports` map and loads a second React
instance at runtime, which makes every hook throw
`Cannot read properties of null (reading 'useState')`.
