# Applies to: TCA 1.25+, iOS 16+

# Shared State Tests

## Use When

Use this when features use `@Shared`, `@SharedReader`, app storage, file storage, or shared parent-to-child values.

## Guidance

- Initialize shared values explicitly in test state.
- When persistence is involved, isolate storage per test.
- Test that two holders of the same shared value observe the same mutation.
- Use projected shared values when constructing child state from parent state.
- Be careful with delegate actions that mutate shared state and dismiss the child in the same flow.
- Reconstruct the feature when the behavior promises persistence across launches.
- Keep shared storage keys and file URLs unique per test.

## Example

```swift
@MainActor
@Test
func sharedSettingSurvivesReconstruction() async {
  let key = "settings.notifications.\(#function)"

  var store = TestStore(
    initialState: Settings.State(
      notificationsEnabled: Shared(.appStorage(key), false)
    )
  ) {
    Settings()
  }

  await store.send(.notificationsToggled(true)) {
    $0.$notificationsEnabled.withLock { $0 = true }
  }

  store = TestStore(
    initialState: Settings.State(
      notificationsEnabled: Shared(.appStorage(key), false)
    )
  ) {
    Settings()
  }

  await store.send(.task) {
    $0.$notificationsEnabled.withLock { $0 = true }
  }
}
```

Use the exact shared-storage construction style from the codebase. The point is to test shared identity, not to copy the value into plain state.

## Pitfalls

- Do not copy a shared value into a plain value and expect persistence or observation.
- Do not let tests share app storage keys or file URLs.
- Do not make assertions before loading persisted shared values when the API requires load/initialization.
- Do not skip delegate visibility. If a child mutates shared state and tells the parent to dismiss, test the parent path.

## Tests

Reconstruct the feature after mutation when the product promise is persistence. The persisted value should survive reconstruction.
