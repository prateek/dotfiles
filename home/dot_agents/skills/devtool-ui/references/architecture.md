# Component Architecture and Build Patterns

## Table of Contents

1. [Component Organization](#component-organization-by-domain)
2. [No SvelteKit Decision](#the-no-sveltekit-decision)
3. [Embedding in Backend Binary](#embedding-in-a-backend-binary)
4. [Block-Level Content Model](#block-level-content-model)
5. [Resizable Pane Layout](#three-column-layout-with-resizable-panes)
6. [Scoped CSS + Global Design System](#scoped-css-and-global-design-system)
7. [Conditional Page Rendering](#conditional-page-rendering)

---

## Component Organization by Domain

Group by feature domain, not component type:

```
src/lib/components/
  layout/          -- structural shell: header, three-column frame, status bar
  sidebar/         -- session list, session item renderers
  content/         -- message stream: message list, typed block renderers
  command-palette/ -- Cmd+K search overlay
  modals/          -- all modal dialogs
  analytics/       -- dashboard charts, heatmaps, breakdowns
  usage/           -- cost and token usage views
  settings/        -- settings page and section components
```

A component gets its own directory when it becomes a page-level concern or
accumulates helper files. Co-locate related utilities next to the components
that use them (e.g., sidebar width constants in `layout/sidebar-width.ts`).

Shared cross-cutting utilities go in `src/lib/utils/`. Stores go in
`src/lib/stores/`. API client in `src/lib/api/`.

---

## The No SvelteKit Decision

Skip SvelteKit when:

- Frontend ships inside a compiled backend (Go, Rust, Tauri)
- No SSR requirement
- App runs on localhost or single-binary deployment
- Zero Node.js runtime in production

Trade-offs: no file-based routing (write 80-line manual router), no SSR
(unnecessary for localhost), no adapters (backend serves static files).

Entry point:

```typescript
import { mount } from "svelte";
import App from "./App.svelte";
import "./app.css";
mount(App, { target: document.getElementById("app")! });
```

---

## Embedding in a Backend Binary

Three stages:

1. **Vite build**: `npm run build` produces `frontend/dist/`
2. **Copy**: `cp -r frontend/dist internal/web/dist`
3. **Go embed**:

```go
//go:embed all:dist
var distFS embed.FS

func Assets() (fs.FS, error) {
  return fs.Sub(distFS, "dist")
}
```

The `all:` prefix includes dotfiles. `fs.Sub` strips the `dist/` prefix.

**SPA fallback**: serve `index.html` for any path that does not match a
static file.

**Version tracking**: inject git commit via Vite `define` at build time.
Compare with server `/version` endpoint on startup.

---

## Block-Level Content Model

Parse raw message text into typed segments, render each with a dedicated
component. This is the most important architectural decision for a
conversation viewer.

```typescript
type SegmentType = "text" | "thinking" | "tool" | "code" | "skill";

interface ContentSegment {
  type: SegmentType;
  content: string;
  label?: string;
  toolCall?: ToolCall;
}
```

**Why it matters:**

1. **Block filtering.** Users toggle visibility of thinking, tool, code
   blocks independently.
2. **Independent styling.** ThinkingBlock has collapse behavior. ToolBlock
   has collapsible I/O. CodeBlock has syntax highlighting + copy button.
3. **Efficient re-rendering.** Svelte's keyed `{#each}` only adds/removes
   toggled block types.
4. **Enrichment pipeline.** Parse text first, then merge structured API data
   in a second pass.

```svelte
{#each segments as segment}
  {#if segment.type === "thinking" && ui.isBlockVisible("thinking")}
    <ThinkingBlock content={segment.content} />
  {:else if segment.type === "tool" && ui.isBlockVisible("tool")}
    <ToolBlock content={segment.content} toolCall={segment.toolCall} />
  {:else if segment.type === "code" && ui.isBlockVisible("code")}
    <CodeBlock content={segment.content} language={segment.label} />
  {:else if segment.type === "text"}
    <div class="markdown">{@html renderMarkdown(segment.content)}</div>
  {/if}
{/each}
```

Cache parsed results keyed by `${messageId}:${contentLength}`.

---

## Three-Column Layout with Resizable Panes

Use Svelte 5 snippets for slot composition:

```svelte
<ThreeColumnLayout>
  {#snippet sidebar()}<SessionList />{/snippet}
  {#snippet content()}<MessageList />{/snippet}
</ThreeColumnLayout>
```

### Pointer capture for resize

`setPointerCapture()` locks all pointer events to the resize handle, even
when the cursor moves outside. Without it, fast mouse movement escapes the
element and the resize drops.

```typescript
function handlePointerDown(event: PointerEvent) {
  event.preventDefault();
  dragState = { startX: event.clientX, startWidth: sidebarWidth };
  resizeHandleElement.setPointerCapture(event.pointerId);
  // Add window-level listeners as fallback
}
```

### Width persistence

Store sidebar width in localStorage. Restore on mount, clamped to viewport:

```typescript
function clampSidebarWidth(desired: number, layout: number): number {
  const max = Math.min(SIDEBAR_WIDTH_MAX, layout - CONTENT_MIN);
  return Math.min(max, Math.max(SIDEBAR_WIDTH_MIN, desired));
}
```

### Disable text selection during resize

Toggle `user-select: none` on `document.body` via a CSS class.

---

## Scoped CSS and Global Design System

### Two layers

**Global `app.css`** owns: reset, custom properties on `:root`/`:root.dark`,
base element styles (scrollbars, selection, focus-visible), layout root.

**Component `<style>` blocks** consume custom properties. Svelte scopes class
names at build time -- no collisions between components.

### When to use `:global()`

Two cases only:

1. Body-level state classes (e.g., `sidebar-resizing` disabling text select)
2. Third-party content rendered via `{@html}` (markdown, syntax highlighting)

Keep `:global()` narrow and co-located with the controlling component.

---

## Conditional Page Rendering

The App.svelte switch pattern:

```svelte
{#if router.route === "usage"}
  <UsagePage />
{:else if router.route === "settings"}
  <SettingsPage />
{:else}
  <ThreeColumnLayout>
    {#snippet sidebar()}<SessionList />{/snippet}
    {#snippet content()}
      {#if sessions.activeSessionId}
        <MessageList />
      {:else}
        <AnalyticsPage />
      {/if}
    {/snippet}
  </ThreeColumnLayout>
{/if}

<!-- Modals render outside the route switch -->
{#if ui.activeModal === "commandPalette"}
  <CommandPalette />
{/if}
```

**Key patterns:**

- Full-page routes use a `.page-scroll` wrapper. Three-column layout only
  for the sessions route.
- Modals render outside the route switch -- can appear on any page.
- URL sync is bidirectional. Use `untrack()` to prevent reactive loops.
