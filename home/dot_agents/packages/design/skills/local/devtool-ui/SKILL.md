---
name: devtool-ui
description: |
  Build beautiful, performant, and accessible developer tool UIs using Svelte 5,
  CSS custom properties, and minimal dependencies. Covers the full stack:
  semantic color systems with dual themes, virtual scrolling for 20K+ item lists,
  Svelte 5 runes-based state management, SSE real-time updates, keyboard
  shortcuts with vim-style navigation, command palettes, responsive layouts, and
  embedding SPAs in backend binaries. Derived from production patterns in
  agentsview (761 stars). Use when building a developer tool frontend, designing
  a dashboard or data viewer, implementing virtual scrolling, setting up a Svelte
  5 app without SvelteKit, designing a dark theme, adding keyboard shortcuts, or
  embedding a frontend in a Go/Rust binary. Also use when asked to build a
  session viewer, log viewer, analytics dashboard, or any dense information
  display that needs to be fast, pretty, and keyboard-navigable.
---

# Developer Tool UI

Build dense, data-rich frontends that are fast, beautiful, and keyboard-native.
These patterns are derived from production code handling 20,000+ item lists with
sub-16ms frame budgets, dual-theme support, and zero component library overhead.

## When to Apply This Skill

Use these patterns when building:
- Session/conversation viewers
- Log and event stream displays
- Analytics dashboards with charts and heatmaps
- Search interfaces with full-text results
- Any developer tool that displays structured data with filtering

## Core Principles

1. **Semantic over descriptive.** Name CSS variables by meaning (`--tool-bg`),
   not appearance (`--amber-50`). Names survive theme changes.

2. **Minimal dependencies.** Three runtime deps (virtual-core, marked,
   dompurify) and hand-written everything else. Each dependency is a liability:
   bundle size, upgrade churn, behavior control, security surface.

3. **Performance through architecture.** Virtual scrolling, LRU caching,
   AbortController discipline, progressive loading. Performance is not a
   late-stage optimization -- it is a structural decision.

4. **Keyboard-first, mouse-supported.** Centralized keyboard handler, vim-style
   navigation, Cmd+K command palette, Escape cascade. Developer tools serve
   terminal-native users.

5. **Two complete themes.** Design light and dark simultaneously, not "light
   first, then invert." Tinted neutrals (blue-shifted dark backgrounds), not
   pure grays.

6. **No component library.** Scoped Svelte `<style>` blocks + CSS custom
   properties. Full control over micro-interactions, zero dead code, no
   specificity battles.

7. **Embedded SPA.** Plain Vite + Svelte 5 (no SvelteKit). Build to static
   files, embed in a Go/Rust binary via `//go:embed`. Single binary deployment.

## Architecture Overview

```
src/
  main.ts                    -- Mount root component
  app.css                    -- Global design system (custom properties, reset)
  App.svelte                 -- Route switch + modal layer
  lib/
    api/client.ts            -- Typed fetchJSON<T> wrapper
    stores/*.svelte.ts       -- Domain stores (UI, sessions, messages, sync, router)
    utils/                   -- Keyboard, content parser, debounce, LRU cache
    components/
      layout/                -- Header, three-column frame, status bar, resize
      sidebar/               -- Virtual-scrolled session list
      content/               -- Virtual-scrolled messages, block renderers
      command-palette/       -- Cmd+K fuzzy search overlay
      modals/                -- All modal dialogs
      analytics/             -- Charts, heatmaps, breakdowns
      usage/                 -- Cost and token tracking
      settings/              -- Configuration page
```

## Quick Reference: Key Decisions

### Color System

Define every color as a CSS custom property. Use four tiers: surfaces/borders,
text hierarchy, role-based backgrounds (`--user-bg`, `--tool-bg`), and named
accents (14 colors for entity coding). Use `color-mix()` for hover/active state
variations instead of separate color definitions.

For per-entity color coding, hash names with DJB2 into a 12-color palette of
CSS custom property references (theme-aware automatically).

Read `references/visual-design.md` for the complete color system, typography
stack, dark mode patterns, and micro-detail polish (scrollbars, transitions,
border-radius tokens).

