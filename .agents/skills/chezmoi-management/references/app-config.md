# App Config Mode

Capturing, editing, and templating macOS app preferences. Load when working under `home/.chezmoitemplates/<bundle-id>.plist.tmpl`, `home/.chezmoiassets/`, or wiring a new app through a `modify_` stub.

## Decision Tree: Where Does App Config Live?

```text
New app config request
│
├── Single file at a native path (e.g., ~/.config/kanata/kanata.kbd)?
│       Place at the native target path under home/.
│       Add to home/.chezmoiignore if app is opt-in for some hosts.
│       Two-way-sync GUI apps need a cask-presence gate and may have
│       format-specific gotchas — defer to a focused skill if one
│       exists (e.g., `$yojam-config` for Yojam's `config.json`).
│
├── Nested macOS preference plist (com.<vendor>.<app>)?
│       1. Capture current state to ${XDG_STATE_HOME:-~/.local/state}/dotfiles/captures/
│       2. Author home/.chezmoitemplates/com.<vendor>.<app>.plist.tmpl
│       3. Wire a 3-line modify_ stub at the target path
│       4. See `Plist Fragment Anatomy` below
│
├── Raw payload that must NOT be templated (e.g., a JSON config with literal {{ }})?
│       Place under home/.chezmoiassets/<name>
│       Load via `include` (NOT `includeTemplate`)
│
└── Setapp-installed app?
        STOP. Do not add chezmoi config until the repo has an install path
        for the app. Setapp-managed apps install after Setapp login.
```

## Plist Fragment Anatomy

A `modify_` stub at the target path under `home/Library/private_Preferences/` (the parent directory carries `private_` so chezmoi enforces 0700 mode on `~/Library/Preferences`). Each stub is a small bash shim that exec's the shared merge tool at `scripts/macos/plist-merge`.

Stub path:

```text
home/Library/private_Preferences/modify_private_<bundle-id>.plist.tmpl
```

Stub content (the contract: hardcode the bundle ID, embed the desired XML fragment as base64):

```text
#!/usr/bin/env bash
exec '{{ .chezmoi.sourceDir }}/../scripts/macos/plist-merge' \
  --bundle-id '<bundle-id>' \
  --desired-b64 '{{ includeTemplate "<bundle-id>.plist.tmpl" . | b64enc }}'
```

The `desired-b64` arg uses `includeTemplate ... | b64enc` because it needs to *pipe* the rendered fragment through `b64enc` — `template` is an action that returns nothing and cannot be piped, so the function form `includeTemplate` is required there.

Each per-app stub stays explicit (one source file per target) rather than being generated from a `range` over `.chezmoidata`. Explicit wins for `git log --follow`, grep, and `.chezmoiignore`-based per-app opt-outs; the duplication is 4 lines and changes only when adding/removing a managed app. Single-quoting the stub args is safe because bundle IDs are reverse-DNS (no quotes) and base64 padding is `=`-only; if you adapt this pattern to a value class that can contain quotes, switch to a heredoc or escape explicitly.

The fragment itself is plain plist XML at `home/.chezmoitemplates/<bundle-id>.plist.tmpl`. Chezmoi renders the stub as a bash script; bash exec's the merge tool. The tool:
1. Reads the existing destination plist from stdin (chezmoi `modify_` contract).
2. Decodes `--desired-b64` and parses it as the desired key set.
3. Applies any `<!-- chezmoi-delete: key1, key2 -->` directives found in the rendered XML (see "Deleting Keys" below).
4. Merges desired keys into current, skipping byte-identical values to avoid spurious rewrites.
5. Writes the binary plist to stdout.

Apply-time hooks at `scripts/chezmoi-hooks/guard-running-apps.sh` and `scripts/chezmoi-hooks/post-apply-plists.sh` guard against modifying running apps and nudge `cfprefsd` to pick up changes.

## Deleting Keys

To remove a key from the destination plist that the app has written but you do not want, add a `chezmoi-delete` comment at the top of the fragment:

```xml
<!-- chezmoi-delete: BadKey, AnotherKey -->
```

The merge engine parses these directives before parsing the rest as plist XML and removes the listed keys during merge.

## Plist Fragment Templating

The `.plist.tmpl` fragment is rendered through `includeTemplate` inside the stub before being base64-decoded by the postlude, so anything that looks like a Go template directive will be evaluated. **Escape literal `{{` and `}}` in plist string values.** Real example: Moom geometry strings are literal `{{width}}x{{height}}+0+0` and must be escaped, otherwise the template engine tries to resolve `width` as a variable.

Two patterns work:

```text
<string>{{ "{{" }}width{{ "}}" }}x{{ "{{" }}height{{ "}}" }}+0+0</string>
```

or with a backtick literal:

```text
<string>{{ `{{width}}x{{height}}+0+0` }}</string>
```

Prefer the backtick form for whole-string literals; it is more readable.

## Templates vs Assets

| Directory | Loaded via | Templated? | Use for |
|---|---|---|---|
| `home/.chezmoitemplates/` | `{{ template "name" . }}` or `includeTemplate` | yes (Go template) | plist fragments, brewfile.tmpl, anything needing data |
| `home/.chezmoiassets/` | `{{ include "name" }}` | no (raw bytes) | JSON/YAML configs with literal `{{` `}}` content; large binary blobs |

