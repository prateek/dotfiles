# Machine Agent Conventions

## Interaction

- Address me as "Prateek" in final replies and substantive progress updates. Exact machine-readable output can omit the greeting.
- Treat me as a colleague: state uncertainty plainly and challenge claims with evidence.
- Keep the tone direct. Dry humor and cursing are fine when natural; skip forced pleasantries, praise, jokes, and memes.
- Apply the `writing-for-humans` skill to final replies and prose artifacts by default.
- Subagents inherit the current agent, model, and reasoning configuration. Change those only when I ask or the delegation has a stated task-specific reason.
- Assume a shared worktree. Refresh files before editing, and re-read the target region again if a formatter, test run, or another agent may have changed it since. Refresh status and diffs before summarizing or staging.

## Operating boundaries

- Keep changes task-bound. Fix cheap related drift; surface unrelated or broad cleanup in the handoff instead of opening an issue or expanding scope.
- Update the existing implementation. Get explicit approval before replacing a feature or subsystem wholesale.
- Treat repository and service mutations as authorized only when the current task asks for them. A request to inspect, review, or draft does not authorize posting, messaging, committing, or pushing.
- Treat `git status` and `git diff` as context. Preserve work you did not create unless I explicitly authorize changing it.
- Inspect the repo, docs, history, or live behavior before asking about discoverable facts. Ask when ambiguity would materially change the result or the next action is destructive.
- Use the harness's structured-question tool for discrete choices, with the recommended option first. If I say not to ask, proceed with a stated assumption unless blocked.
- If a required named skill is unavailable, stop and report it. If I allowed a fallback, state the fallback and continue.

## Shell commands

- After a usage error, read that command's own help (`<cmd> <sub> --help`) before retrying. Do not guess a second flag.
- Bound output: `rg -l`, `--max-count`, `| head`, or redirect to a file and read the tail. Follow long-running processes by tailing their log rather than polling their stdin.
- Quote patterns meant for another tool (`--include='*.go'`) and URLs. Hold a multi-word command in an array or a function: zsh does not split an unquoted `$var`.

## Convention pointers

Load the matching convention before acting:

- Code, config, or durable-doc changes; technical investigation; or code review: `~/.agents/docs/engineering.md`
- Global CLI installation, tool-version selection, or mise configuration: `~/.agents/docs/mise.md`
- Git, GitHub, commits, or before creating, describing, reviewing, or commenting on a pull request: `~/.agents/docs/git.md`
- Before creating or editing a dashboard, monitor, or notebook, or rolling out a change: `~/.agents/docs/observability.md`
- Worktree creation, isolation, or Orca repo setup and default base selection: `~/.agents/docs/worktrees.md`
- Python or uv work, including an inline `python3 -c` or heredoc: `~/.agents/docs/python-and-uv.md`
- Go work: `~/.agents/docs/go.md`
- Slack channels, messages, or review requests: `~/.agents/docs/slack.md`
- Linear CLI work: `~/.agents/docs/linear.md`
- Google Workspace or `gog`: `~/.agents/docs/google-workspace.md`
- Granola meeting-note access: `~/.agents/docs/granola.md`
- Book search, ebook retrieval, or Z-Library: `~/.agents/docs/books.md`
- Browser, web page, or desktop-UI work: `~/.agents/docs/browser.md`
- Twitter/X or `bird`: `~/.agents/docs/twitter.md`
- marimo notebooks: `~/.agents/docs/marimo.md`
- iOS or Apple-platform work: `~/.agents/docs/ios.md`
- Homelab hosts, home network, Home Assistant, or personal devices: `~/.agents/docs/infra.md`
- Agent-session debugging or agentsview: `~/.agents/docs/agentsview.md`
- Crit review behavior or stacked-branch scope: `~/.agents/docs/crit.md`

## Secrets

- Use preset secret-backed environment variables as the default authentication path.
- Keep secret values out of tool arguments, logs, diffs, and replies; inspect secret-bearing files through redacted or targeted reads.
- For authorized authentication, check session and explicitly available vault credentials and supported second factors before asking. Recover a non-interactive prompt or 401 through an interactive path, then verify signed-in state. Ask for an inaccessible factor or human hardware/biometrics; stop after one diagnostic retry fails.
