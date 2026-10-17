# agent-browser driver

Use this driver for page work selected by the skill's router, including an
explicit request or fallback from Orca's embedded browser.
Read `agent-browser skills get core` before acting; the installed guide owns
command syntax.

Controller: agent-browser CLI. Runtime: the browser selected by that CLI and
its launch options, not the agent harness. Identity: isolated, explicitly
imported, or requested restore state. Use the named session on every call.

## Sessions and retention

Choose a unique session name such as `checkout-k3f9` and include it literally
in every command. Shell variables may not survive between tool calls. If the
name is lost, run `agent-browser session list`; reuse a session only to resume
owned work. Retention follows [identity policy](../auth.md#choose-an-identity).

For a retained login, pass `--restore` from the first command. On evaluated
agent-browser 0.38.1, adding it later relaunches the browser and loses the current
login. That version saves plaintext cookies/localStorage under `~/.agent-browser`
with a 30-day expiry; verify the installed version's contract before relying on
those details. Apply [cleanup](../policy.md#ownership) when finished.

## Credential vault

When Prateek requests reusable credential storage, pipe the approved secret
reader directly into `agent-browser auth save <name> --url <login-url>
--username <user> --password-stdin`. This is agent-browser's encrypted credential
vault, separate from saved browser state. `auth login <name>` uses it; verify a
signed-in page element afterward. It does not establish support in other controllers.

## Workflow

1. Choose the [identity](../auth.md), then the session name and retention above.
   Continue when the session name and any `--restore` or `--profile` choice
   are fixed for the task.
2. Pass the session on every command. On commands that open or read pages,
   include the content and action controls:

   ```sh
   agent-browser --session checkout-k3f9 --content-boundaries \
     --max-output 50000 --confirm-actions eval,download open <url>
   ```

   Substitute the task's session name. For isolated state without `--restore`
   or `--profile`, add `--allowed-domains <list>` when the task names its sites.
   The allowlist is incompatible with restored state and profiles.
3. Follow the [interaction loop](../policy.md#interaction) with `snapshot -i`
   and current `@e` refs. Continue when the expected page state is observed.
4. Close the task's session and apply [resource cleanup](../policy.md#ownership).

## Pending actions

`--confirm-actions` holds `eval` and `download` for a tool-level decision.
Check [authorization](../policy.md#confirmation) before resolving it: confirm
an already authorized action, ask only for missing approval, or deny it.
Use the installed guide's `confirm <id>` or `deny <id>` command in the same
session. Keep the 60-second expiry; after expiry, reissue the action only if
it is still wanted and authorized, then resolve the new pending ID.
