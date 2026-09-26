# agent-browser driver

Use this driver for terminal browser work selected by the skill's router.
Read `agent-browser skills get core` before acting; the installed guide owns
command syntax.

## Workflow

1. Choose the identity, session name, and retention in [auth.md](../auth.md).
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
