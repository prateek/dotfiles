# API & Interface Design Principles

## Idempotency

**One-liner:** Same request, same result. Repeating an operation produces the same outcome.

**The rule:** Idempotent operations can be safely retried without side effects. `PUT /users/1 { name: "Alice" }` always results in the same state. This is critical for reliability — network retries, queue redelivery, and crash recovery all depend on idempotency. Design write operations so duplicates are harmless.

**Violation:**
```typescript
// POST /charge — charges card every time it's called
// Network retry = double charge
app.post('/charge', (req) => {
  return stripe.charge(req.body.amount);
});
```

**Correct:**
```typescript
// Idempotency key prevents duplicate charges
app.post('/charge', (req) => {
  const key = req.headers['idempotency-key'];
  const existing = await cache.get(key);
  if (existing) return existing;

  const result = await stripe.charge(req.body.amount);
  await cache.set(key, result);
  return result;
});
```

**When to break it:** Pure queries (GET) are inherently idempotent. Append-only logs or event streams are intentionally non-idempotent.

**Review question:** What happens if this operation is called twice with the same input? Is there a mechanism to prevent duplicate side effects?

---

## Backwards Compatibility

**One-liner:** Don't break existing consumers.

**The rule:** Changes to shared interfaces (APIs, libraries, schemas) should be additive, not destructive. New fields are fine; removing or renaming fields breaks consumers. Use deprecation periods, versioning, or feature flags to transition. The more consumers you have, the more this matters (see Hyrum's Law).

**Violation:**
```typescript
// v1: { user: { name: string } }
// v2: { user: { fullName: string } }  // renamed — breaks all consumers
```

**Correct:**
```typescript
// v2: { user: { name: string; fullName: string } }  // additive
// v3: { user: { name: string; fullName: string } }  // deprecate name in docs
// v4: remove name after migration period
```

**When to break it:** Internal APIs with known, controlled consumers where you can coordinate the change. Breaking changes in a monorepo are cheaper than in a public API.

**Review question:** Does this change remove, rename, or change the type of any existing field? Are there consumers that will break?

---

## Semantic Versioning (Semver)

**One-liner:** Communicate the impact of changes through version numbers.

**The rule:** `MAJOR.MINOR.PATCH` — increment MAJOR for breaking changes, MINOR for new features (backwards-compatible), PATCH for bug fixes. This lets consumers know whether upgrading is safe. Applies to libraries, APIs, and any versioned contract.

**Format:**
```
1.0.0 → 1.0.1  (patch: bug fix, safe to upgrade)
1.0.1 → 1.1.0  (minor: new feature, safe to upgrade)
1.1.0 → 2.0.0  (major: breaking change, review needed)
```

**When to break it:** Pre-1.0 software is expected to break freely. Internal packages in a monorepo may not need strict semver if you control all consumers.

**Review question:** Does this change warrant a version bump? Is it a patch, minor, or major change?

---

## Defensive Coding

**One-liner:** Validate at system boundaries, trust internal code.

**The rule:** Validate all external input (user input, API responses, file contents, environment variables) at the point it enters your system. Once validated, internal code can trust the data. Don't scatter validation throughout business logic — validate once at the boundary, then use typed data downstream.

**Violation:**
```typescript
// Validation scattered everywhere
function createOrder(data: any) {
  if (!data.userId) throw new Error('no user');
  // 5 layers later...
  function calculateTotal(items: any) {
    if (!Array.isArray(items)) throw new Error('not array');
    items.forEach(item => {
      if (typeof item.price !== 'number') throw new Error('bad price');
    });
  }
}
```

**Correct:**
```typescript
// Validate once at boundary with Zod
const CreateOrderSchema = z.object({
  userId: z.string(),
  items: z.array(z.object({ productId: z.string(), price: z.number().positive() })),
});

function createOrder(data: z.infer<typeof CreateOrderSchema>) {
  // data is fully typed and validated — no checks needed downstream
  const total = data.items.reduce((sum, item) => sum + item.price, 0);
}
```

**When to break it:** When crossing trust boundaries within your own system (e.g., data from a shared database that another service writes to). Re-validate at each trust boundary.

**Review question:** Where does external data enter this code? Is it validated at the boundary? Is there redundant validation in internal code?
