# Simplicity Principles

## DRY — Don't Repeat Yourself

**One-liner:** Every piece of knowledge should have a single, unambiguous representation.

**The rule:** Duplication of logic (not just code) means changes need to happen in multiple places, inviting inconsistency. Extract shared logic into a single source of truth. Note: DRY is about knowledge duplication, not textual similarity — two functions that look alike but represent different concepts are NOT DRY violations.

**Violation:**
```typescript
// In user service
const isActive = user.status === 'active' && !user.deletedAt;
// In billing service (same logic, different file)
const isActive = account.status === 'active' && !account.deletedAt;
```

**Correct:**
```typescript
function isEntityActive(entity: { status: string; deletedAt: Date | null }) {
  return entity.status === 'active' && !entity.deletedAt;
}
```

**When to break it:** When the "duplicated" code serves different stakeholders and will likely diverge. Premature DRY creates coupling between unrelated features. See AHA below.

**Review question:** If this business rule changes, how many places need updating? Is this truly the same knowledge, or coincidentally similar code?

---

## YAGNI — You Aren't Gonna Need It

**One-liner:** Don't build features until they're needed.

**The rule:** Resist adding functionality for hypothetical future requirements. Speculative features add complexity, maintenance burden, and often turn out wrong. Build for today's known requirements. Extend later when the need is real.

**Violation:**
```typescript
// "We might need to support multiple currencies someday"
type Price = { amount: number; currency: Currency; exchangeRate: number; baseCurrency: Currency; };
// When the app only handles USD
```

**Correct:**
```typescript
type Price = { amount: number; }; // USD only, extend when needed
```

**When to break it:** When the cost of retrofitting later is genuinely prohibitive (database schema migrations, public API contracts). Even then, prefer the simplest thing that doesn't close the door.

**Review question:** Is this solving a current requirement or a hypothetical future one? What's the cost of adding this later vs. now?

---

## AHA — Avoid Hasty Abstractions

**One-liner:** The cost of the wrong abstraction is higher than the cost of duplication.

**The rule:** Don't abstract at the first sign of duplication. Premature abstractions bake in assumptions that may be wrong. Prefer duplication until the pattern is clear, then extract the right abstraction. Coined by Kent C. Dodds as an evolution of "DRY vs WET."

**Violation:**
```typescript
// After seeing 2 similar forms, creating a generic FormBuilder
// that handles 15 config options for 2 use cases
class FormBuilder<T extends FieldConfig> { /* 200 lines of framework */ }
```

**Correct:**
```typescript
// Two similar but independent form components
// Wait for the third form to reveal the actual shared pattern
function UserForm() { /* ... */ }
function TeamForm() { /* ... */ }
```

**When to break it:** When the abstraction is obvious and well-understood (e.g., extracting a `formatDate` utility after seeing it twice).

**Review question:** Has this abstraction been validated by at least 3 concrete use cases, or is it based on 1-2 examples?

---

## Rule of Three

**One-liner:** Abstract on the third occurrence, not the first or second.

**The rule:** The first time you write something, just write it. The second time, note the duplication but leave it. The third time, you have enough data to extract the right abstraction. This prevents premature generalization.

**Violation:**
```typescript
// First use of a pattern → immediately creating a generic utility
function createGenericCRUDService<T>(entity: string) { /* 100 lines */ }
```

**Correct:**
```typescript
// First time: inline
// Second time: note it, maybe copy-paste
// Third time: NOW extract the shared pattern with confidence
function createResourceService(config: ResourceConfig) { /* ... */ }
```

**When to break it:** When the pattern is universally understood (e.g., error handling wrappers, auth guards). No need to wait for 3 occurrences of `try/catch` boilerplate.

**Review question:** How many concrete instances of this pattern exist? Is this abstraction premature?
