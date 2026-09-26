# browser-harness driver

Use for an explicitly requested live attach to Prateek's running Chrome.
Actions use his existing logins and permissions. This route applies in both
Orca and terminal harnesses.

## Workflow

1. **Prepare.** Run the task-local tool through mise. Read its guide, check
   that the local Chrome setup passes, and disable recordings and telemetry:

   ```sh
   mise exec pipx:browser-harness -- browser-harness skill
   mise exec pipx:browser-harness -- browser-harness --doctor
   mise exec pipx:browser-harness -- browser-harness recordings disable
   mise exec pipx:browser-harness -- browser-harness telemetry disable
   ```

   Use the full prefix on every call. A persistent mise installation is a
   separate choice; ask before adding one. Browser Use Cloud is billed and
   remote, so use local Chrome unless Prateek explicitly requests Cloud.
2. **Target.** Run Python on stdin as the installed guide specifies. Open a
   task-owned tab with `new_tab(url)` and retain its identifier. Follow the
   [focus policy](../policy.md#focus) before any operation that selects or
   raises a visible tab.
3. **Work.** Use the [interaction loop](../policy.md#interaction) within owned
   tabs. Continue until the requested result is visible in the page.
4. **Finish.** Close task-created tabs unless retained for requested reuse.
   Leave Prateek's pre-existing tabs and the browser-harness daemon running.