### Performance

Virtualize both sidebar and message lists with `@tanstack/virtual-core` via a
Svelte 5 adapter (version counter pattern). Cache markdown renders in a 6,000-
entry Map-based LRU. Use AbortController on every async operation. Load messages
progressively in pages of 1,000 for sessions over 20K messages. Debounce search
at 300ms, find at 150ms.

Read `references/performance.md` for the virtualizer adapter code, LRU
implementation, progressive loading thresholds, and the
debounce+AbortController combo pattern.

### State Management

Singleton class stores with `$state` fields exported as module-level instances.
Split by domain: UI, sessions, messages, sync, router, search, starred, pins.
Use `$effect.root()` in constructors only for stores that need module-scope
side effects (localStorage sync, viewport tracking). Wire SSE via EventSource
for server-pushed updates, POST-based streaming for client-initiated operations.

Read `references/state-management.md` for store decomposition guidelines, SSE
integration patterns, the custom History API router, localStorage persistence
strategy, and the typed API client design.

### Keyboard and Accessibility

Single `keydown` listener on `document` with three tiers: modifier combos
(always fire), Escape (cascading close), single-key shortcuts (gated behind
`isInputFocused()` and modal state). Vim-style j/k navigation operating on
data indices, not DOM nodes. Cmd+K command palette with fuzzy search.

Use `:focus-visible` globally, `aria-label` on icon buttons, `role="separator"`
on resize handles, `aria-live="polite"` on dynamic counters. Single responsive
breakpoint at 768px, slide-out sidebar on mobile, `(pointer: coarse)` for touch
targets.

Read `references/keyboard-a11y.md` for the keyboard handler implementation,
Escape cascade, command palette architecture, ARIA patterns, and responsive
layout details.

### Component Architecture

Group components by feature domain (layout, sidebar, content, modals), not
type. Parse messages into typed segments (text, thinking, tool, code) with
dedicated renderers enabling block-level filtering. Use Svelte 5 snippets for
layout slot composition. Pointer capture for resizable panes. Scoped CSS in
components, `:global()` only for body-level state classes and `{@html}` content.

Read `references/architecture.md` for component organization patterns, the no-
SvelteKit rationale, Go embed pipeline, block-level content model, resizable
pane implementation, and the App.svelte conditional rendering pattern.

## Anti-Patterns

### Using Tailwind for dense information displays

Tailwind optimizes for forms and marketing pages. Expressing
`color-mix(in srgb, var(--accent-blue) 10%, transparent)` in utility classes
defeats the framework's purpose. Use scoped CSS for complex custom UIs.

### One giant store

A monolith store makes every `$effect` rerun on any field change. Split by
data ownership domain. But also do not create a store per component -- that
scatters related state and requires prop drilling or event buses.

### Scatter-registered keyboard handlers

Per-component keyboard listeners cause duplicate responses, orphaned listeners,
and ordering ambiguity. One centralized handler, one source of truth.

### Pure gray dark themes

`#1a1a1a` and `#2d2d2d` feel sterile. Tint your neutrals with a subtle color
bias (blue, purple, or warm brown). The effect is subliminal but makes the
interface feel intentional.

### Skipping virtual scrolling

"We only have a few hundred items" becomes "we have 20,000" faster than you
think. Virtualize from the start -- the adapter pattern makes it no harder
than a plain list.

### Forgetting AbortController

Without cancellation: race conditions (stale responses overwrite current data),
wasted connections, stale closures writing to outdated state. Every async store
method gets one.

## Output Guidance

When implementing a developer tool UI with this skill:

1. Start with `app.css`: define the complete custom property design system
   (both themes) before writing any components.
2. Create the store layer: domain stores with `$state` fields, API client,
   router.
3. Build the layout shell: three-column frame, header, status bar.
4. Add the content model: parser, block renderers, message list with
   virtualization.
5. Wire the keyboard system: centralized handler, shortcuts modal.
6. Polish: transitions, scrollbar styling, focus-visible, responsive breakpoint.

Reference the appropriate `references/*.md` file for implementation details
at each stage.
