# Eval 4 Fixture: Meta Skill Maintenance

Simulated state: a snapshot of the chezmoi-management skill itself (at `chezmoi-management/`) needs a one-line update.

The user adds a new env var: `DOTFILES_INSTALL_NIX=true` opts into Nix package management when chezmoi apply runs.

Expected behavior:

1. Agent loads `references/meta-skill-maintenance.md` to find where new env vars are documented.
2. Agent updates the env var table in `references/packages-and-secrets.md`.
3. Agent decides whether the rule is high-stakes enough to also surface in `SKILL.md` Repo-Specific Gotchas; explains its reasoning.
4. Agent does NOT touch the SKILL.md Mode Router (no new mode is being added).
5. Agent runs the post-edit validation checklist: YAML frontmatter parse, openai.yaml parse, evals.json parse, mode router cross-check.
6. Agent does not paraphrase chezmoi.io docs into the skill (self-contained rule).

The fixture's `chezmoi-management/` snapshot is intentionally minimal — the eval tests the agent's process, not the literal content of the snapshot.
