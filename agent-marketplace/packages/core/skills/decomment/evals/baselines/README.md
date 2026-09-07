# Baseline arms for the comparative benchmark

These files are comparison arms for the decomment eval suite, not installable
skills. They are plain markdown (deliberately not named `SKILL.md`) so the
package renderer and validator never pick them up.

- `cody-decomment.md`: the source skill this one was adapted from. Internal
  identifiers in its examples are renamed for publication; rules, structure,
  and severity are unchanged.
- `john-style.md`: a write-time prevention prompt, verbatim.

The benchmark runs `evals.json` across four arms: no skill, `john-style.md`,
`cody-decomment.md`, and the live decomment SKILL.md. The runner materializes
each arm into a temporary skill directory for its runs. Acceptance: the live
skill matches or beats `cody-decomment.md` on every eval. `john-style.md` is
prevention-only and is expected to compete only on eval 3 (generation). The
authoritative record of the 2026-07 benchmark lives in
`docs/plans/decomment-skill-plan.md`; in short, both skills hit the ceiling on
evals 1-3 and 5-6, and the differentiator was eval 4, where the live skill
deleted 11-12 of 12 planted borderline markers per rep against Cody's
consistent 10.
