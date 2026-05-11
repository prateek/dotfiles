# Meta: Keeping This Skill Current (snapshot)

Minimal snapshot for the meta-maintenance eval. Mirrors the relevant rows from the real reference.

## What To Update Where (excerpt)

| Change | File(s) to update |
|---|---|
| New / retired env var | `references/packages-and-secrets.md` (env var table); `SKILL.md` Repo-Specific Gotchas if high-stakes |
| New chezmoi command | `references/chezmoi-cheatsheet.md` |
| New password manager | `references/packages-and-secrets.md` |

## Post-Edit Validation Checklist (excerpt)

```text
./evals/validate.py     # single-file uv-run script that checks frontmatter, openai.yaml,
                        # evals.json, mode-router consistency, self-containment, size cap.
git diff --check
```
