# Meta: Keeping This Skill Current

Load when the repo's chezmoi practices change and this skill must reflect the change. Also load before structural edits to `SKILL.md` or any `references/<mode>.md`.

## When This Skill Must Change

Trigger an update if any of the following land in the dotfiles repo:

- A new `DOTFILES_INSTALL_*` (or sibling) env var is introduced or retired.
- A new `home/.chezmoi*/` directory or convention is added (e.g., `home/.chezmoiexternal/`).
- A mechanism is retired (e.g., `home/.chezmoidata/apps/*.toml`) — add the rule to "Do Not" lists.
- The numeric ordering scheme under `home/.chezmoiscripts/` changes (e.g., 2-digit → 3-digit).
- A new password manager replaces or augments 1Password.
- A new validation lane is added to the Makefile (e.g., `make test-foo`).
- A chezmoi command is renamed, removed, or its behavior changes (e.g., `chezmoi apply` flag semantics).
- A new app config pattern is adopted (e.g., a new `modify_` stub style).
- A repo-specific convention from `CLAUDE.md` or `AGENTS.md` is added or removed.
- Template helpers under `home/.chezmoitemplates/` are renamed or restructured.

If none of the above, the skill does not need to change. Drive-by updates create drift.

## What To Update Where

Use this table to find the right file. If a change touches more than one file, update all and cross-check the router table in `SKILL.md`.

| Change | File(s) to update |
|---|---|
| New / retired env var | `references/packages-and-secrets.md` (env var table); `SKILL.md` Repo-Specific Gotchas if high-stakes |
| New `home/.chezmoi*/` directory | `SKILL.md` Trigger Check + Mode Router; possibly a new reference file |
| Retired mechanism | `SKILL.md` Do Not; the relevant `references/<mode>.md` Common Pitfalls; remove obsolete instructions |
| Script ordering change | `references/workflow.md` ("Numeric ordering in this repo"); `SKILL.md` Repo-Specific Gotchas |
| New password manager | `references/packages-and-secrets.md`; `references/chezmoi-cheatsheet.md` (template functions list) |
| New Makefile lane | `SKILL.md` Validation Lanes table; relevant `references/<mode>.md` Validation section |
| Chezmoi command added/renamed/removed | `references/chezmoi-cheatsheet.md` (commands table + recipes); workflow.md if it changes the apply lifecycle |
| New app config pattern | `references/app-config.md` |
| New template helper | `references/chezmoi-cheatsheet.md` (functions list); `references/app-config.md` if it affects plist work |
| Convention added to repo `CLAUDE.md`/`AGENTS.md` | `SKILL.md` Repo-Specific Gotchas (only if durable and high-stakes); else the relevant `references/<mode>.md` |

## Editing Discipline

1. **Read the whole file you are editing.** Frontmatter parsers are picky and structural drift is silent. The `SKILL.md` description field is one block and must stay at or below 1024 characters.
2. **Update the cross-references.** If you add a new mode reference, add a row to the `SKILL.md` Mode Router table. If you delete one, remove the row.
3. **Keep `SKILL.md` ≤ 200 lines.** If a section grows, push depth into a `references/<mode>.md`. The router pattern is the design.
4. **Push universal rules sparingly.** A rule belongs in `SKILL.md` Universal Rules or Repo-Specific Gotchas only if violating it creates a destructive or hard-to-recover outcome. Otherwise it lives in a `references/<mode>.md` Common Pitfalls section.
5. **Self-contained means self-contained.** Do not link out to chezmoi.io. If you need to add chezmoi-tool knowledge, add it to `references/chezmoi-cheatsheet.md`. Relative paths to dotfiles repo files (`home/.chezmoidata/...`) are fine.
6. **Keep examples concrete and from this repo.** No fictional bundle IDs; reuse the ones already cited (Moom, Hammerspoon, etc.).

## Post-Edit Validation Checklist

After ANY edit to `SKILL.md`, `agents/openai.yaml`, or any `references/*.md`:

```text
# 1. Run the bundled validator (frontmatter, openai.yaml, evals.json,
#    mode-router consistency, self-containment, SKILL.md size).
./evals/validate.py

# 2. Whitespace cleanliness (only meaningful in a git workspace).
git diff --check
```

`evals/validate.py` is a single-file `uv run` script (no virtualenv setup needed); it returns exit 0 on success and prints one line per check.

If any check fails, fix before commit. The repo's `code-gardening` skill warns explicitly that "frontmatter/parser drift has bitten this repo before."

When you add a new validation rule, extend `evals/validate.py` rather than adding ad-hoc one-liners here. The single source of truth keeps drift down.

## Eval Maintenance

When you add a mode or change a guardrail, also touch the evals:

- New `DOTFILES_INSTALL_*` env var → add an eval that checks the agent updates the env var table.
- New `Do Not` rule → add an eval where the user asks for the forbidden action and the expected outcome is "agent declines and explains."
- New chezmoi command → add a recipe row, no eval needed unless it replaces a command users routinely run.

Keep the eval set tight: one happy-path plus one pitfall per mode is the target. Add evals only when a new guardrail, mode, or silent-fail surface lands; do not pad for coverage's sake. The evals should stay balanced across workflow, app-config, packages-and-secrets, meta, and source-target.

## Repo-Local Location

This skill lives at `/Users/prateek/dotfiles/.agents/skills/chezmoi-management/`. The managed-home skills tree under `home/dot_agents/skills/` is separate.

Maintenance steps after structural edits:

1. Confirm repo-local skill discovery only sees real top-level skills: `find .agents/skills -path '*/SKILL.md' -print` should not list fixture snapshots under `evals/`.
2. Run the post-edit validation checklist above from this location.
3. Test trigger overlap with the existing skills by spot-checking `code-gardening`, `fork-lifecycle`, and `conventions-maintainer`.

All references inside the skill use repo-relative paths (`home/.chezmoidata/`, `home/.chezmoiscripts/`) so they remain valid from the repo-local skill tree.

## Anti-Patterns To Avoid In Maintenance

- **Adding "from now on" notes to SKILL.md.** Those go in repo `AGENTS.md` or `CLAUDE.md`, not in a skill file. The skill encodes durable behavior; one-off rules belong elsewhere.
- **Pasting full chezmoi.io doc pages into a reference.** Vendor only what the skill needs. The cheatsheet is opinionated, not exhaustive.
- **Splitting a reference because it grew past 200 lines.** Look for a missing concept first; size alone is not a reason to split.
- **Updating one reference and forgetting the SKILL.md router table.** Always cross-check.
- **Letting evals drift from current behavior.** If you change a guardrail, the eval that tested the old guardrail must change too.
