# Authoring workflow YAMLs

Workflow YAMLs describe scripted end-to-end user journeys for the UX
pillar. They run against a booted simulator and capture screenshots +
accessibility trees at every step.

Workflow YAMLs live in the **project**, not in this skill. Put them at
`<repo>/.audit/workflows.yaml` (or `.audit/flows/*.yaml` if you want to
split per-feature).

## Minimal example

```yaml
app:
  bundle_id: com.example.myapp
  name: MyApp

simulator:
  device: "iPhone 16 Pro"  # optional; defaults to booted

workflows:
  - name: Sign In
    description: User signs in and lands on home
    tags: [critical, auth]
    steps:
      - action: launch
      - action: wait
        duration: 3
      - action: screenshot
        name: signin_screen
      - action: tap
        target: { text: "Email" }
      - action: type
        value: "${MYAPP_TEST_USERNAME}"
      - action: tap
        target: { text: "Password" }
      - action: type
        value: "${MYAPP_TEST_PASSWORD}"
      - action: tap
        target: { text: "Sign In" }
      - action: wait
        duration: 4
      - action: screenshot
        name: home_after_signin
```

## Credentials

Always use env-var interpolation. The collector expands `${NAME}` and
`$NAME` at runtime. Missing vars raise a clear error before the flow
starts.

```yaml
app:
  credentials:
    username: "${MYAPP_TEST_USERNAME}"
    password: "${MYAPP_TEST_PASSWORD}"
```

Pass credentials to the audit run via your shell:

```bash
export MYAPP_TEST_USERNAME="..."
export MYAPP_TEST_PASSWORD="..."
~/.agents/skills/ios-audit/scripts/audit.py collect --workflows .audit/workflows.yaml ...
```

For Xcode UI tests that run alongside the audit, use the Xcode 15.3+
`TEST_RUNNER_` prefix pattern:

```bash
TEST_RUNNER_MYAPP_TEST_USERNAME="$MYAPP_TEST_USERNAME" \
TEST_RUNNER_MYAPP_TEST_PASSWORD="$MYAPP_TEST_PASSWORD" \
xcodebuild test -workspace MyApp.xcworkspace -scheme MyApp ...
```

## Actions reference

See `workflow-schema.yaml` for the authoritative schema, or
`examples/movies-do.yaml` for a full working example with 10 flows.

| Action | Required | Description |
|---|---|---|
| `launch` | — | Cold-launch the app (uses `app.bundle_id`) |
| `terminate` | — | Kill the app |
| `tap` | `target` | Tap by text, id, type, or coordinates |
| `type` | `value` | Type text into the focused field |
| `swipe` | `direction` | up/down/left/right |
| `scroll` | `direction`, `amount` | Scroll with repeat count |
| `wait` | `duration` | Wait N seconds (decimal OK) |
| `screenshot` | `name` | Explicit screenshot with custom suffix |
| `back` | — | Swipe right from left edge |
| `reset_keychain` | — | Reset the simulator keychain to clear persisted auth/session state |

## Target selectors

```yaml
target: { text: "Sign In" }           # Visible text (fuzzy)
target: { id: "signInButton" }        # Accessibility identifier (preferred)
target: { type: "TextField" }         # Element type
target: { coordinates: [200, 400] }   # Point coordinates (last resort)
```

**Prefer `id` selectors** — they survive layout changes. Fall back to
`text` for elements that don't have accessibility identifiers yet. Only
use `coordinates` when nothing else works; they break on the smallest
layout tweak.

## Preconditions

Use `precondition: <workflow-name>` to mark that a flow depends on the
state left by another flow. The executor runs preconditions first.

```yaml
workflows:
  - name: Sign In
    steps: [...]

  - name: Home Hero Tap
    precondition: Sign In
    steps: [...]
```

## Tags

Tag workflows for filtering:

```yaml
tags: [critical, auth, regression]
```

Filter runs with `--workflow NAME` (single-flow) or run all.

## Tips

- **Pin the simulator device** if screenshots need to be byte-stable.
- **Leave settle time** after taps: `wait: 0.5` or `wait: 1` is usually
  enough for animated transitions.
- **Capture explicit screenshots** at key states with `action: screenshot`
  — implicit per-step screenshots are useful but noisy for docs.
- **Keep flows under 30 steps** — longer flows are hard to debug and
  brittle.
- **Run one flow in isolation first** with `--workflow NAME` to debug,
  then run the full suite.
