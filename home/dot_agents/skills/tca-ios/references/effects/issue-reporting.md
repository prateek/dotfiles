# Applies to: TCA 1.25+, iOS 16+

# Issue Reporting

## Use When

Use this when handling non-fatal programmer errors, unexpected dependency failures, database failures, or fallback paths that should be visible during development.

## Guidance

- Use issue reporting for states that should not happen but can be recovered from.
- Use `withErrorReporting` around best-effort database or file work when the product can continue.
- Keep user-facing error state separate from developer diagnostics.
- Escalate truly unrecoverable conditions through normal Swift or platform failure mechanisms only when continuing would corrupt data.
- Prefer typed user-facing error state for expected failures, such as invalid credentials or no network.
- Use issue reporting to catch programmer mistakes, impossible reducer paths, missing dependency overrides, and fallback branches that should be rare.

## Example

```swift
case .deleteButtonTapped:
  guard let id = state.selection?.id else {
    reportIssue("Delete tapped with no selected item.")
    return .none
  }

  state.isDeleting = true
  return .run { [id, delete = itemsClient.delete] send in
    await send(.deleteResponse(Result { try await delete(id) }))
  }
```

For best-effort cleanup:

```swift
return .run { [removeTemporaryFiles = fileClient.removeTemporaryFiles] _ in
  await withErrorReporting {
    try await removeTemporaryFiles()
  }
}
```

## User Errors vs Issues

Expected failures should become domain state:

```swift
case let .deleteResponse(.failure(error)):
  state.isDeleting = false
  state.alert = AlertState { TextState(error.localizedDescription) }
  return .none
```

Unexpected but recoverable programmer paths should report an issue and choose a safe fallback:

```swift
case .destination(.presented(.edit(.delegate(.saved)))):
  guard state.destination != nil else {
    reportIssue("Received edit delegate while no edit destination was presented.")
    return .none
  }
  state.destination = nil
  return .none
```

Keep the two paths separate so diagnostics do not leak into user-facing copy.

## Pitfalls

- Do not swallow errors silently.
- Do not report expected user errors as programmer issues.
- Do not put issue reporting in tight loops or high-frequency reducer paths.
- Do not replace reducer tests with issue reports. If state changes, test the state.
- Do not expose developer diagnostic strings directly in UI.
- Do not use issue reports for normal validation failures.
- Do not continue after an issue if continuing can corrupt persisted state.

## Tests

If an error path changes user-visible state, test the state. If it only reports an issue and continues, test the fallback behavior.
