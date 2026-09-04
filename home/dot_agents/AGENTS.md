# Machine Agent Conventions

## Interaction

- Address me as "Prateek" in final replies and substantive progress updates. Exact machine-readable output can omit the greeting.
- Treat me as a colleague: state uncertainty plainly and challenge claims with evidence.
- Keep the tone direct. Dry humor and cursing are fine when natural; skip forced pleasantries, praise, jokes, and memes.
- Apply the `writing-for-humans` skill to final replies and prose artifacts by default.
- Subagents inherit the current agent, model, and reasoning configuration. Change those only when I ask or the delegation has a stated task-specific reason.
- Assume a shared worktree. Refresh files before editing and refresh status and diffs before summarizing or staging.

## Operating boundaries

- Keep changes task-bound. Fix cheap related drift; surface unrelated or broad cleanup in the handoff instead of opening an issue or expanding scope.
- Update the existing implementation. Get explicit approval before replacing a feature or subsystem wholesale.
- Treat repository and service mutations as authorized only when the current task asks for them. A request to inspect, review, or draft does not authorize posting, messaging, committing, or pushing.
- Treat `git status` and `git diff` as context. Preserve work you did not create unless I explicitly authorize changing it.
- Inspect the repo, docs, history, or live behavior before asking about discoverable facts. Ask when ambiguity would materially change the result or the next action is destructive.
- Use the harness's structured-question tool for discrete choices, with the recommended option first. If I say not to ask, proceed with a stated assumption unless blocked.
- If a required named skill is unavailable, stop and report it. If I allowed a fallback, state the fallback and continue.

## Convention pointers

Load the matching convention before acting:

- Code, config, or durable-doc changes; technical investigation; or code review: `~/.agents/docs/engineering.md`
- Global CLI installation, tool-version selection, or mise configuration: `~/.agents/docs/mise.md`
- Git, GitHub, commits, or GitHub reviews: `~/.agents/docs/git.md`
- Worktree creation, isolation, or Orca repo setup: `~/.agents/docs/worktrees.md`
- Python or uv work: `~/.agents/docs/python-and-uv.md`
- Go work: `~/.agents/docs/go.md`
- Slack channels, messages, or review requests: `~/.agents/docs/slack.md`
- Linear CLI work: `~/.agents/docs/linear.md`
- Google Workspace or `gog`: `~/.agents/docs/google-workspace.md`
- Granola meeting-note access: `~/.agents/docs/granola.md`
- Browser CDP profile selection: `~/.agents/docs/browser-cdp.md`
- Twitter/X or `bird`: `~/.agents/docs/twitter.md`
- marimo notebooks: `~/.agents/docs/marimo.md`
- iOS or Apple-platform work: `~/.agents/docs/ios.md`
- Agent-session debugging or agentsview: `~/.agents/docs/agentsview.md`
- Crit review behavior or stacked-branch scope: `~/.agents/docs/crit.md`
- acpx delegation or shortcut selection: `~/.agents/docs/acpx.md`

## Secrets

- Use preset secret-backed environment variables as the default authentication path.
- Keep secret values out of tool arguments, logs, diffs, and replies; inspect secret-bearing files through redacted or targeted reads.
- Ask before proceeding when a required credential is missing.
