---
status: accepted
doc_type: adr
owner: Prateek
created: 2026-09-08
updated: 2026-09-08
related:
  - 0005-mise-tool-management.md
  - 0027-codex-standalone-installer.md
  - ../references/mise-tool-management.md
---

# ADR 0029: Install the Claude Code CLI with Anthropic's native installer

Install the Claude Code CLI through `https://claude.ai/install.sh`, driven by a
chezmoi apply hook, and drop the `npm:@anthropic-ai/claude-code` pin from
`clis.toml`. `npm:@agentclientprotocol/claude-agent-acp` is a different package
and stays on mise.

## Context

`clis.toml` pinned the CLI at `npm:@anthropic-ai/claude-code = "latest"`. Two
copies followed from that: mise's own npm-backend install, and the package under
the mise-managed node's global prefix, which is where Claude Code's updater
reinstalls itself when it believes it was installed from npm.

The npm package is no longer the program. Since 2.1.x it is a wrapper whose
postinstall hardlinks a platform binary out of an optional dependency over
`bin/claude.exe`; the running process is the same native executable either way.
What differs is the update: npm rewrites its package tree in place — unlink, then
relink at the same path — with no regard for processes already executing the old
image.

On 2026-09-08 that tree was rewritten at 20:11 with nine sessions running. At
20:14 the machine panicked:

```text
panic(cpu 8): zalloc[3]: zone map exhausted while allocating from zone
[data.kalloc.1024], likely due to memory leak in zone [data.kalloc.1024]
(19G, 20481120 elements allocated)
```

`com.apple.iokit.EndpointSecurity` was in the backtrace and the panicked task
was `claude.exe`, after roughly 6.5 days of uptime — about 36 leaked elements
per second. Upstream [anthropics/claude-code#66020](https://github.com/anthropics/claude-code/issues/66020)
collects around a dozen independent reproductions that all stall at the same
~21M-element, 20 GB ceiling. The leading theory there is that an orphaned
executable image makes `vn_getpath` fail, leaking a 1 KB `vfs.namei` pathname
buffer per event, and the same npm-versus-installer split has been reported for
an unrelated tool. It is contested: two reporters see the same growth on clean
native installs.

Anthropic's installer keeps each release at its own path under
`~/.local/share/claude/versions/<version>` and repoints the `~/.local/bin/claude`
symlink, so an update never unlinks a running image.

## Decision

`run_after_06-claude-native.sh` owns the CLI, gated on `run_install_scripts` and
on `claude` appearing in the machine's `agent_clis` — the same list
`run_onchange_after_36-agent-plugins.sh` already requires on `PATH`, and the
hook is numbered ahead of it. It exits early once `~/.local/bin/claude` answers
`--version`, so the steady state is that check plus a `pgrep`, with no network.

The hook constrains the installer the way the Codex one does
([ADR 0027](0027-codex-standalone-installer.md)): it runs with `PATH` set to
`~/.local/bin` plus the system directories. `install.sh` downloads the current
binary and hands off to its own `claude install <target>`, and that step is what
sets up the launcher and edits a shell startup file when the install directory
is off `PATH` — with `~/.local/bin` already there it has nothing to fix, and
chezmoi keeps ownership of shell configuration.

The install target is `latest`, and it has to match the `autoUpdatesChannel` in
`home/.chezmoitemplates/claude-settings-managed.json.tmpl`. That is not just
tidiness: the installer writes its own target into `~/.claude/settings.json`
under that key, and the hook runs after chezmoi has merged the managed value
into the same file. A mismatch would have the installer overwrite chezmoi on
every fresh install and chezmoi overwrite it back on the next apply.

Retiring the npm copies is part of the same hook rather than a separate
mechanism, because the ordering constraint is local: retirement runs only after
the native launcher is in place. Uninstalling under a live session is exactly
the orphaning this migration exists to avoid, so each copy is checked against
the processes running from that copy specifically — a busy one gets a warning
and survives to the next apply, an idle one goes now. mise reaches each install
through several version-alias paths but a running process names only the
resolved one, so the hook walks the real install directories and skips the
aliases; checking a copy under a path no process can be using would clear the
guard and retire it anyway.

That gate covers the hook's own retirement, not the migration itself. `claude
install` runs Claude Code's npm cleanup before this hook sees a native launcher,
so the copies a first migration removes go without any check — see the
consequence below.

## Consequences

`~/.local/bin` precedes the mise shims in the managed `path` array, so the native
install is what `claude` resolves to. Machines whose `agent_clis` is empty — the
`ci` type and the test harness — no longer get the CLI at all; nothing in the
apply used it there.

Claude Code versions are no longer visible to `mise ls`. The installed release is
the file name under `~/.local/share/claude/versions/`, and `claude doctor`
reports it along with the update channel.

A session started before its own copy is retired keeps executing an image with
no directory entry left, and stays orphaned until it is restarted. The migration
itself creates that state once: Claude Code's installer removes the npm package
when it takes over, so every session running at that moment is orphaned. Restart
them.

This is a cheap mitigation, not a proven fix. The leak is worth watching
directly:

```sh
zprint | awk '$1=="data.kalloc.1024"{print $7}'
```

Baseline after boot is around 1,200 elements; the panic was at 20.5M. If the
count still climbs at tens of elements per second on the native install with no
orphaned session left, the npm theory does not hold on this machine and issue
66020 is the place to say so.

## Alternatives considered

- **Keep npm and turn off auto-updates.** The updater is not the only writer —
  `mise install` rewrites the same tree — and it trades a memory leak for a
  stale security-relevant binary.
- **Pin an npm version instead of `latest`.** The tree is still rewritten
  whenever the pin moves, and the CLI is frozen the rest of the time.
- **Homebrew.** There is no CLI cask; the `claude` cask in `packages.toml` is the
  desktop app and stays.
