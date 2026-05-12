# Applies to: TCA 1.25+, iOS 16+

# Modularity and App Architecture Review

## Use When

Use this for module boundaries, root reducer structure, shared modules, dependency clients, and scale risks.

## Inspect

- Feature modules and app/root modules.
- Shared domain modules and dependency-client modules.
- Cross-cutting concerns such as analytics, persistence, remote config, permissions, and notifications.
- Coupling between siblings.
- Circular dependencies.
- API DTOs versus domain models.
- Preview/test dependency organization.

## Findings To Look For

- Everything in one giant app module where ownership or build time suffers.
- Shared modules as junk drawers.
- Root reducers with too much business logic.
- Feature modules importing unrelated siblings.
- Global singleton state.
- Duplicated clients or models.

## Output

Include module summary, findings, recommended target structure, incremental boundary plan, and over-modularization risks.