Mixing them up is a common bug. If you `includeTemplate` an asset, the engine evaluates `{{ }}` inside it. If you `include` a template, the engine emits raw template directives into the destination.

**Path semantics for `include`:** `include` resolves paths relative to the chezmoi source directory, NOT relative to `.chezmoitemplates/`. Bare names like `{{ include "voiceink-prompts.json" }}` will not find files nested under `.chezmoitemplates/`. Use one of these forms:

```text
{{ include ".chezmoiassets/path/to/file.json" }}
{{ include (printf "%s/.chezmoitemplates/voiceink-prompts.json" .chezmoi.sourceDir) }}
```

The repo's VoiceInk fragment uses the second form to pull a non-templated JSON payload from `home/.chezmoitemplates/voiceink-prompts.json` into the rendered XML.

## Opt-In Apps and `home/.chezmoiignore`

Apps that should not install on every host go in `home/.chezmoiignore` with a template guard:

```text
{{- if not (eq .chezmoi.hostname "prateek-mbp") }}
private_dot_config/SomeApp
{{- end }}
```

Do not render an empty placeholder config for an absent app. Either gate the whole tree via `.chezmoiignore` or omit it from source entirely.

## Capturing An App's Current State

Raw captures live under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/captures/`, not in the repo. Use `scripts/macos/` helpers if available, or:

```text
defaults read com.<vendor>.<app> > "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/captures/com.<vendor>.<app>.plist"
```

From the capture, hand-author the desired-state fragment under `home/.chezmoitemplates/`. Do not commit the raw capture.

## The `modify_` Pattern Extends Beyond Plists

The `modify_` mechanism works for any config where chezmoi owns some keys and the app/user owns others — it's not plist-only. Real examples in the repo:

- `home/dot_codex/modify_private_config.toml.tmpl` — TOML modify_ stub.
- `home/.chezmoitemplates/codex-config-managed.toml.tmpl` — fragment of chezmoi-owned defaults.
- `home/dot_claude/modify_private_settings.json.tmpl` — JSON modify_ stub merging two fragments (generated plugin fragment + hand-maintained `claude-settings-managed.json.tmpl`; the managed fragment merges last and wins).

**Important: non-plist modify_ stubs (TOML, JSON) do NOT use the plist bash-shim pattern.** They are standalone Python scripts (`#!/usr/bin/env -S uv run --quiet --script` with their own PEP 723 metadata and imports) that:

1. Pull the chezmoi-owned fragment via `desired_text = base64.b64decode("{{ includeTemplate "codex-config-managed.toml.tmpl" . | b64enc }}").decode()` — only the fragment line uses `includeTemplate`.
2. Read stdin (current `~/.codex/config.toml`).
3. Implement their own merge logic — typically a `managed_tables` allowlist plus per-key/per-table overlay that preserves any unmanaged sections (for Codex: trust, hook approval, NUX, marketplace state).
4. Write the merged TOML to stdout.

Use the `chezmoi-delete`-style directive only inside plist fragments; for TOML/JSON the merge logic is inlined in the stub script itself.

When you need a similar pattern for a new format (YAML, INI, etc.), copy the standalone-Python-script shape from the Codex (TOML) or Claude (JSON) stub. (The plist case is special: 11 stubs share the same merge logic, so they delegate to a single `scripts/macos/plist-merge` tool via a bash shim. For one-off formats, an inline modify_ script keeps things simpler.)

## Retired Mechanisms (Do Not Reintroduce)

- **`home/.chezmoidata/apps/*.toml`** — retired with `bin/dotfiles`. App config now lives at the native target path (simple files) or as a `modify_` stub (nested plists or TOML). If you see references to this in old commits, do not revive the pattern.
- **`scripts/macos/apply.sh` + `scripts/macos/render-chrome-policy.py`** — the privileged Chrome managed-policy install path was removed. Chrome profile state belongs in Chrome Sync or extension-native export. Do not reintroduce a `DOTFILES_APPLY_PRIVILEGED_APP_ASSETS` gate or template the policy plist.

## Chrome / Browser Extensions

Chrome extension settings are NOT snapshotted from user profiles. Use Chrome Sync or extension-native export. Do not template `~/Library/Application Support/Google/Chrome/...` files. The previous privileged managed-policy installer was removed; do not bring it back.

## Validation

```text
make test-plist-hooks                                                # plist modify_ stubs round-trip
make test-codex-config                                               # non-plist modify_ pattern (Codex TOML)
make test-claude-settings                                            # non-plist modify_ pattern (Claude JSON)
make test-macos-defaults-script                                      # 30-macos-defaults side-effect guards
chezmoi diff <target>
chezmoi execute-template < home/.chezmoitemplates/com.<vendor>.<app>.plist.tmpl
```

The `execute-template` smoke catches template syntax errors before `chezmoi apply` runs the merge. Use `test-codex-config` when you touch the codex-config-managed template; use `test-claude-settings` when you touch claude-settings-managed or the Claude modify_ stub; use `test-macos-defaults-script` when you touch `home/.chezmoitemplates/macos-defaults.sh.tmpl`.

## Common Pitfalls

- **Forgetting to escape literal `{{` in a plist string value.** Template engine fails or silently drops content.
- **Using `includeTemplate` for an asset that contains literal template syntax.** Fix by moving to `home/.chezmoiassets/` and switching to `include`.
- **Committing raw captures.** They belong under `${XDG_STATE_HOME}/dotfiles/captures/`, not in the repo.
