# Meta Principles

## Hyrum's Law

**One-liner:** With enough users, every observable behavior becomes a de facto API.

**The rule:** Regardless of your documented API contract, users will depend on any observable behavior: error message text, response ordering, timing, whitespace in output. This means "internal" behaviors become breaking changes when modified. Be deliberate about what you expose — hidden behaviors are still behaviors.

**Example:**
```
// You return users sorted by ID as an implementation detail
GET /users → [{ id: 1 }, { id: 2 }, { id: 3 }]

// Consumers start depending on this ordering
// You switch to a new DB that returns unordered results → breakage
```

**Mitigation:**
```
// Explicitly document that order is not guaranteed
// OR explicitly sort and make it part of the contract
GET /users?sort=id → [{ id: 1 }, { id: 2 }, { id: 3 }]
```

**When to break it:** Internal tools with few, known consumers where you can coordinate changes. Rapid prototyping where the API will be rewritten.

**Review question:** Are consumers likely depending on any undocumented behavior here (ordering, timing, error formats)? Should we make it explicit or randomize it?

---

## Connascence

**One-liner:** A generalization of coupling — two components are connascent when changing one requires changing the other.

**The rule:** Connascence ranges from weak (acceptable) to strong (dangerous):

| Strength | Type | Example |
|----------|------|---------|
| Weak | Name | Renaming a function requires updating all callers |
| | Type | Changing a parameter type requires updating all callers |
| | Meaning | Magic values: `status === 1` means "active" in two places |
| | Position | Function parameter order must match at call sites |
| | Algorithm | Encoder and decoder must use the same algorithm |
| Strong | Execution | Code must run in a specific order |
| | Timing | Code depends on when something happens |
| | Identity | Two references must point to the same object |

**Guideline:** Minimize connascence strength. Convert strong connascence to weak (e.g., replace positional args with named params). Reduce connascence across module boundaries; tolerate it within modules.

**When to break it:** Some strong connascence is inherent (crypto encode/decode must match). Focus on cross-boundary connascence.

**Review question:** What changes in module A would force changes in module B? Can this coupling be weakened?

---

## Locality of Behavior

**One-liner:** Code should be understandable by reading it in one place.

**The rule:** The behavior of a piece of code should be apparent from reading it locally, without chasing references across multiple files. Indirection (DI, event buses, decorators, middleware chains) has a cost: it scatters behavior. Favor colocation and explicit flow over clever abstraction.

**Violation:**
```typescript
// To understand what happens on user creation, you must read:
// 1. UserController.create()
// 2. UserCreatedEvent listener (different file)
// 3. WelcomeEmailHandler (different file)
// 4. AnalyticsTracker (different file)
// 5. AuditLogMiddleware (different file)
```

**Correct:**
```typescript
async function createUser(data: UserInput) {
  const user = await userRepo.create(data);
  await sendWelcomeEmail(user);     // explicit, visible
  await trackEvent('user_created'); // explicit, visible
  await auditLog('create', user);   // explicit, visible
  return user;
}
```

**When to break it:** When the explicit version becomes a God function. Event-driven architectures are sometimes necessary for decoupling — but be aware of the locality cost and document the full flow.

**Review question:** Can I understand this behavior by reading this file alone, or do I need to trace through multiple files?

---

## Pit of Success

**One-liner:** Design APIs so the easiest path is the correct path.

**The rule:** Make it hard to misuse your code and easy to use it correctly. Good defaults, required parameters for dangerous operations, types that prevent invalid states, and builder patterns that enforce required steps. Users should "fall into" correct usage naturally.

**Violation:**
```typescript
// Easy to misuse: forgetting to set required fields
const config = new Config();
config.setHost('localhost');
// Forgot setPort() — silently uses 0, fails at runtime
```

**Correct:**
```typescript
// Required params enforced at compile time
const config = createConfig({
  host: 'localhost',
  port: 5432, // TypeScript error if omitted
});
```

**When to break it:** Rarely. Sometimes power-user escape hatches are needed, but the default path should be safe.

**Review question:** What's the most likely way someone could misuse this API? Does the type system or API shape prevent it?
