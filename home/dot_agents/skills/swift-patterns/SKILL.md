---
name: swift-patterns
description: Review, refactor, or build SwiftUI features with correct state management, modern API usage, optimal view composition, navigation patterns, performance optimization, and testing best practices.
---

# swift-patterns

This wrapper exists so skill loaders that only discover top-level skill directories can use the shared `swift-patterns` skill.

Primary skill body:
- `swift-patterns/SKILL.md`

Reference files used by that skill:
- `swift-patterns/references/`

When this skill is invoked:
1. Read `swift-patterns/SKILL.md`.
2. Resolve every `references/...` path from that nested skill relative to `swift-patterns/`.
3. Follow the nested skill exactly; this wrapper should not add its own workflow.
