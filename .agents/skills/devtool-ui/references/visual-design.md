# Visual Design Principles for Developer Tool UIs

## Table of Contents

1. [Color System Architecture](#color-system-architecture)
2. [Typography for Developer Tools](#typography-for-developer-tools)
3. [Dark Mode Done Right](#dark-mode-done-right)
4. [The No Component Library Approach](#the-no-component-library-approach)
5. [Micro-Details That Create Polish](#micro-details-that-create-polish)
6. [Per-Entity Color Coding](#per-entity-color-coding)

---

## Color System Architecture

### Use CSS custom properties as the single source of truth

Define every color as a CSS custom property on `:root`. Never hard-code hex
values in component styles. This creates one place to change colors and
guarantees that every component participates in theming automatically.

### Name colors semantically, not by hue

Do not name variables after what the color looks like (`--blue-500`,
`--gray-200`). Name them after what the color *means* in the interface:

- **Theme independence.** `--user-bg` can be a cool blue in light mode and a
  deep navy in dark mode.
- **Intent documentation.** `background: var(--tool-bg)` communicates purpose
  instantly.

Organize semantic colors into tiers:

```css
/* Tier 1: Surfaces and borders */
--bg-primary          /* Page background */
--bg-surface          /* Card / panel background */
--bg-surface-hover    /* Hover state on surfaces */
--bg-inset            /* Recessed or nested areas */
--border-default      /* Standard borders */
--border-muted        /* Subtle dividers */

/* Tier 2: Text hierarchy */
--text-primary        /* Headings, body text */
--text-secondary      /* Supporting text, metadata */
--text-muted          /* Timestamps, tertiary info */

/* Tier 3: Role-based backgrounds */
--user-bg             /* User message background */
--assistant-bg        /* AI response background */
--thinking-bg         /* Chain-of-thought / reasoning */
--tool-bg             /* Tool call / function results */
--code-bg             /* Code block background */

/* Tier 4: Named accents (for entity color-coding) */
--accent-blue --accent-rose --accent-purple --accent-amber
--accent-green --accent-teal --accent-indigo --accent-orange
/* ... up to 14 named accents */
```

Tier 3 is what makes a developer tool *feel* purpose-built. A chat viewer
with `--user-bg` and `--assistant-bg` communicates role at a glance.

### Separate structural shadows from color

```css
/* Light */
--shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.05);
--shadow-md: 0 2px 8px rgba(0, 0, 0, 0.08);
--shadow-lg: 0 4px 16px rgba(0, 0, 0, 0.1);

/* Dark -- increase opacity, shadows need more contrast */
--shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.25);
--shadow-md: 0 2px 8px rgba(0, 0, 0, 0.35);
--shadow-lg: 0 4px 16px rgba(0, 0, 0, 0.4);
```

---

## Typography for Developer Tools

### Font stacks

```css
--font-sans: "Inter", -apple-system, BlinkMacSystemFont,
  "Segoe UI", "Noto Sans", Helvetica, Arial, sans-serif;
--font-mono: "JetBrains Mono", "SF Mono", "Fira Code",
  "Fira Mono", Menlo, Consolas, monospace;
```

**Why Inter?** Designed for screens at small sizes, extensive OpenType
features, includes tabular figures. **Why JetBrains Mono?** Best glyph
coverage for programming symbols, excellent distinguishability (0/O, 1/l/I).

### Font rendering

```css
-webkit-font-smoothing: antialiased;
-moz-osx-font-smoothing: grayscale;
text-rendering: optimizeLegibility;
```

`antialiased` switches to grayscale antialiasing -- thinner, crisper text on
Retina/HiDPI. `optimizeLegibility` enables kerning and optional ligatures.

### Font feature settings

```css
font-feature-settings: "cv11", "ss01";
```

- **`cv11`**: Changes single-storey `a` to double-storey (more distinguishable
  from `o` at small sizes). Inter-specific.
- **`ss01`**: Opens apertures on `a`, `e`, `s`, `t` (improves readability at
  12-13px). Inter-specific.

Check your chosen font's OpenType feature list -- do not blindly copy tags.

### Size scale

- Body/content: 13px
- Metadata/timestamps: 10-11px
- Code blocks: 12-13px monospace
- Session names: 12px, font-weight 450
- Modal titles: 13px, font-weight 600

---

## Dark Mode Done Right

### Design both themes simultaneously

Do not "invert" the light theme. Design both in the same CSS block:

```css
:root {
  --bg-primary: #f5f6f8;
  --text-primary: #181b24;
  --accent-blue: #2563eb;
  color-scheme: light;
}
:root.dark {
  --bg-primary: #0d0d12;
  --text-primary: #e4e6eb;
  --accent-blue: #60a5fa;
  color-scheme: dark;
}
```

`color-scheme` adjusts native UI elements (scrollbars, form controls).

### Catppuccin approach: warmth through tinted neutrals

Pure grays feel sterile. Use blue-tinted deep colors:

```
Background   #0d0d12   (the `12` adds blue, not #0d0d0d)
Surface      #16161e   (the `1e` adds warmth, not #161616)
Hover        #1f1f2a   (the `2a` is distinctly indigo)
```

### Adjust accent colors per theme

Light-mode accents need saturation/darkness. Dark-mode accents need
lightness/desaturation:

```
             Light         Dark
blue         #2563eb       #60a5fa
rose         #e11d48       #fb7185
purple       #7c3aed       #a78bfa
```

### Role backgrounds in dark mode

Barely perceptible -- 2-4 lightness steps from the page background:

```css
/* Light: subtle tints */
--user-bg: #eef2ff;
--thinking-bg: #f5f3ff;
--tool-bg: #fffbf0;

/* Dark: deep, near-black tints */
--user-bg: #111827;
--thinking-bg: #1a1530;
--tool-bg: #1a1508;
```

---

## The No Component Library Approach

### When to skip Tailwind/shadcn

- Building a dense information display (log viewer, session browser, analytics)
- Need precise control over micro-interactions (`color-mix()` hover states)
- Component count is bounded (30-50 components total)
- Zero runtime overhead matters

### When to use a component library

- Generic SaaS with standard CRUD views
- Team of 5+ frontend devs needing enforced consistency
- Need accessibility out of the box without expertise

### The practical trade-off

Hand-rolling CSS means more CSS, but every line is intentional. No dead code,
no specificity battles, no version upgrade anxiety. Main cost: implement
accessibility yourself.

---

## Micro-Details That Create Polish

### Scrollbar styling

```css
::-webkit-scrollbar { width: 6px; height: 6px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb {
  background: var(--border-default);
  border-radius: 3px;
}
::-webkit-scrollbar-thumb:hover { background: var(--text-muted); }
```

### Transition timing

- Command palette items: 50ms
- Tab/pill toggles: 80ms
- Sidebar items: 100ms
- Star button opacity: 120ms
- Chevron rotation: 150ms

Never exceed 200ms for hover states. Use `ease` for transforms.

### `color-mix()` for state variations

```css
/* Selected state */
background: color-mix(in srgb, var(--accent-blue) 10%, transparent);
/* Hover */
background: color-mix(in srgb, var(--accent-blue) 18%, transparent);
/* Danger hover */
background: color-mix(in srgb, var(--accent-red) 10%, transparent);
```

### Border-radius consistency

Three tokens, nothing else:

```css
--radius-sm: 4px;   /* Pills, badges, inline code */
--radius-md: 6px;   /* Cards, code blocks, inputs */
--radius-lg: 8px;   /* Modals, panels, top-level containers */
```

### Layout dimensions as custom properties

```css
--header-height: 40px;
--status-bar-height: 24px;

@media (pointer: coarse) {
  :root { --header-height: 44px; }
}
```

---

## Per-Entity Color Coding

### The DJB2-hash-to-palette pattern

```typescript
const PROJECT_PALETTE = [
  "var(--accent-blue)", "var(--accent-purple)", "var(--accent-amber)",
  "var(--accent-teal)", "var(--accent-rose)", "var(--accent-green)",
  "var(--accent-indigo)", "var(--accent-orange)", "var(--accent-sky)",
  "var(--accent-pink)", "var(--accent-coral)", "var(--accent-lime)",
] as const;

function djb2(s: string): number {
  let h = 5381;
  for (let i = 0; i < s.length; i++) {
    h = ((h << 5) + h + s.charCodeAt(i)) | 0;
  }
  return Math.abs(h);
}

function projectColor(name: string): string {
  if (!name) return "var(--text-muted)";
  return PROJECT_PALETTE[djb2(name) % PROJECT_PALETTE.length]!;
}
```

**Why DJB2?** Fast, good distribution for short strings, deterministic.

**Why reference CSS custom properties?** The palette adapts to themes
automatically. **Why 12 colors?** Practical limit of perceptually distinct
colors in both themes.

### Known-entity color maps

For fixed sets (AI agent types), use a lookup map instead of hashing:

```typescript
const AGENT_COLORS = new Map([
  ["claude", "var(--accent-blue)"],
  ["codex", "var(--accent-green)"],
  ["copilot", "var(--accent-amber)"],
]);
```

Use hashing for open-ended sets (projects), maps for closed sets (agent types).
