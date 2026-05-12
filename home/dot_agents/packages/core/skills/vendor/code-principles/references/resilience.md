# Resilience Principles

## Fail Fast

**One-liner:** Validate early, throw early. Don't let bad state propagate.

**The rule:** When something is wrong, surface the error immediately rather than continuing with invalid state that crashes 5 layers deeper with an incomprehensible error. Validate inputs at system boundaries, assert preconditions at function entry, and prefer throwing over returning defaults for unexpected conditions.

**Violation:**
```typescript
function processPayment(amount: unknown) {
  // Silently coerces bad input, fails later in Stripe
  const cents = Math.round(Number(amount) * 100);
  return stripe.charge(cents); // NaN * 100 = NaN → cryptic Stripe error
}
```

**Correct:**
```typescript
function processPayment(amount: number) {
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new Error(`Invalid payment amount: ${amount}`);
  }
  return stripe.charge(Math.round(amount * 100));
}
```

**When to break it:** Graceful degradation in user-facing code (show a fallback UI instead of crashing), retry-able operations where transient failures are expected.

**Review question:** If invalid data enters this function, where does it fail? Is the error message clear, or does bad state propagate?

---

## Robustness Principle (Postel's Law)

**One-liner:** Be conservative in what you send, liberal in what you accept.

**The rule:** Accept flexible inputs (trim whitespace, handle case variations, accept optional fields) but produce strict, well-formed outputs. This makes your code more interoperable and forgiving of upstream quirks while ensuring downstream consumers get predictable data.

**Violation:**
```typescript
// Strict input: rejects "john@EXAMPLE.com" because it's not lowercase
function findUser(email: string) {
  return db.users.find(u => u.email === email);
}
```

**Correct:**
```typescript
// Liberal input: normalizes before processing
function findUser(email: string) {
  return db.users.find(u => u.email === email.toLowerCase().trim());
}
// Strict output: always returns normalized data
```

**When to break it:** Security-sensitive inputs (don't be liberal with SQL, HTML, or auth tokens). Also when "liberal acceptance" creates ambiguity — if two valid interpretations exist, reject rather than guess.

**Review question:** Does this code reject valid input due to strict formatting requirements? Does it produce consistent output regardless of input variations?

---

## Principle of Least Privilege

**One-liner:** Give code, users, and processes only the minimum access they need.

**The rule:** Don't grant write access when read suffices. Don't expose admin APIs to regular users. Don't give a function access to the entire database when it only needs one table. Minimizing privilege reduces the blast radius of bugs, compromises, and mistakes.

**Violation:**
```typescript
// Tool has full DB access when it only needs to read alerts
async function listAlerts(ctx: { db: FullDatabase }) {
  return ctx.db.query.alerts.findMany();
}
```

**Correct:**
```typescript
// Tool calls through scoped procedure with permission checks
async function listAlerts(ctx: ToolContext) {
  return call(alertRouter.list, {}, { context: toORPCContext(ctx) });
}
```

**When to break it:** Development/debugging environments where restricted access slows iteration. Admin tools that inherently need broad access (but should be gated behind auth).

**Review question:** Does this code have access to more resources than it actually uses? Could the scope be narrowed?
