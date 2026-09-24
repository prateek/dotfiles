# Orca driver

This driver serves the rows of the SKILL.md table that route to Orca. The
version-matched command surface comes from the running binary; this file adds
the local rules.

1. Load the [orca-cli](../../../orca-cli/SKILL.md) skill, then its browser
   reference: `orca skills get orca-cli --reference browser`.
2. Create the task's tab with the identity from [auth.md](../auth.md):
   `orca tab create --url <url> --profile <id> --json`. Record its
   `browserPageId` from `orca tab list --json` and pass `--page <id>` on every
   later command.
3. Drive the page with the snapshot, act, and re-snapshot loop from the Orca
   reference.
4. Native windows, dialogs, and app chrome: `orca computer list-windows --app
   <app>`, then `orca computer get-app-state --app <app>`, then act by
   `--element-index`.
5. When Prateek wants to point at elements, ask him to mark them with Orca's
   element annotation and send the notes to this agent.

## Safety flags

In Orca 1.4.209, `orca exec --command "<agent-browser command>"` forwards
every flag except `--cdp` and `--session`. Add
`--content-boundaries --max-output 50000` to exec commands that read page
content. Typed commands such as `orca snapshot` take no such flag, so their
page text arrives without boundary marks; the untrusted-content rule in
[policy.md](../policy.md) is the protection there.

Orca attaches over CDP, and agent-browser rejects `--allowed-domains` on CDP
attachments, so keep navigation to the task's sites by choosing each URL
yourself.

Orca's bundled agent-browser reads `~/.agent-browser/config.json`, so keep
safety settings on the command line; a global config would change Orca's own
calls.

## Secrets

`orca cookie get` prints cookie values, and `orca set credentials` takes a
password as an argument. Use them only through [auth.md](../auth.md)'s login
hand-off, which avoids both.
