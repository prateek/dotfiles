# Architecture Principles

## SoC — Separation of Concerns

**One-liner:** Each layer or module handles one concern.

**The rule:** UI logic, business logic, data access, and infrastructure should live in separate layers. A React component shouldn't know about SQL. A database module shouldn't format dates for the UI. Separation makes each layer independently testable, replaceable, and comprehensible.

**Violation:**
```typescript
// React component does everything
function UserList() {
  const users = await db.query('SELECT * FROM users WHERE deleted_at IS NULL');
  return <ul>{users.map(u => <li>{formatDate(u.created_at)} - {u.name}</li>)}</ul>;
}
```

**Correct:**
```typescript
// Data layer
function getActiveUsers() { return db.query.users.findMany({ where: isNull(deletedAt) }); }
// Presentation
function UserList({ users }: { users: User[] }) {
  return <ul>{users.map(u => <UserRow key={u.id} user={u} />)}</ul>;
}
```

**When to break it:** Prototypes, scripts, and small tools where layering adds more complexity than the code itself. Also server components that fetch and render in one place by design.

**Review question:** Does this module mix multiple concerns (data access, business logic, presentation)? Could each be tested independently?

---

## CQRS — Command Query Responsibility Segregation

**One-liner:** Separate read and write models.

**The rule:** The data model optimized for writes (normalized, consistent) is often different from the model optimized for reads (denormalized, fast). CQRS separates these: commands go through a write model with validation and business rules, queries go through a read model optimized for the specific view. Not every system needs CQRS — use it when read and write patterns diverge significantly.

**Violation:**
```typescript
// Same model for complex writes and simple reads
// Dashboard query joins 8 tables to reconstruct data the write model normalized
const dashboardData = await db
  .select()
  .from(orders)
  .innerJoin(users).innerJoin(products).innerJoin(categories)
  .innerJoin(payments).innerJoin(shipping).innerJoin(discounts)
  .innerJoin(reviews);
```

**Correct:**
```typescript
// Write model: normalized, validates invariants
async function placeOrder(cmd: PlaceOrderCommand) { /* ... */ }

// Read model: materialized view optimized for dashboard
async function getDashboardSummary(orgId: string) {
  return db.query.dashboardSummaries.findFirst({ where: eq(organizationId, orgId) });
}
```

**When to break it:** Simple CRUD apps where reads and writes use the same shape. CQRS adds complexity — only use when the read/write asymmetry justifies it.

**Review question:** Are read queries complex because they're reconstructing data the write model split apart? Would a separate read model simplify this?

---

## Hexagonal Architecture (Ports and Adapters)

**One-liner:** Business logic at the center, infrastructure at the edges.

**The rule:** The core domain has no knowledge of databases, HTTP, or external services. It defines "ports" (interfaces) that adapters implement. Inbound adapters (HTTP handlers, CLI) drive the core. Outbound adapters (DB, APIs, email) are driven by the core. This makes the domain testable without infrastructure and replaceable without rewriting business logic.

```
[HTTP Handler] → [Port: CreateUser] → [Domain Logic] → [Port: UserRepo] → [Postgres Adapter]
   inbound                                                    outbound
```

**Violation:**
```typescript
// Domain logic directly imports infrastructure
import { db } from './database';
import { sendgrid } from './email';

function createUser(data: UserInput) {
  const user = db.insert(users).values(data);
  sendgrid.send({ to: user.email, template: 'welcome' });
}
```

**Correct:**
```typescript
// Domain defines ports
interface UserRepository { create(data: UserInput): Promise<User>; }
interface EmailSender { sendWelcome(user: User): Promise<void>; }

// Domain logic uses ports
function createUser(data: UserInput, repo: UserRepository, email: EmailSender) {
  const user = await repo.create(data);
  await email.sendWelcome(user);
  return user;
}
```

**When to break it:** Small apps, scripts, serverless functions where the overhead of ports/adapters exceeds the benefit. Also: oRPC middleware chains effectively provide this separation without explicit port interfaces.

**Review question:** Does this business logic import infrastructure directly? Could the infrastructure be swapped without changing the domain?

---

## Bounded Contexts

**One-liner:** Explicit boundaries where a domain model applies.

**The rule:** From Domain-Driven Design. A "User" in the Auth context (email, password hash) is different from a "User" in the Billing context (payment method, subscription). Don't force one universal model — define explicit boundaries where each model is valid. Communicate between contexts through well-defined contracts (APIs, events), not shared databases.

**Violation:**
```typescript
// One God model used everywhere
type User = {
  id: string; email: string; passwordHash: string;  // auth
  stripeCustomerId: string; plan: Plan;              // billing
  teamIds: string[]; role: Role;                     // organization
  preferences: Preferences;                          // settings
  lastLogin: Date; sessions: Session[];              // session mgmt
};
```

**Correct:**
```typescript
// Auth context
type AuthUser = { id: string; email: string; passwordHash: string; };

// Billing context
type BillingCustomer = { userId: string; stripeId: string; plan: Plan; };

// Organization context
type OrgMember = { userId: string; teamIds: string[]; role: Role; };
```

**When to break it:** Small apps with one team and one context. Bounded contexts add overhead — they're most valuable when multiple teams own different parts of the domain.

**Review question:** Is this model trying to serve too many contexts? Would splitting it by domain boundary reduce complexity?
