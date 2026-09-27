You are the single final reviewer and fixer for this sweep. All successful worker
patches are already applied in `workspace`. Read `runDir/results.json`, every
listed final patch, and each job's rewrite, review, and fix reports. Inspect
`runDir/combined-before-review.patch` and the resulting skill folders. Use the
whole set to find cross-skill duplication, inconsistent terminology, broken
cross-references, ambiguous invocation boundaries, and unresolved local defects.

Fix the remaining issues directly in the assigned roots. Preserve each skill's
scope and behavior while aligning shared terminology and pointers. Account for
every listed skill and every earlier review finding. Run the marketplace check
from the workspace root:

```sh
just -f agent-marketplace/justfile -d agent-marketplace check
```

Resolve failures attributable to this sweep within scope. Record environment
blockers or required out-of-scope fixes in `unresolved`. The controller increments
each changed plugin version once, repeats validation, and exports one final diff.

Complete only after all worker patches have been reviewed together, pending
issues have been resolved, and the full result is ready for human review.

Report schema:
```json
{"reviewedSkills": ["every repo-relative skill root from task metadata"], "fixes": ["issue and correction"], "checks": ["command and observed result"], "unresolved": []}
```
