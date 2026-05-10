# Applies to: TCA 1.25+, iOS 16+

# Snapshot Testing

## Use When

Use this for visual regressions, rendered SwiftUI/UIKit output, generated text, or serialized artifacts.

## Guidance

- Use snapshots to cover presentation output that structural reducer tests cannot see.
- Keep reducer behavior in TestStore tests.
- Make snapshots deterministic: fixed data, fixed locale, fixed size, fixed traits.
- Prefer inline snapshots for small text outputs when the codebase uses them.
- Review record-mode changes carefully.
- Snapshot after state is prepared. Do not use a snapshot as a substitute for sending reducer actions in TestStore.
- Keep one snapshot assertion focused on one rendered contract.

## Example

```swift
let view = SearchView(
  store: Store(
    initialState: Search.State(
      query: "swift",
      results: [.fixture]
    )
  ) {
    Search()
  } withDependencies: {
    $0.searchClient.search = { @Sendable _ in [.fixture] }
  }
)

assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
```

Use the local snapshot library and naming conventions. Fix the device, locale, color scheme, dynamic type size, and data.

## State Setup

Prepare state directly when the snapshot only covers rendering:

```swift
let state = Search.State(
  query: "swift",
  results: [
    SearchResult(id: "swift", title: "Swift")
  ]
)
```

Use a TestStore before the snapshot when the rendered state is produced by non-trivial reducer behavior. That gives one test for behavior and one snapshot for presentation.

## Recording

Record mode is a local workflow, not a committed setting. After recording:

1. Open the rendered artifact.
2. Check that dynamic data is fixed.
3. Turn record mode off.
4. Re-run the snapshot test.

Do not accept a recorded diff that contains unrelated layout churn.

## Pitfalls

- Do not snapshot live dates, random IDs, remote images, or network results.
- Do not use snapshot tests as the only coverage for reducer logic.
- Do not leave record mode enabled in committed code.
- Do not accept snapshot churn without opening the rendered output.
- Do not snapshot loading spinners or animations unless the strategy freezes them.
- Do not snapshot remote images unless the image loader is overridden with deterministic data.
- Do not mix several screens into one snapshot if separate failures would be easier to diagnose.

## Tests

Pair one reducer test for behavior with one snapshot test for UI output when both can regress independently.
