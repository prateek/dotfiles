# Local fixtures

`../setup_fixture.sh <name> <absolute-destination>` materializes each fixture:

| Name | Conditions |
| --- | --- |
| `basic` | E0, E10 |
| `ambiguous-init` | E1 |
| `untracked-worktree` | E2 |
| `conflict` | E5 |
| `worktree-trunk` | E9 |
| `commit-only` | E11 |
| `lower-layer` | E12 |
| `ambiguous-delete` | E13 |
| `test-restack` | E14 |

The script creates sibling bare repositories and holder clones where needed.
Use a fresh destination and remove the whole destination prefix after a run.
Every repository sets the target `spice.*` values locally so ambient global
Git config cannot change the scenario.
