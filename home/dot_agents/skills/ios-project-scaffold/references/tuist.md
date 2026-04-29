# Tuist patterns for this skill

Every project scaffolded by `ios-project-scaffold` uses Tuist. Read this file when you need more detail than the templates encode — for example, when adding a second module, wiring SPM dependencies, or debugging a `tuist generate` failure.

## Core rules

- `tuist generate` always runs with `--no-open` (or `TUIST_GENERATE_OPEN=0` in the environment). Never let it launch Xcode.
- `Project.swift` is the source of truth. Never hand-edit the generated `.xcworkspace`, `.xcodeproj`, or anything under `xcshareddata/`.
- Everything under `xcshareddata/xcschemes/` and the entire `.xcworkspace` / `.xcodeproj` tree is gitignored. Tuist regenerates them on demand.
- Commit `.tuist-version`. Tuist reads it and refuses to run with a different version.

## Test environment variables

Test-action env vars belong on the `Scheme.testAction.targets(arguments: Arguments(environmentVariables:))` path, defined in `Project.swift`. They survive `tuist generate` because the manifest is regenerated from source each time.

Verified against Tuist 4.61.2, the shape is:

```swift
.scheme(
    name: "MyApp",
    shared: true,
    buildAction: .buildAction(targets: ["MyApp"]),
    testAction: .targets(
        ["MyAppTests"],
        arguments: .arguments(environmentVariables: [
            "MY_APP_TEST_USERNAME": "$(MY_APP_TEST_USERNAME)",
            "MY_APP_TEST_PASSWORD": "$(MY_APP_TEST_PASSWORD)",
        ])
    ),
    runAction: .runAction(executable: "MyApp")
)
```

Tuist expands `$(VAR)` against the shell environment at generate time. Commit the key, never the value. Set the values in `.env.test` sourced by the Makefile target that runs tests, or as CI secrets.

Run-action env vars (app launches, not tests) use the same shape on `runAction.arguments`:

```swift
runAction: .runAction(
    executable: "MyApp",
    arguments: .arguments(environmentVariables: [
        "MY_APP_API_BASE_URL": "$(MY_APP_API_BASE_URL)",
    ])
)
```

## SPM dependencies and Package.resolved

Tuist consumes Swift packages through `Project.swift` / `Package.swift`. Two rules:

1. **Commit `Package.resolved`.** Without it, every clone re-resolves and drifts; CI can pull a different version than local.
2. **Use `tuist install` explicitly** (not `tuist fetch`, which is deprecated) when you want to refresh package resolution without a full regenerate. `tuist generate` calls resolution internally, so the explicit path is mostly useful when diagnosing a stuck cache.

Clear a stuck resolution with:

```bash
rm -rf .tuist/Dependencies Derived
tuist install
tuist generate --no-open
```

## Tuist Cloud binary caching

For any project that exceeds a minute of cold Swift compile, adopt Tuist Cloud's binary cache. It is the only real lever against Swift compile time short of reducing the Swift code itself.

Setup:

1. Sign up at https://tuist.dev (or whatever the current Tuist Cloud entry point is — the project renamed from "Cloud" to "Server" in 2024, check current docs).
2. Create a project in the Tuist dashboard; it gives you a project token.
3. Store the token in 1Password or the shell env as `TUIST_CONFIG_CLOUD_TOKEN` (exact name varies by Tuist version; check `tuist config --help` or the current docs).
4. Add the project binding to `Project.swift` via `Config.swift`:
   ```swift
   import ProjectDescription
   let config = Config(
       compatibleXcodeVersions: .list(["26.3"]),
       plugins: [],
       generationOptions: .options(
           enforceExplicitDependencies: true
       )
   )
   ```
5. Warm the cache: `tuist cache warm`. This builds every framework target and uploads the binaries.
6. On subsequent `tuist generate` runs, Tuist downloads the cached binaries instead of compiling.

CI: set the same env var as a repo secret and run `tuist cache warm` as a scheduled job (nightly) to keep the cache ahead of commits.

Expected win: the audit report documented cold-compile times of 3–6 minutes on real projects. Tuist Cloud caching typically brings that under a minute for unchanged targets.

## Module boundaries and the `.target()` DSL

Prefer the explicit `.target(...)` helper over the bare `Target(...)` initializer. The helper has stable argument defaults and handles the `destinations`, `product`, `bundleId`, and `sources` argument order consistently across Tuist 4 point releases.

Split modules when either is true:

- A Swift compile unit exceeds 45 seconds.
- A UI feature has its own model tier, testable in isolation.

Do not split prematurely — single-module projects have a lower Tuist overhead than multi-module projects, and the Makefile skeleton assumes a single primary scheme.

## Debugging `tuist generate` failures

Common failures and their fixes:

- **"Couldn't locate the root directory"** — Tuist needs a `.git` directory or an existing Tuist project at the root. Run `git init` first.
- **"Unknown option '--no-open'"** — you're on Tuist 3.x; the scaffold requires Tuist 4. `mise install tuist@4.61.2` or similar.
- **Stale package resolution** — clear `.tuist/Dependencies` and `Derived` and re-run (see SPM section above).
- **Scheme missing after regenerate** — `Project.swift` doesn't declare an explicit `schemes:` array, so Tuist auto-generates one. Add an explicit `schemes:` block to pin the shape.
- **Env var keys in scheme files look wrong** — `$(VAR)` notation is required; plain `VAR` won't expand. Verify against the working example in `assets/templates/Project.swift.example`.

## When to regenerate

Run `make generate` (which calls `tuist generate --no-open`):

- After editing `Project.swift`.
- After adding, removing, or renaming source files outside the existing `sources: ["Sources/**"]` glob.
- After pulling changes that touched `Project.swift`, `Package.swift`, or `Package.resolved`.
- Before every `make build`, `make test`, or `make run` in the skeleton Makefile (they depend on `generate`).

Never run `tuist generate` in a loop or as a file-system watcher. Each run rewrites the entire `.xcodeproj` tree and is not cheap.
