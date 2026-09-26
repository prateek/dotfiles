# Browser identity and login

## Choose an identity

Use isolated state unless Prateek requests an import or live attach. Resolve
the identity before the first session command; live attach uses his existing
logins and permissions.

| Identity | Orca | Terminal |
| --- | --- | --- |
| Isolated | Create an isolated profile and a tab bound to it using the installed Orca guide | Create a named agent-browser session |
| Imported | Follow [Import source](#import-source) | Use `agent-browser --profile` with the named source below |
| Live attach | [browser-harness](drivers/browser-harness.md) | [browser-harness](drivers/browser-harness.md), or Claude in Chrome when named |

## Sessions

For terminal work, choose a unique session name such as `checkout-k3f9` and
pass it literally on every command. Shell variables may disappear between
tool calls. Recover a lost name with `agent-browser session list`; reuse an
existing name only to resume that session.

If login will be needed, settle retention before the first command. Reuse
Prateek's stated preference; ask if it is missing. For a retained agent-browser
login, pass `--restore` from the first command onward. In 0.38.1, adding it
later relaunches the browser and loses the current login. Saved state contains
plaintext cookies and localStorage under `~/.agent-browser` and expires after
30 days. Apply the shared [cleanup policy](policy.md#ownership) when finished.

## Import source

1. **Source.** Identify the browser and profile Prateek named. Ask for either
   missing value before importing.
2. **Import.** Use the selected driver's path:
   - **Orca:** run [`orca-import-login`](../scripts/orca-import-login) with
     `--url`, `--browser`, and `--browser-profile`; consult `--help` for optional
     arguments. Follow the [focus policy](policy.md#focus) before it opens the
     new tab. Success returns the new page and profile IDs; use those IDs for
     subsequent commands. A profile created with `--scope imported` alone is
     empty and does not import a login.
   - **Terminal / Chrome:** use `agent-browser profiles` to resolve the named
     profile, then `--profile <name>`. This copies it into a temporary directory.
   - **Terminal / another browser:** obtain the profile directory and explain
     that `--profile <path>` writes to it in place. Use it after that write
     access is authorized.
3. **Verify.** Inspect a signed-in page element, such as the account menu.
   The Orca helper checks host suffixes; it does not prove site identity or login.
   If the page requires login, follow [Login hand-off](#login-hand-off).

Orca's helper reports the browser families it detects. For an unsupported
source, use its native UI or ask for a supported source. Prisma requires the
[Prisma Access Browser workflow](drivers/native.md#prisma-access-browser);
its cookie store is not an import fallback. An expired source login needs a
fresh sign-in before repeating the import.

## Login hand-off

When the chosen identity needs a login:

1. If credential entry is already authorized, follow the driver's password
   workflow: [Orca](drivers/orca.md#secrets) or the terminal vault below.
   Otherwise prepare the page and ask Prateek to sign in. Get the
   [focus agreement](policy.md#focus) before opening or revealing a headed
   window; an existing Orca tab is not necessarily visible or focused.
2. Wait for the requested sign-in or any uncovered MFA, CAPTCHA, consent, or
   account decision. Reuse decisions already supplied for this task.
3. Verify a signed-in page element before continuing. Cookie presence and
   successful command receipts do not establish login success.

## Terminal credential vault

When Prateek requests a reusable credential, use
`agent-browser auth save <name> --url <login-url> --username <user>
--password-stdin`, with the approved secret reader piped directly to stdin.
It stores the credential in the encrypted vault; `auth login <name>` uses it.
Verify the signed-in page after login. For Orca, use its
[password workflow](drivers/orca.md#secrets); the terminal vault route does not
establish Orca login support.
