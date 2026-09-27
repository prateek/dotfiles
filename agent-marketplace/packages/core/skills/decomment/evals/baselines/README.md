# Benchmark arms

Use these fixed comparison prompts when evaluating the live
[`decomment` skill](../../SKILL.md). They are plain Markdown so the package
renderer does not install them as skills.

| Arm | Purpose |
| --- | --- |
| `cody-decomment.md` | Source prompt adapted into the live skill. Internal example identifiers were renamed for publication; its rules, structure, and severity remain the benchmark baseline. |
| `john-style.md` | Verbatim prevention prompt. It addresses comment generation rather than cleanup. |

Run [`evals.json`](../evals.json) against no skill, these two arms, and the live
skill. The benchmark runner materializes each arm in a temporary skill
directory. The live skill must match or beat `cody-decomment.md` on every eval;
`john-style.md` is expected to compete only on eval 3.

The 2026-07 benchmark record at `docs/plans/decomment-skill-plan.md` in the
dotfiles source repo reports a ceiling on evals 1-3 and 5-6 for the live and
Cody arms. Eval 4 separated them: the live skill deleted 11-12 of 12 planted
borderline markers per repetition, compared with Cody's 10. Keep the arm
prompts and planted fixtures fixed when measuring changes to the live skill.
