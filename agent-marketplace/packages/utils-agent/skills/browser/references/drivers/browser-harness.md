# browser-harness driver

Live attach to Prateek's running Chrome through a CDP connection, from Browser
Use. Use it only when Prateek asks for his real Chrome session, in any
harness; every action then carries his full Chrome login.

1. Run it through mise for this task. Each command may run in a new shell, so
   type the full prefix every time. Read the version-matched guide from
   `browser-harness skill` before acting, then check the setup and turn off
   recordings and telemetry:

   ```bash
   mise exec pipx:browser-harness -- browser-harness skill
   mise exec pipx:browser-harness -- browser-harness --doctor
   mise exec pipx:browser-harness -- browser-harness recordings disable
   mise exec pipx:browser-harness -- browser-harness telemetry disable
   ```

   Ask Prateek before declaring it machine-wide in mise.
2. Drive Chrome with Python on stdin, as the guide shows. Open the task's page
   with `new_tab(url)` and work only in tabs the task opened:

   ```bash
   mise exec pipx:browser-harness -- browser-harness <<'PY'
   new_tab("https://example.com")
   print(page_info())
   PY
   ```

3. Use local Chrome. Browser Use Cloud browsers are billed and remote; use
   them only when Prateek names them.
4. Close the tabs the task opened. Leave the daemon and Prateek's tabs
   running.
