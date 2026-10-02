# Handoff: Hermes Agent dotfiles integration

## Where things stand

- Branch `prateek/hermes-agent` in worktree `~/code/worktrees/dotfiles/hermes-agent`, pushed. Draft PR: https://github.com/prateek/dotfiles/pull/19 (one commit, `e8a69178`, docs only).
- Read these first. They hold the content, so it isn't repeated here:
  - `docs/research/hermes-agent-field-guide.md`: primary-source facts pinned to NousResearch/hermes-agent@`bed0d535`.
  - `docs/plans/hermes-agent-plan.md`: status `proposed`. It has the design, rollout, validation steps, and open questions.
- Community pulse: a last30days run saved at `~/Documents/Last30Days/hermes-agent-raw-v3.md`. Takeaways: daily releases, back up `~/.hermes`, the security/CVE caveat, Bot Mode (v0.21).
- The research subagent left a scratch clone of upstream at `$TMPDIR/hermes/src`. It's useful for checking source facts. Re-clone if it's gone.

## Decisions Prateek made (don't re-ask)

- Machines: personal-mbp, m4mini, work-mbp. work-mbp only after the XDR smoke test in plan step 5.
- Gateway: none for now.
- Provider: local model (Ollama/vLLM, `provider: custom`).
- Config ownership: Hermes managed scope. Prateek chose this over the merge-style `modify_` option.

## Next step

Implement the personal-mbp slice from the plan: the `agents.toml` entry, `run_after_07-hermes.sh.tmpl`, `home/dot_config/hermes-managed/readonly_config.yaml`, the `HERMES_MANAGED_DIR` export in `home/dot_config/zsh/dot_zshenv.tmpl`, and a local runtime. Then run rollout step 2's checks.

Things the next agent must not miss:
- Model the install hook on `home/.chezmoiscripts/run_after_07-cursor-agent.sh.tmpl`.
- Verify the env var in both zsh startup paths, per the AGENTS.md check.
- The work Mac has no sudo, and Cortex XDR killed omp there. See the omp comment in `home/.chezmoidata/machines.toml`. Don't add `hermes` to the work type until a manual smoke test passes.
- `chezmoi apply` dies at script 10 on some machines (periphery tap). Render and run a single hook to work around it.
- Never run chezmoi probes without `--config`, or they clobber the real config. See the chezmoi test-isolation memory.
- Still to pick: the local model for each machine.
- Commit and push only when asked. The PR stays a draft until Prateek says otherwise.

## Pending small item

The PR description should carry this handoff doc as an attachment (`gh attach 19 <file>`). If that hasn't happened yet, do it.

## Suggested skills

- `chezmoi-management`: templates, scripts, `.chezmoidata`, and dry-run/apply.
- `core:testing-philosophy`, plus `tests/README.md`: catalogue and template tests.
- `utils-agent:acpx`: only if the deferred `hermes acp` route gets picked up.
- `review:github-attachments`: attaching files to the PR.
- `review:land-changes`: when Prateek asks to land.
- `core:writing-for-humans`: PR text and final replies.
