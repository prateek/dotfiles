# Applies to: TCA 1.25+, iOS 16+

# ReducerProtocol to @Reducer

## Use When

Use this when migrating `ReducerProtocol` features to modern macro reducers.

## Steps

1. Change `struct Feature: ReducerProtocol` to `@Reducer struct Feature`.
2. Keep nested `State` and `Action`.
3. Prefer `@ObservableState` on `State` if moving to observation-era views.
4. Keep `var body: some ReducerOf<Self>` and `Reduce`.
5. Remove explicit protocol-associated type workarounds no longer needed.
6. Update tests only where type names or observation changes require it.

## Pitfalls

- Do not rewrite reducer behavior while changing syntax.
- Do not migrate surrounding views unless the recipe includes the view migration.
- Do not rename the feature type to include `Reducer`.

## Tests

Run the existing reducer test target before and after. Behavior should stay identical.
