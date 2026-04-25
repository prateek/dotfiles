# ADR 0003 — git-subrepo-managed `src/` subdir (merged into 0001)

- Status: **Merged into ADR 0001**
- Date: 2026-04-17

This ADR briefly proposed a `git-subrepo`-managed `src/` subdir architecture (Option B′) as an alternative to the original Option C. It was rejected after a live smoke test at `/tmp/fork-smoketest/` surfaced two deal-breakers:

1. `git-subrepo` squashes upstream commits on every sync. The fork's `main` branch history loses upstream's per-commit granularity — which the user explicitly values.
2. The build-system-path offset (`cd src && ...`) adds friction for day-to-day iteration.

Both the subtree-vs-subrepo comparison and the rejection rationale are folded into ADR 0001 under "Options considered" → "Option B′". Consult ADR 0001 as the canonical reference.

Preserved only to satisfy the ADR numbering convention (never renumber; never delete).
