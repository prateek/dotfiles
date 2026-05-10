# Test Plans

- `__APP_NAME__.simprofile.toml` is the repo-owned execution-policy file for simulator runtime classes and preferred device types.
- `Project.swift` is the source of truth for suite structure, scheme names, and test target conventions.
- `Makefile`, the worktree helper, and the trace runner infer execution topology from Tuist metadata instead of checked-in `.xctestplan` files.
- `make generate` refreshes the generated Tuist project and workspace after manifest changes.
