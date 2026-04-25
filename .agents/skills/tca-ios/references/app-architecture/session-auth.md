# Applies to: TCA 1.25+, iOS 16+

# Session and Auth

## Use When

Use this for login, logout, onboarding, token refresh, account switching, and gated deep links.

## Guidance

- Model session as root state: logged out, onboarding, logged in, locked, or restoring.
- Store deferred deep links while auth is unresolved.
- Keep auth clients behind dependencies.
- Let child features delegate auth-required events upward instead of importing auth internals.
- Clear sensitive state on logout.
- Keep tokens out of ordinary reducer state when they do not need to drive UI. Store them in a dependency-managed secure store.
- Model refresh, expiry, and account switching as actions at the root or session feature.
- Cancel session-scoped effects on logout.
- Rebuild signed-in child state from a session value rather than mutating many optional fields.

## State Shape

```swift
@ObservableState
struct State: Equatable {
  var route: Route = .restoring
  var deferredDeepLink: DeepLink?

  enum Route: Equatable {
    case restoring
    case signedOut(AuthFeature.State)
    case onboarding(OnboardingFeature.State)
    case signedIn(SignedInFeature.State)
    case locked(LockFeature.State)
  }
}
```

Use a struct around the route when root-level values, such as deferred deep links or global alerts, need to survive route changes.

## Action Shape

```swift
enum Action {
  case task
  case auth(AuthFeature.Action)
  case onboarding(OnboardingFeature.Action)
  case signedIn(SignedInFeature.Action)
  case lock(LockFeature.Action)
  case sessionResponse(Result<Session?, Error>)
  case tokenRefreshResponse(Result<Session, Error>)
  case deepLinkReceived(DeepLink)
}
```

Child features should report session concerns with delegate actions:

```swift
enum Delegate {
  case requiresSignIn(DeepLink?)
  case loggedOut
}
```

## Flow

1. App starts in `.restoring`.
2. Root loads secure session state through a dependency.
3. Missing session routes to `.signedOut`.
4. Valid session routes to `.signedIn`.
5. Expired session either refreshes through a dependency or routes to `.signedOut`.
6. Deep links received during restore are stored and replayed after sign-in.

## Pitfalls

- Do not let leaf features decide global auth navigation.
- Do not keep token refresh hidden in views.
- Do not represent auth with one boolean when the app has restoring, expired, onboarding, and logged-in cases.
- Do not keep signed-in feature state alive after logout unless the product explicitly supports account switching with cached state.
- Do not let failed refresh loops dispatch unbounded actions. Use cancellation and backoff.

## Tests

Test restore success/failure, login success/failure, logout cleanup, token refresh failure, cancellation of session-scoped effects, account switching, and deferred route replay after sign-in.
