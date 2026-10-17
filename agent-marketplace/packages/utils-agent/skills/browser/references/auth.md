# Browser identity and login

## Choose an identity

Use isolated state unless Prateek requests an import or live attach. Resolve
identity and retention before the first session command. Reuse his stated
retention preference; otherwise delete task state when finished. Live attach
uses his existing logins and permissions. Session names and IDs belong to the
controller, not the harness; record them for every later call.

| Controller | Identity and retention mechanics |
| --- | --- |
| [Orca](drivers/orca.md) | Isolated profile and bound tab; explicit import below; record profile/page IDs |
| [agent-browser](drivers/agent-browser.md#sessions-and-retention) | Named session; explicitly requested import or restore state; controller guide owns retention/vault commands |
| [Camofox REST](drivers/camofox.md) | Fresh task server, user/tab IDs and ephemeral directories; this recipe has no imports, retained login or secret-entry support |
| [browser-harness](drivers/browser-harness.md) | Explicit live Chrome attach; preserve pre-existing user state |
| [Playwright](drivers/playwright.md) | Isolated test contexts or repository-owned test-state fixtures |

An unavailable identity mode is a capability limit. Select another supported
recipe with Prateek's runtime/identity choice preserved; do not silently copy
state or import a profile to recover. Apply [cleanup](policy.md#ownership) to
sessions, persisted files and processes, not just the final tab.

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
   - **agent-browser / Chrome:** use `agent-browser profiles` to find the named
     profile, then pass it with `--profile <name>`. This copies it to a
     temporary directory.
   - **agent-browser / another browser:** get the profile directory and explain
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
   [agent-browser vault](drivers/agent-browser.md#credential-vault). If the selected
   recipe has no verified secret transport, report that limit and use a supported
   login recipe only within Prateek's runtime choice. If the source is inaccessible, prepare the page and
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
