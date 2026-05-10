# Applies to: TCA 1.25+, iOS 16+

# UIKit Navigation

## Use When

Use this for UIKit screens, hybrid SwiftUI/UIKit apps, or TCA 1.13+ UIKit presentation.

## Guidance

- Use `observe { ... }` in view controllers to update UI from observed store state.
- Use `@UIBindable` when UIKit navigation APIs need bindings to store scopes.
- Use `present(item:)` for optional presentation.
- Use `NavigationStackController` for stack navigation.
- Keep reducer domains the same as SwiftUI domains; the UI layer changes, not the architecture.

## Pitfalls

- Do not manually subscribe to broad store state if `observe` can track the exact fields.
- Do not mutate UIKit controls from background effects.
- Do not keep navigation state only in UIKit coordinator objects when product logic depends on it.

## Tests

Reducer tests stay the same. Add UIKit integration tests only for controller wiring that has broken before or cannot be proven through reducer state.
