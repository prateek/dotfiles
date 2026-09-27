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
include it literally in every command. Shell variables may not survive between
tool calls. If the name is lost, run `agent-browser session list`; reuse an
existing session only to resume it.

If login will be needed, settle retention before the first command. Reuse
Prateek's stated preference; otherwise use temporary state. For a retained agent-browser
login, pass `--restore` from the first command onward. In 0.38.1, adding it
later relaunches the browser and loses the current login. Saved state contains
plaintext cookies and localStorage under `~/.agent-browser` and expires after
30 days. Apply the shared [cleanup policy](policy.md#ownership) when finished.

## Import source

1. **Identify the source.** Use the browser and profile Prateek named. Ask for
   either missing value before importing.
2. **Import the login.** Use the path for the selected driver:
   - **Orca:** run [`orca-import-login`](../scripts/orca-import-login) with
     `--url`, `--browser`, and `--browser-profile`. Read `--help` for optional
     arguments. Follow the [focus policy](policy.md#focus) before opening the
     new tab. On success, use the returned page and profile IDs in later calls.
     Creating a profile with `--scope imported` alone creates an empty profile;
     it does not copy a login.
   - **Terminal / Chrome:** use `agent-browser profiles` to find the named
     profile, then pass it with `--profile <name>`. This copies it to a
     temporary directory.
   - **Terminal / another browser:** get the profile directory and explain
     that `--profile <path>` writes into it. Use that path after write access
     is authorized.
3. **Verify the login.** Inspect a signed-in page element, such as the account
   menu. The Orca helper checks host suffixes; that does not establish site
   identity or prove login. If the page still requires login, follow
   [Login hand-off](#login-hand-off).

The Orca helper reports detected browser families. For an unsupported source,
use its native UI or ask for a supported source. Prisma requires the
[Prisma Access Browser workflow](drivers/native.md#prisma-access-browser); its
cookie store is not an import fallback. If the source login has expired, sign
in again before repeating the import.

## Login hand-off

When the selected identity needs a login:

1. For an authorized task, check the available credential sources and follow
   the driver's password workflow: [Orca](drivers/orca.md#secrets) or the
   terminal vault below. If the source is inaccessible, prepare the page and
   ask Prateek to sign in. Get the
   [focus agreement](policy.md#focus) before opening or revealing a headed
   window; an existing Orca tab is not necessarily visible or focused.
2. Resolve accessible factors under [credential-aware recovery](#credential-aware-recovery).
3. Verify a signed-in page element before continuing. Cookie presence and
   successful command receipts do not establish login success.

## Credential-aware recovery

Use credentials already supplied in the session, Devland through
`scripts/chezmoi-hooks/op-service-account`, or another explicitly available
source for the authorized service. Search for an existing item before creating
one and include `--vault` on 1Password item operations. Pass secrets through
stdin or an approved secret transport, keeping them out of argv, logs, and
screenshots. Never print a retrieved value.
For SSH Key items, follow [Devland operations](onepassword.md).

Complete supported TOTP and accessible email or SMS codes. Solve a CAPTCHA
when the available browser can do so within the authorized sign-in. Check the
resulting application state after each step. Ask Prateek for a factor that is
inaccessible or requires human hardware or biometrics; ask for an account or
consent decision that the task does not supply. A failed action gets one
diagnostic retry at most, then a specific blocker report.

## Terminal credential vault

When Prateek requests a reusable credential, run
`agent-browser auth save <name> --url <login-url> --username <user>
--password-stdin` and pipe the approved secret reader directly to stdin. The
command stores the credential in the encrypted vault; `auth login <name>` uses
it. Verify the signed-in page after login. For Orca, use its
[password workflow](drivers/orca.md#secrets); this terminal vault does not
establish Orca login support.
