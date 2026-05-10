---
name: swiftui-expert-skill
description: Write, review, or improve SwiftUI code following best practices for state management, view composition, performance, macOS-specific APIs, and iOS 26+ Liquid Glass adoption. Use when building new SwiftUI features, refactoring existing views, reviewing code quality, or adopting modern SwiftUI patterns.
---

# SwiftUI Expert Skill

This wrapper exists so skill loaders that only discover top-level skill directories can use the shared `swiftui-expert-skill`.

Primary skill body:
- `swiftui-expert-skill/SKILL.md`

Reference files used by that skill:
- `swiftui-expert-skill/references/`

When this skill is invoked:
1. Read `swiftui-expert-skill/SKILL.md`.
2. Resolve every `references/...` path from that nested skill relative to `swiftui-expert-skill/`.
3. Follow the nested skill exactly; this wrapper should not add its own workflow.
