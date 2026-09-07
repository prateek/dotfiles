# Keyboard Interaction, Accessibility, and Responsive Design

## Table of Contents

1. [Centralized Keyboard Handler](#centralized-keyboard-handler)
2. [Vim-Style Navigation](#vim-style-navigation)
3. [Command Palette](#command-palette)
4. [Shortcuts Modal](#shortcuts-modal)
5. [ARIA Patterns](#aria-patterns-for-developer-tools)
6. [Responsive Design](#responsive-developer-tools)
7. [Layout Cycling](#layout-cycling)

---

## Centralized Keyboard Handler

Register one `keydown` listener on `document`. A centralized handler
eliminates: duplicate responses, orphaned listeners, and ordering ambiguity.

```typescript
export function registerShortcuts(opts: ShortcutOptions): () => void {
  function handler(e: KeyboardEvent) {
    const meta = e.metaKey || e.ctrlKey;

    // Modifier shortcuts: always active
    if (meta && e.key === "k") {
      e.preventDefault();
      ui.toggleCommandPalette();
      return;
    }

    if (e.key === "Escape") { handleEscape(); return; }

    // Single-key shortcuts: skip modifiers, modals, input focus
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    if (ui.activeModal !== null || isInputFocused()) return;

    const action = keyActions[e.key];
    if (action) { e.preventDefault(); action(); }
  }

  document.addEventListener("keydown", handler);
  return () => document.removeEventListener("keydown", handler);
}
```

Three tiers: (1) modifier combos -- always fire, (2) Escape -- always fires
with cascading close, (3) single-key shortcuts -- gated behind focus/modal
checks. Allow Shift through the modifier gate (`?` requires Shift).

### isInputFocused guard

```typescript
function isInputFocused(): boolean {
  const el = document.activeElement;
  if (!el) return false;
  const tag = el.tagName;
  return tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT"
    || (el as HTMLElement).isContentEditable;
}
```

---

## Vim-Style Navigation

Developer tool users live in terminals. Offer `j`/`k` alongside arrows.

Navigate by ordinal index, not DOM node -- the message list uses virtual
scrolling, most items do not exist in the DOM:

```typescript
function navigateMessage(delta: number) {
  const items = messageListRef?.getDisplayItems();
  if (!items?.length) return;
  const curIdx = items.findIndex(i => i.ordinals.includes(selected));
  const nextIdx = Math.max(0, Math.min(items.length - 1, curIdx + delta));
  if (nextIdx === curIdx) return;
  ui.selectOrdinal(items[nextIdx]!.ordinals[0]!);
  messageListRef?.scrollToOrdinal(items[nextIdx]!.ordinals[0]!);
}
```

Clamp at both ends, do not wrap.

### Escape cascade

```typescript
function handleEscape(): void {
  if (inSessionSearch.isOpen) { inSessionSearch.close(); return; }
  if (ui.activeModal !== null) { ui.activeModal = null; return; }
  if (sessions.activeSessionId && !isInputFocused()) {
    sessions.deselectSession();
  }
}
```

Each level returns after acting. Users press Escape repeatedly to peel layers.

---

## Command Palette

Cmd+K replaces menus for power users. Single searchable entry point to every
action and content item.

- **Default mode** (< 3 chars): show recent sessions, filtered client-side
- **Search mode** (>= 3 chars): debounced server-side full-text search

The palette owns its own keydown for ArrowDown/ArrowUp/Enter. Does not
conflict with the global handler because the global handler gates single-key
shortcuts behind `ui.activeModal !== null`.

Auto-focus input on mount. Clean up on destroy (clear state, cancel requests).

---

## Shortcuts Modal

Press `?` to show all keyboard shortcuts. Define shortcuts as data:

```typescript
const isMac = navigator.platform.toUpperCase().includes("MAC");
const mod = isMac ? "Cmd" : "Ctrl";

const shortcuts = [
  { key: `${mod}+K`, action: "Open command palette" },
  { key: "j / down", action: "Next message" },
  { key: "k / up", action: "Previous message" },
  // ...
];
```

Detect platform once, show correct modifier label. Keep in sync with actual
bindings -- both derive from the same set.

---

## ARIA Patterns for Developer Tools

### `focus-visible` over `:focus`

```css
:focus-visible {
  outline: 2px solid var(--accent-blue);
  outline-offset: 1px;
}
```

Only shows focus ring for keyboard navigation, not mouse clicks.

### `.sr-only` utility

```css
.sr-only {
  position: absolute; width: 1px; height: 1px; padding: 0;
  margin: -1px; overflow: hidden; clip: rect(0,0,0,0);
  white-space: nowrap; border: 0;
}
```

### Interactive element labels

Every icon-only button needs `aria-label`. Decorative SVGs get
`aria-hidden="true"`.

### Resize handle

```svelte
<div role="separator" aria-label="Resize sidebar"
     aria-orientation="vertical"
     aria-valuemin={220} aria-valuemax={520}
     aria-valuenow={sidebarWidth}>
</div>
```

### Dynamic content

Use `aria-live="polite"` on elements whose text changes in response to user
action (search result counters, find match indicators).

---

## Responsive Developer Tools

### Single breakpoint at 768px

Developer tools have two viewport classes: "enough room for sidebar" and "not
enough." One breakpoint handles the transition.

### Slide-out sidebar on mobile

```css
@media (max-width: 767px) {
  .sidebar {
    position: fixed;
    top: var(--header-height);
    left: 0; width: 280px;
    z-index: 50;
    box-shadow: var(--shadow-lg);
  }
}
```

Auto-close sidebar when user selects an item on mobile.

### Touch target sizing

Use `(pointer: coarse)` for touch targets, not width queries:

```css
@media (pointer: coarse) {
  :root { --header-height: 44px; }
}
```

44px matches Apple's minimum recommended touch target.

### JavaScript viewport detection

```typescript
const mq = window.matchMedia("(min-width: 768px)");
this.isMobileViewport = !mq.matches;
mq.addEventListener("change", (e) => {
  this.isMobileViewport = !e.matches;
});
```

---

## Layout Cycling

Provide multiple message layouts, cycle with `l` key:

- **Default**: padded, role icons, timestamps, left border accent
- **Compact**: reduced padding, smaller icons, tighter spacing
- **Stream**: no headers, no borders, alternating background tint

```typescript
cycleLayout() {
  const idx = VALID_LAYOUTS.indexOf(this.messageLayout);
  this.messageLayout = VALID_LAYOUTS[(idx + 1) % VALID_LAYOUTS.length]!;
}
```

Apply via class on scroll container: `class="layout-{ui.messageLayout}"`.
Persist to localStorage.
