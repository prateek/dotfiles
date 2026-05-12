# Design Heuristics

## CQS — Command-Query Separation

**One-liner:** A method should either change state OR return data, never both.

**The rule:** Commands (mutate state, return void) and queries (return data, no side effects) should be separate. This makes code easier to reason about — you know a query is safe to call without worrying about side effects, and you know a command changes something.

**Violation:**
```typescript
// Deletes the item AND returns the remaining count
function removeItem(id: string): number {
  items.delete(id);
  return items.size;
}
```

**Correct:**
```typescript
function removeItem(id: string): void { items.delete(id); }
function getItemCount(): number { return items.size; }
```

**When to break it:** Stack/queue `pop()` operations, `getOrCreate` patterns, atomic operations where separating query and command creates race conditions.

**Review question:** Does this function both change state and return derived data? Could those be separate operations?

---

## Law of Demeter (LoD) — Principle of Least Knowledge

**One-liner:** Don't talk to strangers. Only call methods on your immediate collaborators.

**The rule:** A method should only call methods on: (1) its own object, (2) its parameters, (3) objects it creates, (4) its direct dependencies. Reaching through an object to call methods on its internals creates hidden coupling.

**Violation:**
```typescript
function getCity(order: Order): string {
  return order.getCustomer().getAddress().getCity(); // 3 levels deep
}
```

**Correct:**
```typescript
// Option 1: Delegate
function getCity(order: Order): string {
  return order.getShippingCity(); // Order knows how to get it
}
// Option 2: Pass what you need
function getCity(address: Address): string {
  return address.getCity();
}
```

**When to break it:** Fluent APIs, builder patterns, and data transfer objects where chaining is the intended interface. Also accessing plain data structures (not behavior-rich objects).

**Review question:** Is this code reaching through multiple objects? Could the intermediate object expose the needed data directly?

---

## Tell, Don't Ask

**One-liner:** Tell objects what to do instead of asking for their data and deciding externally.

**The rule:** Instead of querying an object's state and making decisions based on it, push the decision logic into the object itself. This keeps behavior with the data it operates on and reduces feature envy.

**Violation:**
```typescript
if (account.getBalance() > amount && !account.isFrozen()) {
  account.setBalance(account.getBalance() - amount);
}
```

**Correct:**
```typescript
account.withdraw(amount); // Account handles its own rules
```

**When to break it:** Pure data objects (DTOs, database rows), presentation logic where the view needs to inspect data to decide how to render it.

**Review question:** Is this code extracting data from an object just to make a decision that the object should own?

---

## POLA — Principle of Least Astonishment

**One-liner:** Code should behave the way a reader would expect.

**The rule:** Names, APIs, and behaviors should match programmer expectations. A `getUser()` function should not delete anything. A `save()` method should not send emails. Surprising behavior leads to bugs from incorrect assumptions.

**Violation:**
```typescript
function processOrder(order: Order) {
  // "process" is vague — this actually charges the card AND sends an email
  chargeCard(order.paymentMethod, order.total);
  sendConfirmationEmail(order.customer);
}
```

**Correct:**
```typescript
function chargeOrder(order: Order) { /* charges only */ }
function sendOrderConfirmation(order: Order) { /* emails only */ }
```

**When to break it:** Rarely. If an operation inherently does something surprising, document it prominently rather than relying on the name alone.

**Review question:** Would a new developer reading this function name guess what it actually does? Are there hidden side effects?

---

## Composition over Inheritance

**One-liner:** Compose behavior from small pieces rather than building deep class hierarchies.

**The rule:** Inheritance creates tight coupling between parent and child. Changes to the parent ripple to all children. Prefer composing objects from small, focused behaviors (mixins, decorators, higher-order functions, hooks) that can be combined freely.

**Violation:**
```typescript
class Animal { move() {} }
class Bird extends Animal { fly() {} }
class Penguin extends Bird { fly() { throw new Error('Cannot fly'); } } // violates LSP too
```

**Correct:**
```typescript
const withMovement = (entity) => ({ ...entity, move() {} });
const withFlight = (entity) => ({ ...entity, fly() {} });
const bird = withFlight(withMovement({ name: 'sparrow' }));
const penguin = withMovement({ name: 'penguin' }); // no flight
```

**When to break it:** When there's a genuine "is-a" relationship with a stable, shallow hierarchy (e.g., Error subclasses). Max 2 levels deep.

**Review question:** Is this inheritance hierarchy deeper than 2 levels? Would composition be simpler?

---

## IoC — Inversion of Control

**One-liner:** The framework calls you, not the other way around.

**The rule:** Instead of your code calling library functions procedurally, you provide callbacks/handlers that a framework invokes. Dependency injection is one form. React hooks, Express middleware, and event systems all use IoC. This decouples your logic from orchestration.

**Violation:**
```typescript
// Your code controls the flow
const db = new Database();
const auth = new AuthService(db);
const app = new App(auth);
app.start();
```

**Correct:**
```typescript
// Framework controls the flow, you provide the pieces
export default function handler(req: Request) {
  // Framework calls you with the request
  return new Response('ok');
}
```

**When to break it:** Simple scripts, CLIs, or one-off tools where a framework adds unnecessary indirection.

**Review question:** Is this code manually orchestrating things that a framework or container should manage?
