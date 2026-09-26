# Playwright driver

Use for browser test suites, including Firefox and WebKit. Keep each task's
browser state isolated and its traces or recordings in the task's scratch
directory.

## Choose the runner

- **Repository install:** use the repository's Playwright configuration and
  documented test command; `npx playwright test` is the default entry point.
- **No repository install:** use Microsoft's task-local CLI through mise.
  Read `mise exec npm:@playwright/cli -- playwright-cli --help`, then use that
  full prefix for every command. Ask before making it a persistent mise tool.

## Run and verify

1. Select the required browser engines and test cases before launching.
   Follow the [focus policy](../policy.md#focus) for headed browsers.
2. Run the suite, or use the CLI's snapshot/action workflow for the selected
   cases. Observe each expected result; launching a browser is not test success.
3. Close task-created browsers. Report the engines and cases exercised,
   failures, and any untested requirements. Keep relevant artifacts in scratch.
