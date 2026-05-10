# Applies to: TCA 1.25+, iOS 16+

# Modernization Review

## Use When

Use this in review mode to assess API consistency without editing code.

## Inspect

- Installed TCA version.
- Use of `@Reducer`, `@ObservableState`, `StoreOf`, `@Dependency`, `Effect.run`, `TestStore`.
- Legacy Environment structs.
- `ReducerProtocol`, `Reducer.combine`, `WithViewStore`, helper store views.
- Combine-heavy effects and schedulers.
- Navigation/presentation API generation.
- Deprecated APIs relative to the installed version.

## Guidance

Do not blindly recommend modernization. First judge whether the current style is internally consistent and appropriate for the installed version.

## Output

Rank migration opportunities:

- should do now
- should do opportunistically
- not worth changing

Include compatibility concerns and a suggested sequence if migration is warranted.
