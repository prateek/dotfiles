# Playwright driver

Playwright runs browser test suites, including Firefox and WebKit.

1. When the repository has its own Playwright install, use it:
   `npx playwright test`.
2. Otherwise run Microsoft's `playwright-cli` through mise for this task; its
   `--help` is the command reference. Each command may run in a new shell, so
   type the full prefix every time:

   ```bash
   mise exec npm:@playwright/cli -- playwright-cli --help
   mise exec npm:@playwright/cli -- playwright-cli open --browser=firefox <url>
   mise exec npm:@playwright/cli -- playwright-cli snapshot
   mise exec npm:@playwright/cli -- playwright-cli click e3
   mise exec npm:@playwright/cli -- playwright-cli close
   ```

   Ask Prateek before declaring it machine-wide in mise.
3. Use a fresh browser per task, and keep traces and recordings inside the
   task's scratch directory.
