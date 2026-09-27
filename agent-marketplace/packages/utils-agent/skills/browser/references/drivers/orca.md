# Orca driver

## Page workflow

1. Load the [orca-cli](../../../orca-cli/SKILL.md) skill and its browser
   reference: `orca skills get orca-cli --reference browser`. Use that
   version-matched guide for command syntax.
2. Choose the [browser identity](../auth.md), then create or reuse an owned
   tab. Record its `browserPageId` from `orca tab list --json`; pass
   `--page <id>` on every subsequent command.
3. Follow the shared [interaction loop](../policy.md#interaction) until the
   expected page state is visible. For password fields, use [Secrets](#secrets).

Follow the [focus policy](../policy.md#focus) before revealing a tab or
changing the foreground context. Page scoping alone does not preserve focus:
Orca's CDP input path can activate its window internally.

## Secrets

For an authorized password fill, use
[`orca-fill-stdin`](../../scripts/orca-fill-stdin). It keeps the password in
stdin and local RPC, focuses and clears the field, inserts text through Orca's
page-scoped keyboard RPC, and checks the exact field value with a salted digest.
The value stays out of eval expressions. It leaves submission to the caller. For a
text search that needs Enter, use `--type text --enter`; inspect the resulting
application state afterward.

1. **Target.** Inspect the owned page and identify its exact origin and a CSS
   selector matching one editable password input. Read the helper's `--help`
   for its arguments. It supports local macOS Orca 1.4.212 and 1.4.214;
   other versions require revalidation before changing its version gate.
2. **Fill.** Pipe the approved secret reader directly into the helper. Set
   `BROWSER_SKILL_DIR` to the directory containing this browser skill's
   `SKILL.md`, then substitute the page ID, origin, and selector:

   ```sh
   "$DOTFILES_CHECKOUT/scripts/chezmoi-hooks/op-service-account" read \
     --no-newline 'op://<vault-id>/<item-id>/<field-id>' |
     "$BROWSER_SKILL_DIR/scripts/orca-fill-stdin" \
       --page '<browserPageId>' --origin 'https://example.com' \
       --selector 'input[name="password"]'
   ```

   Set `DOTFILES_CHECKOUT` to the dotfiles checkout containing the service-account
   wrapper. Use the secret reader's no-newline option: the helper preserves stdin
   exactly. Keep the value out of shell arguments, output, and files.
   Entry is complete only when the helper exits successfully with
   `{"filled": true, "verified": true, "submitted": false}`.
3. **Verify the task.** After an authorized submission, check a page element
   that proves the requested result, such as the signed-in account menu.
   The fill receipt proves field entry only.

**Failure:** inspect the page before retrying. The helper suppresses runtime
error details and never retries uncertain writes. If its runtime or field
requirements cannot be met, use the [login hand-off](../auth.md#login-hand-off)
with the user's focus agreement.

**Validation:** a synthetic DOM test covers nested open shadow roots, field
focus, digest verification, event order, and a search result triggered by Enter keyup.
The local RPC contract is version-gated to 1.4.212 and 1.4.214. Before a live
secret fill on either release, repeat a dummy background test that checks
exact entry, foreground focus, and process arguments. A passing fixture does
not establish live browser compatibility.

**Other input paths:** `orca exec` does not forward stdin; its raw `fill` and
`auth login` can report success with empty fields. The public `orca fill`
accepts its value through a command argument and may report success while a
shadow-DOM input stays empty.
Native typing or pasting requires the [focus hand-off](../policy.md#focus).
Keep cookie values out of tool output; use [browser identity](../auth.md)
for session reuse.

## Page content and command flags

For page reads through `orca exec`, add
`--content-boundaries --max-output 50000` to the forwarded command. Typed
commands such as `orca snapshot` lack these flags; apply the
[untrusted-content policy](../policy.md#untrusted-content) to their output.

Choose navigation URLs from the task's sites: agent-browser's
`--allowed-domains` is incompatible with Orca's CDP attachment. Keep safety
settings on individual commands; changing `~/.agent-browser/config.json`
also changes Orca's own helper calls.

## Native UI and annotations

For native windows, dialogs, or app chrome, use `orca computer`: inspect the
named app's windows and accessibility state, then act on an element from that
snapshot. Apply the [focus policy](../policy.md#focus) before foreground input.
A successful browser `focus` or `tab switch` does not prove native keyboard
input will reach the page.

When Prateek wants to point at page elements, ask him to use Orca's element
annotation and send the notes to this agent.
