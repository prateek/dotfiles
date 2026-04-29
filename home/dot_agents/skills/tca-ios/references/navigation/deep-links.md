# Applies to: TCA 1.25+, iOS 16+

# Deep Links

## Use When

Use this when URLs, universal links, notifications, widgets, or shortcuts need to open a TCA route.

## Guidance

- Parse the external input at the app boundary into a typed route or action.
- Let reducers build navigation state from the route.
- Keep URL parsing testable and separate from SwiftUI view code.
- For stack links, set the full `StackState` needed to reach the screen.
- For modal links, set the appropriate `Destination.State`.

## Shape

```swift
enum AppRoute: Equatable {
  case result(Result.ID)
  case settings
}

case deepLinkOpened(.settings):
  state.destination = .settings(Settings.State())
  return .none

case deepLinkOpened(.result(let id)):
  state.path = StackState([
    .search(Search.State()),
    .result(ResultDetail.State(id: id)),
  ])
  return .none
```

## Pitfalls

- Do not scatter URL handling across views.
- Do not rely on a view appearing before route state is valid.
- Do not ignore auth/session gates. A deep link may need to be stored until sign-in completes.

## Tests

Test valid links, malformed links, and gated links. Assert the path or destination state produced by the route action.
