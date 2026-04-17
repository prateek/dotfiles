# State Management and Data Flow

## Table of Contents

1. [Singleton Class Store Pattern](#singleton-class-store-pattern)
2. [Store Domain Decomposition](#store-domain-decomposition)
3. [Effect Roots in Constructors](#effect-roots-in-constructors)
4. [SSE Integration](#sse-integration)
5. [Custom Routing Without SvelteKit](#custom-routing-without-sveltekit)
6. [localStorage Persistence](#localstorage-persistence)
7. [API Client Design](#api-client-design)

---

## Singleton Class Store Pattern

Structure each store as a plain TypeScript class with `$state` fields and
`$derived` computations. Export a module-level singleton.

```typescript
class SearchStore {
  query: string = $state("");
  results: SearchResult[] = $state([]);
  isSearching: boolean = $state(false);
  private abortController: AbortController | null = null;

  search(q: string) { /* ... */ }
  clear() { /* ... */ }
}

export const searchStore = new SearchStore();
```

**Why this over alternatives:**

- **Context API** requires a component tree. Stores that load data on import,
  run timers, or respond to SSE exist outside the component lifecycle.
- **Svelte 4 writable stores** use subscribe/set/update callbacks -- awkward
  for objects with methods. `$state` gives direct property assignment.
- **Zustand/external state libs** add a dependency and a reactivity bridge.
  Svelte 5 runes provide fine-grained reactivity on class fields natively.

---

## Store Domain Decomposition

Split by data ownership, not component structure:

| Store | Domain | Owns |
|---|---|---|
| `UIStore` | Presentation | Theme, layout, zoom, sidebar, modals, filters |
| `SessionsStore` | Entity list | Session list, filters, pagination, selection |
| `MessagesStore` | Entity detail | Messages, pagination, model detection |
| `SyncStore` | Infrastructure | Sync progress, SSE watch, polling, versions |
| `RouterStore` | Navigation | Route, params, URL sync, sticky params |
| `SearchStore` | Cross-cutting | FTS5 search with debounce and abort |
| `StarredStore` | User preference | Starred session IDs (persisted) |

**Rule:** If two components need the same reactive value, it belongs in a
domain store. If a value is only used inside one component, keep it local.

---

## Effect Roots in Constructors

Use `$effect.root()` in constructors for side effects that run at module
scope:

```typescript
class UIStore {
  theme: Theme = $state(readStoredTheme() || "light");

  constructor() {
    $effect.root(() => {
      $effect(() => {
        document.documentElement.classList.toggle("dark", this.theme === "dark");
        localStorage.setItem("theme", this.theme);
      });
    });
  }
}
```

**Why `$effect.root()`:** Module-level singletons instantiate at import time,
before any component mounts. `$effect()` can only run inside a component's
reactive context.

**When NOT to use it:** Most stores do not need it. Only 2 of 12+ stores
typically use it -- UI store (localStorage persistence, viewport tracking)
and stores with reactive cross-store observation.

---

## SSE Integration

### Pattern 1: EventSource for server-pushed updates

```typescript
export function watchSession(sessionId: string, onUpdate: () => void): EventSource {
  const url = `${getBase()}/sessions/${sessionId}/watch`;
  const es = new EventSource(url);
  es.addEventListener("session_updated", () => onUpdate());
  return es;
}
```

**Note:** `EventSource` does not support custom headers. Pass auth tokens as
query params. Document the security trade-off.

### Pattern 2: POST-based streaming

For client-initiated operations, use `fetch` with readable body stream and
parse SSE frames manually from response chunks.

### Polling as fallback

Combine SSE with periodic polling (10s intervals) for detecting changes from
external sources (CLI sync the UI did not trigger).

---

## Custom Routing Without SvelteKit

Skip SvelteKit when the SPA is embedded in a backend binary (Go, Rust, Tauri).
Build a History API router as a store:

```typescript
class RouterStore {
  route: Route = $state("sessions");
  sessionId: string | null = $state(null);
  params: Record<string, string> = $state({});

  constructor() {
    const initial = parsePath();
    Object.assign(this, initial);
    window.addEventListener("popstate", () => Object.assign(this, parsePath()));
  }

  navigate(route: Route, params = {}) {
    window.history.pushState(null, "", buildUrl(route, params));
    this.route = route;
    this.params = { ...this.stickyParams, ...params };
  }
}
```

**Sticky params:** Some query params (`?desktop`) must survive across all
navigations. Capture at init, merge into every URL.

**`pushState` vs `replaceState`:** `pushState` for user-initiated navigation.
`replaceState` for filter changes that should not pollute history.

---

## localStorage Persistence

### What to persist

Theme, layout mode, sidebar width, zoom, block filters, transcript mode.

### What NOT to persist

Active session ID, scroll position, modal state, loading flags, search query.

### Pattern

Read with validation at field initialization. Write via `$effect` in
`$effect.root()`. Always wrap in try/catch for private browsing:

```typescript
function readStoredLayout(): MessageLayout {
  try {
    const raw = localStorage?.getItem(LAYOUT_KEY);
    if (raw && VALID_LAYOUTS.includes(raw)) return raw;
  } catch { /* ignore */ }
  return "default";
}
```

---

## API Client Design

### Thin typed wrapper around fetch

```typescript
async function fetchJSON<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${getBase()}${path}`, authHeaders(init));
  if (!res.ok) throw new ApiError(res.status, await res.text());
  return res.json() as Promise<T>;
}
```

### Base URL discovery

Read `<base href>` from the HTML document. Supports reverse proxy subpaths
without build-time configuration.

### Exported functions, not a class

Export individual typed functions per endpoint. Keeps the API discoverable
and tree-shakeable:

```typescript
export function listSessions(params = {}): Promise<SessionPage> {
  return fetchJSON(`/sessions${buildQuery(params)}`);
}
```

### Why a thin wrapper beats a full HTTP client

- ~30 lines. Axios/ky add 10-30KB for unused features.
- `AbortController` support is native to `fetch`.
- Generic `<T>` provides type safety with zero runtime cost.
