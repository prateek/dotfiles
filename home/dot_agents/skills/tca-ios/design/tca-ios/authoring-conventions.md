# Authoring Conventions

This skill is self-contained. Do not point users or agents to predecessor skill corpora from shipped files.

## Voice

Use short imperative guidance. Prefer one concrete pattern over a survey of alternatives. Mention tradeoffs when the wrong choice is plausible.

## Reference Files

Files under `references/` start with:

`# Applies to: TCA 1.25+, iOS 16+`

References about removing legacy APIs may add a note in the body that the legacy API is recognized only as migration input.

Then use:

- one H1 naming the topic
- `## Use When`
- `## Guidance`
- `## Pitfalls`
- `## Tests` when testing applies

Keep files below 400 lines. Split by workflow before compressing important details.

`SKILL.md` is capped at 450 lines. Keep the router, mode contracts, and load-bearing opinions inline rather than spilling them into a reference, since SKILL.md is what the model reads on every invocation.

Add a short `## Contents` block to any reference over 100 lines.

The skill's default target is iOS 16+ and TCA 1.25+. Keep older API guidance only when a reference diagnoses or migrates existing code.

## Source Discipline (Rewrite, Don't Quote)

Rewrite from source material in this repository. Do not paste through long source phrases. API names and tiny code idioms are allowed; explanatory prose should be original. This is the **rewrite-not-quote** rule: the shipped skill's voice is ours, not the source's.

When citing real repositories in `design/tca-ios/provenance.md`, verify with grep before marking the row `verified`.

## Adding References

When adding a reference:

1. Add the file under the closest topic directory.
2. Add a row to `references/index.md`.
3. Add a row to `design/tca-ios/provenance.md`.
4. Check whether `SKILL.md` routing needs a new trigger keyword. If you add a trigger to `SKILL.md`, update the same mode's `Optional` `trigger-keywords` column in `references/index.md` so the router and the index agree (this rule lives in `references/index.md` under "Update Rule").
5. Run `uv run --with pyyaml python /Users/prateek/dotfiles/.agents/skills/.system/skill-creator/scripts/quick_validate.py tca-ios`.
6. Run `wc -l tca-ios/SKILL.md tca-ios/references/**/*.md` and confirm `SKILL.md ≤ 450` and every reference `≤ 400`. Split any large reference by workflow before trimming substance.

## OpenAI Metadata

`agents/openai.yaml` follows the skill-creator `openai_yaml` reference:

- top-level `interface:` key
- quoted string values
- `display_name`, `short_description`, and `default_prompt`
- `default_prompt` explicitly mentions `$tca-ios`

Regenerate with:

```bash
uv run --with pyyaml python /Users/prateek/dotfiles/.agents/skills/.system/skill-creator/scripts/generate_openai_yaml.py tca-ios --interface 'display_name=TCA iOS' --interface 'short_description=Build, review, modernize, and diagnose TCA iOS apps' --interface 'default_prompt=Use $tca-ios to build, review, modernize, or diagnose a modern TCA iOS feature.'
```
