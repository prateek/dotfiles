# Ghost of Commits Past

Things a past agent landed or assumed that someone still has to verify. Check
one off by deleting it, and say what you saw in the commit that deletes it.

## 2026-10-20: marketplace layout (docs/plans/agent-marketplace-layout-plan.md)

- On a personal machine: `mise run test-tools`, `just test-python -p 'test_console_*.py'`, `just test-shell tests/bats/agents`; green.
- With `CODEX_HOME=$(mktemp -d)`: `codex plugin marketplace add raintree-technology/apple-hig-skills`, then `codex plugin add apple-hig-skills@apple-hig-skills`; the plugin lists its skills, and `.agents/skills/agent-skill-management/scripts/reconcile-upstream-agent-plugins --apply --agent codex` leaves it disabled.

Skills: `agent-skill-management`.

## 2026-10-20: ask skill replaced by src (docs/plans/src-skill-plan.md)

- On a personal machine, reconcile utils-agent for Codex; `codex` lists `utils-agent:src`, not `ask`.
- On the Linux devbox, `just -f agent-marketplace/justfile -d agent-marketplace test`; `test_src_fresh` passes, exercising GNU `stat`/`date`.
- With utils-agent 1.19.0 installed and no other apply running, `agent-marketplace/scripts/trigger-eval/run.sh --skill-dir agent-marketplace/src/utils-agent/skills/src --runs 5`; exits 0.
- Same conditions, `agent-marketplace/src/utils-agent/skills/acpx/evals/run_trigger_evals.sh --runs 5`; at least 18/19.

Skills: `agent-skill-management`.
