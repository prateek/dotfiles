# Applies to: TCA 1.25+, iOS 16+

# Case Paths and Enums

## Use When

Use this for enum state, enum actions, navigation destinations, and case-specific access.

## Guidance

- Add `@CasePathable` to enums that need case paths outside TCA macro synthesis.
- Use dynamic member case paths where APIs expect key-path-like case access.
- Use enum reducers for navigation domains and heterogeneous path elements.
- Prefer case paths over manual `if case` extraction when composing reusable helpers.
- Use TestStore case-path receives for actions with non-Equatable payloads, especially `Result<Success, any Error>`.
- Prefer enum state when the UI can be in exactly one of several modes.

## Example

```swift
@CasePathable
enum Loadable<Value> {
  case idle
  case loading
  case loaded(Value)
  case failed(String)
}

if state.mode.is(\.loading) {
  return .none
}
```

Mutate a payload in place with `.modify`:

```swift
state.mode.modify(\.loaded) { value in
  value.append(newRow)
}
```

`modify` runs the closure only when the case matches, so it is safe to call without first checking `.is(...)`.

## TestStore Case Paths

Modern TCA can receive an effect action by case path:

```swift
await store.receive(\.searchResponse.success) {
  $0.results = [.fixture]
  $0.isLoading = false
}

await store.receive(\.searchResponse.failure) {
  $0.isLoading = false
  $0.errorMessage = "Could not load results."
}
```

This avoids forcing `Action: Equatable` when a case carries `Result<Success, any Error>`. If the extracted payload is `Equatable`, the value overload can assert it without making the whole action equatable:

```swift
await store.receive(\.delegate.saved, savedID)
```

## TCA Navigation

`@Reducer enum Destination` and `@Reducer enum Path` synthesize the state/action plumbing that TCA navigation APIs expect. In TCA 1.25+ prefer projected destination scopes where the migration guide calls for them.

## Pitfalls

- Do not model independent booleans when one enum captures the real state.
- Do not leak a child destination enum into unrelated parent features.
- Do not use case paths as an excuse to make one giant action enum. Feature boundaries still matter.
- Do not add manual case-path boilerplate for enums already handled by the TCA macros unless a compiler diagnostic proves it is needed.
