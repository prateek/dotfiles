# Performance Patterns for Developer Tool UIs

## Table of Contents

1. [Virtual Scrolling](#virtual-scrolling)
2. [LRU Caching](#lru-caching-for-render-heavy-content)
3. [AbortController Discipline](#abortcontroller-discipline)
4. [Progressive Loading](#progressive-paginated-loading)
5. [Debounce Strategy](#debounce-strategy)
6. [Minimal Dependencies](#minimal-dependency-philosophy)

---

## Virtual Scrolling

### When to use it

Virtualize any list where item count can exceed a few hundred. Session
sidebars, message lists with 20,000+ items, log viewers, search results.

### Fixed-height vs variable-height

Fixed-height: total height = count * rowHeight. Offset calculation is pure
arithmetic. Use for sidebar session lists with known row heights.

Variable-height: requires estimated sizes, `ResizeObserver` measurement, and
a cache of measured heights. Use `@tanstack/virtual-core` for this.

### The Svelte 5 adapter pattern

Bridge TanStack's imperative API to Svelte 5's reactive system via a
`$state` version counter:

```typescript
function createBaseVirtualizer<TScroll extends Element, TItem extends Element>(
  optsFn: () => VirtualizerOptions<TScroll, TItem> & { measureCacheKey?: unknown },
) {
  let instance: Virtualizer<TScroll, TItem> | undefined;
  let notifyPending = false;
  let _version = $state(0);

  // Batch synchronous onChange calls into one state update
  function bumpVersion() {
    if (notifyPending) return;
    notifyPending = true;
    setTimeout(() => { notifyPending = false; _version++; }, 0);
  }

  $effect(() => {
    const opts = optsFn();
    const resolvedOpts = {
      ...opts,
      onChange: (vInst, sync) => {
        instance = vInst;
        sync ? _version++ : bumpVersion();
        opts.onChange?.(vInst, sync);
      },
    };
    if (!instance) {
      instance = new Virtualizer(resolvedOpts);
    } else {
      instance.setOptions(resolvedOpts);
    }
    instance._willUpdate();
    return () => instance?._willUpdate();
  });

  return {
    get instance() { _version; return instance; },
  };
}
```

The `_version` read inside the getter subscribes consumers to changes.

### Measurement cache reset

When switching contexts (sessions), stale measurements produce wrong scroll
positions. Pass a `measureCacheKey` that changes on context switch:

```typescript
const virtualizer = createVirtualizer(() => ({
  count: displayItems.length,
  getScrollElement: () => containerRef ?? null,
  estimateSize: () => 120,
  overscan: 5,
  measureCacheKey: sessions.activeSessionId ?? "",
}));
```

### Scroll event throttling

Use `requestAnimationFrame`, not `setTimeout`:

```typescript
let scrollRaf: number | null = null;
function handleScroll() {
  if (scrollRaf !== null) return;
  scrollRaf = requestAnimationFrame(() => {
    scrollRaf = null;
    scrollTop = containerRef!.scrollTop;
  });
}
```

Use `position: absolute` + `transform: translateY()` for virtual rows (GPU
composited, skips layout).

---

## LRU Caching for Render-Heavy Content

### Why cache markdown rendering

Markdown-to-HTML involves parsing, HTML generation, and DOM sanitization.
1-5ms per message. A virtualizer re-renders 15-30 visible items per scroll
frame. Without caching: 30-150ms per frame, past the 16ms budget.

### The Map-based LRU

ES Map iteration order = insertion order. O(1) LRU without a linked list:

```typescript
export class LRUCache<K, V> {
  private map = new Map<K, V>();
  constructor(private capacity: number) {}

  get(key: K): V | undefined {
    if (!this.map.has(key)) return undefined;
    const value = this.map.get(key)!;
    this.map.delete(key);
    this.map.set(key, value);
    return value;
  }

  set(key: K, value: V): void {
    if (this.map.has(key)) {
      this.map.delete(key);
    } else if (this.map.size >= this.capacity) {
      this.map.delete(this.map.keys().next().value!);
    }
    this.map.set(key, value);
  }

  clear(): void { this.map.clear(); }
}
```

### Sizing strategy

- **Markdown render cache: 6,000 entries.** Covers the working set of a
  20,000-message session without thrashing.
- **Content parsing cache: 500 entries.** Parsing is cheaper; 500 covers
  visible window plus generous overscan.
- Clear caches on context switch.

### Cache key design

```typescript
const cacheKey = `${hasToolUse ? "t" : "n"}:${messageId}:${contentLength}`;
```

`contentLength` acts as a version stamp for streaming messages.

---

## AbortController Discipline

### The rule

Every async operation gets an `AbortController`. Every `fetch` receives its
`signal`. Every new request aborts the previous one. No exceptions.

### Why

Without cancellation: race conditions (stale responses overwrite current
data), wasted network (abandoned requests consume connection slots), stale
closures (callbacks write to outdated state).

### Pattern: class-level controller

```typescript
class MessagesStore {
  private abortController: AbortController | null = null;

  async loadSession(id: string) {
    this.abortController?.abort();
    const ac = new AbortController();
    this.abortController = ac;
    try {
      const data = await api.getMessages(id, { signal: ac.signal });
      if (this.sessionId !== id) return; // guard stale closure
      this.messages = data.messages;
    } catch (err) {
      if (err instanceof DOMException && err.name === "AbortError") return;
      console.warn("Failed to load messages:", err);
    } finally {
      if (!ac.signal.aborted) this.loading = false;
    }
  }
}
```

### The finally guard

Only clear loading state if the signal was not aborted -- a new request is
already in flight, clearing state would flash "idle" for one frame.

---

## Progressive Paginated Loading

### Strategy

Below 20,000 messages: load everything in pages. Above: load the newest page
first and paginate backward.

```typescript
const MESSAGE_PAGE_SIZE = 1000;
const FULL_SESSION_MESSAGE_THRESHOLD = 20_000;
```

### Wiring load-more to the virtualizer

Check distance from the edge in the scroll handler:

```typescript
function handleScroll() {
  scrollRaf = requestAnimationFrame(() => {
    scrollRaf = null;
    const items = virtualizer.instance?.getVirtualItems() ?? [];
    if (items.length > 0 && messages.hasOlder) {
      if (items[0]!.index <= 30) { // threshold
        messages.loadOlder();
      }
    }
  });
}
```

### Why 30 items, not 5 or 100

- Too small (5): user scrolls past before the network round-trip completes.
- Too large (100): fetch triggers too early, loading pages never reached.
- 30 items is ~2-3 viewport heights. Gives 200-400ms head start.

### Deduplication guard

Prevent concurrent load-more requests (scroll fires 60 times/second):

```typescript
private loadOlderPromise: Promise<void> | null = null;
async loadOlder() {
  if (this.loadOlderPromise || !this.hasOlder) return;
  const p = this.doLoadOlder().finally(() => {
    if (this.loadOlderPromise === p) this.loadOlderPromise = null;
  });
  this.loadOlderPromise = p;
}
```

---

## Debounce Strategy

### Two tiers

| Operation | Interval | Reason |
|-----------|----------|--------|
| Global search | 300ms | Network round-trip. 300ms captures full word. |
| In-session find | 150ms | Searches loaded content. Shorter = more responsive. |

### Combining debounce with AbortController

```typescript
class SearchStore {
  private debouncedSearch = debounce((q: string) => {
    this.executeSearch(q);
  }, 300);

  search(q: string) {
    this.query = q;
    if (!q.trim()) {
      this.debouncedSearch.cancel();
      this.abortController?.abort();
      this.results = [];
      return;
    }
    this.abortController?.abort(); // abort immediately, before debounce
    this.debouncedSearch(q);
  }
}
```

---

## Minimal Dependency Philosophy

### Why 3 runtime deps is a feature

- `@tanstack/virtual-core` -- complex measurement reconciliation
- `marked` -- markdown spec compliance
- `dompurify` -- security-critical HTML sanitization

Everything else (LRU cache, debounce, router, state management, keyboard
shortcuts) is hand-written.

### What to depend on vs what to write

**Depend** when: algorithm is complex and well-studied, getting it wrong has
security implications, requires domain expertise.

**Write yourself** when: implementation under 50 lines, need tight framework
integration, library brings transitive deps that dwarf your code.

Svelte 5 runes replace state management libraries entirely -- a store is a
plain class with `$state` fields. No Redux, no Zustand, no signals library.
