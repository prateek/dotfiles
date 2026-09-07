# Testing Principles

## TDD — Test-Driven Development

**One-liner:** Red-green-refactor. Write the test first.

**The rule:** (1) Write a failing test that describes the desired behavior. (2) Write the minimum code to make it pass. (3) Refactor while keeping tests green. TDD gives you confidence, drives clean design (hard-to-test code is usually poorly designed), and produces comprehensive test coverage as a side effect.

**Violation:**
```
1. Write 200 lines of implementation
2. Write tests after the fact to cover it
3. Tests mirror implementation details, not behavior
```

**Correct:**
```
1. Write test: "it should return 401 for unauthenticated requests"
2. Implement: add auth check → test passes
3. Refactor: extract auth middleware → tests still pass
```

**When to break it:** Exploratory prototyping where you don't yet know the interface. Spike first, then TDD the real implementation. Also pure UI work where visual testing may be more appropriate.

**Review question:** Were these tests written before or after the implementation? Do they test behavior or implementation details?

---

## AAA — Arrange-Act-Assert

**One-liner:** Structure every test in three clear phases.

**The rule:** (1) **Arrange** — set up test data, mocks, and preconditions. (2) **Act** — perform the action being tested. (3) **Assert** — verify the expected outcome. This structure makes tests readable and reveals what's actually being tested. One act per test.

**Violation:**
```typescript
test('user flow', () => {
  const user = createUser({ name: 'Alice' });
  expect(user.id).toBeDefined();        // asserting mid-test
  updateUser(user.id, { name: 'Bob' });
  const updated = getUser(user.id);
  expect(updated.name).toBe('Bob');
  deleteUser(user.id);
  expect(getUser(user.id)).toBeNull();   // multiple acts + asserts
});
```

**Correct:**
```typescript
test('updates user name', () => {
  // Arrange
  const user = UserFactory.create({ name: 'Alice' });

  // Act
  const updated = updateUser(user.id, { name: 'Bob' });

  // Assert
  expect(updated.name).toBe('Bob');
});
```

**When to break it:** Integration tests that verify a multi-step workflow may need multiple act-assert cycles. Keep each cycle clearly separated.

**Review question:** Does this test have a single clear act? Can I identify the arrange, act, and assert sections at a glance?

---

## Test Isolation

**One-liner:** Tests must not affect each other.

**The rule:** Each test should be independently runnable in any order. No shared mutable state between tests. No test depending on another test's side effects. Use setup/teardown hooks to reset state. If tests are flaky or order-dependent, isolation is broken.

**Violation:**
```typescript
let counter = 0;
test('increments', () => { counter++; expect(counter).toBe(1); });
test('increments again', () => { counter++; expect(counter).toBe(2); }); // order-dependent
```

**Correct:**
```typescript
test('increments from zero', () => {
  const counter = new Counter(0);
  counter.increment();
  expect(counter.value).toBe(1);
});
```

**When to break it:** True end-to-end tests that model user flows sometimes chain steps intentionally. Label these clearly and run them separately from unit tests.

**Review question:** If I run this test in isolation, does it pass? If I reverse test order, do they all still pass?

---

## Test Behavior, Not Implementation

**One-liner:** Test what the code does, not how it does it.

**The rule:** Tests should verify observable outcomes (return values, state changes, side effects) rather than internal mechanics (which private methods were called, in what order). Implementation-coupled tests break when you refactor, even if behavior is unchanged. This makes refactoring painful and tests less valuable.

**Violation:**
```typescript
test('creates user', () => {
  const spy = vi.spyOn(db, 'insert');
  createUser({ name: 'Alice' });
  expect(spy).toHaveBeenCalledWith('users', { name: 'Alice', createdAt: expect.any(Date) });
  // Breaks if you rename the table or change the insert API
});
```

**Correct:**
```typescript
test('creates user', async () => {
  const user = await createUser({ name: 'Alice' });
  expect(user.name).toBe('Alice');
  expect(user.id).toBeDefined();
  // Verifies behavior, survives refactoring
});
```

**When to break it:** When you specifically need to verify a side effect (email sent, event emitted). Even then, assert on the observable side effect, not the internal call chain.

**Review question:** If I refactor the internals without changing behavior, would this test break?

---

## Testing Pyramid

**One-liner:** Many unit tests, fewer integration tests, few end-to-end tests.

**The rule:** Unit tests are fast, isolated, and cheap — write many. Integration tests verify components work together — write enough to cover critical paths. E2E tests are slow and brittle — write few, covering only critical user journeys. The pyramid ensures fast feedback loops with good coverage.

```
        /\
       /e2e\        Few: critical user flows
      /------\
     /integr. \     Some: component interactions, API contracts
    /----------\
   /   unit     \   Many: business logic, utilities, pure functions
  /--------------\
```

**When to break it:** Frontend-heavy apps may use the "testing trophy" (more integration, fewer unit) because component integration tests provide more confidence than testing hooks in isolation.

**Review question:** Is this the right level of test for what we're verifying? Would a unit test give faster feedback? Would an integration test give more confidence?
