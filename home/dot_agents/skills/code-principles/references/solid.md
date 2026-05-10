# SOLID Principles

## SRP — Single Responsibility Principle

**One-liner:** A module should have one, and only one, reason to change.

**The rule:** Every class, module, or function should be responsible to one actor (stakeholder). If two different stakeholders could request changes to the same module, it has too many responsibilities. This doesn't mean "do one thing" — it means "change for one reason."

**Violation:**
```typescript
class UserService {
  createUser(data: UserInput) { /* saves to DB */ }
  sendWelcomeEmail(user: User) { /* sends email */ }
  generateReport(users: User[]) { /* builds CSV */ }
}
```
Three reasons to change: user creation logic, email templates, report format.

**Correct:**
```typescript
class UserRepository { create(data: UserInput): User { /* ... */ } }
class WelcomeEmailSender { send(user: User): void { /* ... */ } }
class UserReportGenerator { generate(users: User[]): string { /* ... */ } }
```

**When to break it:** Tiny utilities where splitting adds more complexity than the coupling. A `formatDate` helper doesn't need its own module.

**Review question:** Does this module have more than one reason to change? Who are the different stakeholders that could request changes here?

---

## OCP — Open/Closed Principle

**One-liner:** Open for extension, closed for modification.

**The rule:** Add new behavior by adding new code, not by changing existing code. Use polymorphism, strategy patterns, or plugin architectures so existing code remains untouched when requirements expand.

**Violation:**
```typescript
function calculateDiscount(type: string, amount: number) {
  if (type === 'student') return amount * 0.2;
  if (type === 'senior') return amount * 0.3;
  // add new discount type = modify this function
}
```

**Correct:**
```typescript
const discountStrategies: Record<string, (amount: number) => number> = {
  student: (amount) => amount * 0.2,
  senior: (amount) => amount * 0.3,
};
// add new discount = add entry, don't modify function
function calculateDiscount(type: string, amount: number) {
  return (discountStrategies[type] ?? (() => 0))(amount);
}
```

**When to break it:** When the "extension point" is speculative. Don't add plugin architectures for two variants. Apply when you see the pattern emerge (Rule of Three).

**Review question:** Will adding a new variant require modifying existing code, or can it be added alongside?

---

## LSP — Liskov Substitution Principle

**One-liner:** Subtypes must be substitutable for their base types without breaking behavior.

**The rule:** If `S` is a subtype of `T`, anywhere you use `T` you should be able to use `S` without surprises. Subtypes must honor the contract (preconditions, postconditions, invariants) of the base type.

**Violation:**
```typescript
class Rectangle {
  setWidth(w: number) { this.width = w; }
  setHeight(h: number) { this.height = h; }
  area() { return this.width * this.height; }
}
class Square extends Rectangle {
  setWidth(w: number) { this.width = w; this.height = w; } // breaks Rectangle contract
}
```

**Correct:**
```typescript
interface Shape { area(): number; }
class Rectangle implements Shape { /* ... */ }
class Square implements Shape { /* ... */ }
```

**When to break it:** Rarely. LSP violations usually indicate the inheritance hierarchy is wrong.

**Review question:** If I swap this subtype for the base type, would callers be surprised by different behavior?

---

## ISP — Interface Segregation Principle

**One-liner:** Many small interfaces are better than one fat interface.

**The rule:** Don't force clients to depend on methods they don't use. Split large interfaces into focused ones so implementers only need to satisfy what they actually provide.

**Violation:**
```typescript
interface Worker {
  work(): void;
  eat(): void;
  sleep(): void;
}
// RobotWorker must implement eat() and sleep() even though it doesn't eat
```

**Correct:**
```typescript
interface Workable { work(): void; }
interface Feedable { eat(): void; }
interface Restable { sleep(): void; }
```

**When to break it:** When the interface is consumed by a single client that uses everything. Splitting adds indirection without benefit.

**Review question:** Are any implementers of this interface forced to stub out methods they don't need?

---

## DIP — Dependency Inversion Principle

**One-liner:** Depend on abstractions, not concretions.

**The rule:** High-level modules (business logic) should not import low-level modules (database, HTTP). Both should depend on abstractions (interfaces/types). This decouples and makes testing easier.

**Violation:**
```typescript
import { PostgresDB } from './postgres';
class OrderService {
  private db = new PostgresDB();
}
```

**Correct:**
```typescript
interface OrderRepository { save(order: Order): Promise<void>; }
class OrderService {
  constructor(private repo: OrderRepository) {}
}
```

**When to break it:** In application composition roots (main, route handlers) where you wire concrete implementations. Also unnecessary for simple scripts or throwaway code.

**Review question:** Does this module import a concrete implementation it could instead receive as an abstraction?
