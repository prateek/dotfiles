# React Principles

Inspired by Bullet Proof React and established React community patterns.

## Feature Directories

**One-liner:** Organize by feature, not by file type.

**The rule:** Group all files related to a feature together: components, hooks, schemas, actions, tests. Don't scatter them across `components/`, `hooks/`, `utils/`, `types/` directories. This makes features self-contained, easy to find, and easy to delete.

**Violation:**
```
src/
├── components/
│   ├── UserList.tsx
│   ├── TeamList.tsx
│   └── DashboardWidget.tsx
├── hooks/
│   ├── useUsers.ts
│   ├── useTeams.ts
│   └── useWidgets.ts
├── types/
│   ├── user.ts
│   ├── team.ts
│   └── widget.ts
```

**Correct:**
```
src/features/
├── users/
│   ├── components/
│   │   └── UserList.tsx
│   ├── hooks/
│   │   └── useUsers.ts
│   ├── schemas.ts
│   ├── actions/
│   └── index.ts          # public API
├── teams/
│   └── ...
```

**When to break it:** Shared utilities, UI primitives, and cross-cutting concerns (auth, layout) live outside features.

**Review question:** Can I find everything related to this feature in one directory? If I delete this feature, is it a clean removal?

---

## Component SRP

**One-liner:** One job per component.

**The rule:** A component should do one of: (1) fetch data, (2) manage state, (3) render UI. Not all three. Split "smart" containers (data + logic) from "dumb" presentational components (props in, JSX out). This makes components reusable, testable, and easy to reason about.

**Violation:**
```tsx
function UserDashboard() {
  const [users, setUsers] = useState([]);
  const [filter, setFilter] = useState('');
  useEffect(() => { fetch('/api/users').then(r => r.json()).then(setUsers); }, []);
  const filtered = users.filter(u => u.name.includes(filter));
  return (
    <div>
      <input value={filter} onChange={e => setFilter(e.target.value)} />
      <table>{filtered.map(u => <tr><td>{u.name}</td><td>{u.email}</td></tr>)}</table>
      <Chart data={filtered.map(u => u.signupDate)} />
    </div>
  );
}
```

**Correct:**
```tsx
// Data fetching (server component or hook)
async function UserDashboardPage() {
  const users = await getUsers();
  return <UserDashboard users={users} />;
}

// State + orchestration
function UserDashboard({ users }: { users: User[] }) {
  const [filter, setFilter] = useState('');
  const filtered = users.filter(u => u.name.includes(filter));
  return (
    <>
      <SearchInput value={filter} onChange={setFilter} />
      <UserTable users={filtered} />
      <SignupChart users={filtered} />
    </>
  );
}

// Pure presentational
function UserTable({ users }: { users: User[] }) { /* renders table */ }
```

**When to break it:** Tiny components where splitting adds indirection without benefit. A simple `<Badge status={status} />` doesn't need a container.

**Review question:** Does this component fetch data, manage state, AND render complex UI? Could any of these responsibilities be extracted?

---

## Colocation

**One-liner:** Keep related files together.

**The rule:** Tests next to source files. Types next to the code that uses them. Styles next to components. The further apart related files are, the harder it is to maintain consistency between them. Colocation reduces the chance of stale or forgotten files.

**Violation:**
```
src/components/UserCard.tsx
src/__tests__/components/UserCard.test.tsx    # far away
src/types/UserCard.types.ts                   # far away
src/styles/UserCard.css                       # far away
```

**Correct:**
```
src/features/users/components/
├── UserCard.tsx
├── UserCard.test.tsx       # right next to it
└── UserCard.css            # right next to it
```

**When to break it:** Global test utilities, shared types, and test fixtures that serve multiple features.

**Review question:** Are the test, types, and styles for this component easy to find? Are they colocated or scattered?

---

## Unidirectional Data Flow

**One-liner:** Data flows down via props, events flow up via callbacks.

**The rule:** Parent components own state and pass it down. Children communicate upward via callback props. Don't create circular data flows where a child modifies parent state through a back-channel (global store mutations, refs, context abuse). This makes data flow predictable and debuggable.

**Violation:**
```tsx
// Child reaches into global store to mutate parent's data
function ChildRow({ userId }: { userId: string }) {
  const updateUser = useGlobalStore(s => s.updateUser);
  return <button onClick={() => updateUser(userId, { active: false })}>Deactivate</button>;
}
```

**Correct:**
```tsx
function ChildRow({ userId, onDeactivate }: { userId: string; onDeactivate: (id: string) => void }) {
  return <button onClick={() => onDeactivate(userId)}>Deactivate</button>;
}
```

**When to break it:** Global state managers (Zustand, Redux) are designed for cross-tree communication. Server state (React Query, SWR) also breaks strict unidirectional flow by design. Use these tools intentionally, not accidentally.

**Review question:** Can I trace where this data comes from and where changes originate? Or does state mutation happen through non-obvious channels?

---

## State Placement

**One-liner:** State should live at the lowest common ancestor that needs it.

**The rule:** Don't hoist state higher than necessary (causes unnecessary re-renders). Don't duplicate state (causes sync bugs). Find the lowest component that's a common ancestor of all consumers and put state there. Use URL state for shareable/bookmarkable state. Use server state for data that comes from APIs.

**Violation:**
```tsx
// App-level state for something only two sibling components need
function App() {
  const [selectedTab, setSelectedTab] = useState('overview');
  return <Layout>
    <Sidebar /> {/* doesn't use selectedTab */}
    <Header /> {/* doesn't use selectedTab */}
    <TabBar tab={selectedTab} onChange={setSelectedTab} />
    <TabContent tab={selectedTab} />
  </Layout>;
}
```

**Correct:**
```tsx
function App() {
  return <Layout><Sidebar /><Header /><Dashboard /></Layout>;
}
function Dashboard() {
  const [selectedTab, setSelectedTab] = useState('overview');
  return <>
    <TabBar tab={selectedTab} onChange={setSelectedTab} />
    <TabContent tab={selectedTab} />
  </>;
}
```

**When to break it:** When lifting state up simplifies prop threading (e.g., theme, locale, auth). Use context for truly global state.

**Review question:** Is this state owned by the right component? Could it live lower in the tree? Is any state duplicated?

---

## Barrel Exports

**One-liner:** Control the public API of a feature via index.ts.

**The rule:** Each feature directory exports its public API through an `index.ts` barrel. External code imports from the barrel, never deep into the feature's internals. This creates a clear contract: the barrel is the API, everything else is implementation detail. Makes refactoring safe — internals can change without breaking importers.

**Violation:**
```typescript
// Deep imports scattered across the codebase
import { UserCard } from '@/features/users/components/UserCard';
import { useUserPermissions } from '@/features/users/hooks/useUserPermissions';
import { UserSchema } from '@/features/users/schemas';
```

**Correct:**
```typescript
// features/users/index.ts
export { UserCard } from './components/UserCard';
export { useUserPermissions } from './hooks/useUserPermissions';
export { UserSchema } from './schemas';

// Consumer
import { UserCard, useUserPermissions, UserSchema } from '@/features/users';
```

**When to break it:** Deep imports into `actions/` and `schemas` are acceptable for code-splitting (avoid pulling entire feature bundles into server actions). This is a practical exception documented in your codebase.

**Review question:** Is external code importing directly into this feature's internals? Should these imports go through the barrel?
