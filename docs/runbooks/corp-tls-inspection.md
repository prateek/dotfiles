---
status: active
doc_type: runbook
owner: Prateek
created: 2026-09-08
updated: 2026-09-08
related:
  - ../references/chezmoi-hook-lifecycle.md
  - ../adr/0012-config-gating-convention.md
---

# Corporate TLS inspection

The work Mac sits behind a TLS-inspecting proxy: it decrypts outbound TLS and
re-signs it with a corporate CA. macOS keeps that CA in the System keychain, so
Safari, Chrome, and anything using Secure Transport are fine. Node is not: it
ships its own compiled-in root store and never consults the keychain, so every
Node client fails with `SELF_SIGNED_CERT_IN_CHAIN` until `NODE_EXTRA_CA_CERTS`
points it at the corporate roots.

The `tls_inspection` flag in
[`machines.toml`](../../home/.chezmoidata/machines.toml) turns the fix on. It is
true for the `work` machine type and false everywhere else.

## What apply installs

| Piece | Job |
| --- | --- |
| `run_after_19-corp-ca-bundle.sh` | Exports the System keychain's trust anchors to `~/.config/certs/corp-ca-bundle.pem` on every apply, then reloads the launch agent so it republishes. |
| `~/.local/bin/corp-ca-gui-env` | Sets `NODE_EXTRA_CA_CERTS` in the launchd GUI domain, or clears it when the bundle is gone. |
| `com.prateek.gui-corp-ca` | Runs that wrapper at every login, because `launchctl setenv` only lives as long as the session. |
| `$ZDOTDIR/.zshenv` | Exports the same variable for shells, which do not inherit the GUI domain's copy. |

Two separate paths because macOS has two. Shells get their environment from zsh
startup; apps launched from the Dock, Spotlight, or Finder get theirs from
launchd and never see a shell. Orca is the worked example: its sign-in opens the
authorize step in a browser (Chromium's stack, keychain trust, works) and then
exchanges the code with a bare `fetch` in the Electron main process (Node's
stack, no keychain, fails). Launching the same app from a terminal would have
worked, which is what makes this class of bug confusing.

The bundle is regenerated on every apply rather than only when something
changes. IT rotates these roots, and a bundle that quietly falls behind fails
exactly like a missing one — `SELF_SIGNED_CERT_IN_CHAIN` out of nowhere, in one
tool, with nothing locally changed to blame. The keychain export costs about
a second.

## What goes in the bundle

Only self-signed CAs. `security find-certificate -a` returns everything in the
keychain, which on a managed Mac also means device-identity certificates
carrying your name and email, and intermediates macOS holds but does not treat
as roots. `NODE_EXTRA_CA_CERTS` promotes every certificate it is handed to a
trust anchor and ignores macOS trust settings, so exporting the lot would let
Node accept a chain terminating at an intermediate — or at something macOS
explicitly distrusts — that Safari would reject.

Self-signed-plus-`CA:TRUE` reproduces the admin trust domain exactly. Compare
the two if the count ever looks wrong:

```sh
grep -c 'BEGIN CERTIFICATE' ~/.config/certs/corp-ca-bundle.pem
security dump-trust-settings -d | head -1   # Number of trusted certs = N
```

## Security constraints

Export the CA from the local keychain. Never download it, not even from an
internal-looking URL: that download is itself intercepted, which is precisely
how an attacker's root would get installed. `security find-certificate` reading
the System keychain is the only trustworthy source on the machine.

The bundle is machine-local and is never committed. Pinning a snapshot of one
company's trust store into a personal dotfiles repo is stale by tomorrow and
nobody else's business.

## Verify

Shells first. There are two zsh startup paths — `ZDOTDIR` set and unset read
different `.zshenv` files — and a parent that already exports the variable
masks a broken one, so clear it and force each path to re-derive:

```sh
env -u NODE_EXTRA_CA_CERTS ZDOTDIR=~/.config/zsh zsh -c 'echo $NODE_EXTRA_CA_CERTS'
env -u NODE_EXTRA_CA_CERTS -u ZDOTDIR            zsh -c 'echo $NODE_EXTRA_CA_CERTS'
```

Both must print the bundle path. Then the GUI domain:

```sh
launchctl print "gui/$(id -u)/com.prateek.gui-corp-ca" >/dev/null && echo loaded
launchctl getenv NODE_EXTRA_CA_CERTS
```

`launchctl getenv` reads the *caller's* bootstrap context, not a domain you can
name. Run it from a terminal inside the Aqua session and it reflects what
Dock-launched apps get; run it over SSH and it tells you nothing about them.

Check a whole chain against any host the proxy intercepts, which is all of them:

```sh
node -e 'fetch("https://api.github.com/")
  .then(r=>console.log("ok",r.status)).catch(e=>console.log("ERR",e.cause?.code))'
```

Any HTTP status means TLS succeeded. `ERR SELF_SIGNED_CERT_IN_CHAIN` means that
process did not trust the chain — usually the variable never reached it, but a
stale or narrowed bundle looks identical, so check the bundle's contents before
concluding it is an environment problem.

## When an app still fails

A process only ever sees the environment it was started with; macOS offers no
supported way to change it afterwards, and Node builds its root store once on
first TLS use. So `launchctl setenv` reaches nothing that is already running.

**Restart the app.** For Orca specifically, quitting the app does not kill your
terminals: a standalone daemon owns the PTYs and survives an app restart. It
does not survive a reboot.

If the GUI domain is empty after login, load the agent by hand — from a
terminal inside the Aqua session, since `bootstrap` needs the target domain to
be the one the Dock launches into:

```sh
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.prateek.gui-corp-ca.plist
```

## Leaving the proxy

Set `tls_inspection = false` for the machine and apply. Chezmoi stops managing
the launch agent but does not delete it, so the hook's kill switch does: it
boots the agent out, clears the GUI variable, and removes the plist, the
wrapper, and the bundle.

## Checks

```sh
just test-python -p test_corp_tls_trust.py -p test_machines.py -p test_config_gates.py
```

The trust suite drives the real wrapper and rendered hook against a fake
launchd domain and keychain: the fake `bootstrap` actually executes the job's
`ProgramArguments`, so the launch agent's contract is exercised rather than
echoed back. It exports a keychain holding a root, an intermediate, and an
identity leaf and asserts only the root survives, runs both zsh startup paths
with the variable cleared, and never touches the live GUI domain.
