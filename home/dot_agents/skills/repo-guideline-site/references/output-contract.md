# Output Contract

Before implementing the site, create a plan bundle. This makes the work reviewable and testable.

## Required Files

Create these under `.codex/site-plan/` or `docs/site-plan/`:

- `site-manifest.json`
- `audiences.md`
- `page-inventory.md`
- `media-plan.md`
- `build-test-plan.md`

## `site-manifest.json`

Required top-level fields:

- `repo`
- `positioning`
- `audiences`
- `pages`
- `workflows`
- `media`
- `implementation`
- `quality_gates`
- `writing`

Optional top-level fields:

- `ux_review`
- `visual_direction`

## Recommended Schema

```json
{
  "repo": {
    "name": "worktrunk",
    "source": "https://github.com/max-sixty/worktrunk",
    "product_type": "cli",
    "surfaces": ["terminal", "config-files", "git-worktrees"]
  },
  "positioning": {
    "promise": "Git worktree management for parallel AI agent workflows",
    "proof_points": [
      "Create and switch worktrees with one command",
      "Hooks automate setup and cleanup",
      "List view shows status, CI, and summaries"
    ],
    "differentiators": [
      "Workflow-focused instead of raw git worktree commands",
      "Designed for parallel agent usage"
    ]
  },
  "audiences": [
    {
      "id": "new-evaluator",
      "name": "Engineers evaluating the tool",
      "technical_level": "advanced",
      "needs": ["understand the core loop quickly", "see proof before setup friction"]
    }
  ],
  "pages": [
    {
      "slug": "index",
      "title": "Home",
      "kind": "landing",
      "purpose": "Value proposition, proof, quickstart, and route map",
      "audiences": ["new-evaluator"],
      "must_include": ["hero proof", "quickstart", "next steps"]
    }
  ],
  "workflows": [
    {
      "id": "install-and-first-success",
      "title": "Install and reach first success",
      "summary": "Get from zero to one successful task quickly",
      "audiences": ["new-evaluator"],
      "evidence": ["README.md", "docs/content/worktrunk.md"]
    }
  ],
  "media": [
    {
      "id": "core-loop",
      "kind": "terminal-demo",
      "tool": "vhs",
      "purpose": "Homepage hero proof",
      "workflow": "install-and-first-success",
      "validation": "snapshot"
    }
  ],
  "implementation": {
    "stack": "Zola",
    "reason": "Repo already uses a Zola docs site and generated command pages",
    "content_sources": ["README.md", "CLI help output", "docs/content/*.md"],
    "reference_strategy": "Generate reference pages from machine-readable sources; hand-author workflow pages",
    "verification_commands": ["zola build", "cargo test --test integration test_command_pages_and_skill_files_are_in_sync"]
  },
  "quality_gates": [
    {
      "id": "site-build",
      "description": "Static site build passes"
    }
  ],
  "ux_review": {
    "source": "ui-review-checklist",
    "viewports": ["390x844", "1440x900"],
    "checks": [
      "skip link and keyboard navigation",
      "focus states are visible",
      "proof media has reduced-motion or poster fallback",
      "no horizontal scroll on narrow widths"
    ],
    "findings": [
      "hero GIF needed a static poster image",
      "sticky nav needed touch-target tuning on smaller screens"
    ]
  },
  "visual_direction": {
    "concept": "editorial operator manual with proof-heavy terminal panels",
    "tone_keywords": ["precise", "confident", "craft-focused"],
    "memorable_hook": "hero proof panel framed like a product artifact",
    "typography": "expressive serif display with restrained sans-serif body",
    "color_strategy": "warm paper background with dark proof surfaces and one strong accent",
    "composition": "sticky shell, dense workflow cards, wide proof blocks, intentional negative space",
    "motion": "subtle page-load reveals and poster fallbacks for proof GIFs",
    "anti_patterns_to_avoid": [
      "default docs theme look",
      "generic dashboard cards without context",
      "purple gradient hero by reflex"
    ]
  },
  "writing": {
    "tone": ["precise", "evidence-first", "operator-friendly"],
    "plain_language_for": ["new-evaluator"],
    "glossary": true,
    "accessibility": ["alt text for screenshots", "captions or transcript for videos"]
  }
}
```

## Expectations

- `pages` should describe the user journey, not the repo tree
- `workflows` should map to real user tasks
- `media` should be linked to workflows and have validation methods
- `quality_gates` should be concrete enough to run
- `quality_gates` should include at least one rendered UI review or accessibility review item
- `ux_review`, when present, should capture viewports, checks, and concrete findings or fixes
- `visual_direction`, when present, should make the design point-of-view explicit enough to critique
- `writing` should capture audience adaptation and accessibility decisions
