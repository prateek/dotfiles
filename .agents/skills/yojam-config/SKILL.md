---
name: yojam-config
description: Maintain Prateek's Yojam browser-router config under chezmoi using the deltas-only `modify_` + desired-fragment pattern. Use when editing the desired-mutations fragment at `home/.chezmoiassets/yojam-config.json`, debugging rules that disappear or stay disabled after `chezmoi apply` (the import-time security pass), bumping the schema `version` field on a Yojam upgrade, adding a new rule (which needs a stable UUID), or onboarding a new Mac. Do not use for installing the Yojam cask itself (that lives in the chezmoi-management skill → packages-and-secrets), for the broader OSS-browser-router research that lives under `docs/`, or for editing the live `~/Library/Application Support/Yojam/config.json` directly (always edit the fragment instead).
---

# Yojam Config

Yojam is the OSS browser router installed via the cask in
`home/.chezmoidata/packages.toml`. Its live config is one JSON file at
`~/Library/Application Support/Yojam/config.json` that Yojam watches and
re-imports on external writes.

We don't capture that file whole. Yojam fills every key from upstream
defaults via `decodeIfPresent`, so the file you write only needs to
contain your **mutations**. Two source files do that:

- **`home/.chezmoiassets/yojam-config.json`** — the desired
  fragment. Hand-authored, small, contains only the keys that differ
  from upstream defaults. Plain JSON (no Go template directives), so
  it lives under `.chezmoiassets/` and loads via `include` per
  the `chezmoi-management` skill → `references/app-config.md`.
- **`home/Library/Application Support/Yojam/modify_config.json.tmpl`**
  — the `modify_` stub. A `uv` Python script that reads live on stdin,
  merges the fragment over it, writes the result to stdout. Same
  pattern as `home/dot_codex/modify_private_config.toml.tmpl` and
  `home/dot_claude/modify_private_settings.json.tmpl`.

This skill covers the *config* side. Cask install lives in
the `chezmoi-management` skill → `references/packages-and-secrets.md`.

## Universal Rules

1. **The fragment is deltas-only.** Upstream `SettingsExport` decodes
   every key with `decodeIfPresent` plus a default, so anything you
   omit reverts to that default. Carry only what differs.
2. **The merge respects upstream identity.** `browsers` and
   `emailClients` merge by `bundleIdentifier` (stable across machines);
   `rules` merge by `id` (UUID). Top-level scalars: desired wins.
   Unmatched live entries (Yojam's auto-discovered browsers, learned
   domain churn) pass through untouched. Inside a matched entry the
   merge is `dict.update` — fields present in desired overwrite live,
   fields absent in desired are *preserved* on the live entry. The
   fragment cannot delete a key from live by omission, and cannot
   reset `enabled: false` back on without an explicit `"enabled":
   true`. See the Bisect workflow for the recovery flow.
3. **The import-time security pass silently disables some shapes.**
   Five triggers covering `bundleIdentifier`, `targetBundleId`,
   `customLaunchArgs`, `ruleCustomLaunchArgs`, and `regex` patterns
   — enumerated in the Bisect workflow below.
4. **Rule `id` must be stable.** Yojam's decoder requires `id` on
   every Rule, AND the merge keys off it: a fresh UUID per apply
   would append a duplicate rule each time. Mint with `uuidgen` once,
   then leave it.
5. **`chezmoi re-add` does NOT round-trip this file.** The source is
   a `modify_` script, not a captured JSON file. Capturing live with
   `re-add` would either error or replace the script with raw JSON.
   Edit the fragment by hand instead.

## Workflows

### Add or change a mutation

Edit `home/.chezmoiassets/yojam-config.json`, then:

```text
chezmoi diff "$HOME/Library/Application Support/Yojam/config.json"
chezmoi apply
```

The modify stub merges your fragment into whatever Yojam has written.
For a top-level scalar, just add the key. For a rule, mint a new UUID:

```text
uuidgen
```

Paste it as the rule's `id`. Set `targetBundleId` to the destination
app's reverse-DNS bundle ID; set `targetAppName` to its display name.
Yojam needs only `id` to decode a rule — every other field has a
sensible default (`enabled: true`, `priority: 100`, `matchType:
.domain`, etc.).

### Debug a setting you set in the GUI

Yojam writes the GUI change into the live `config.json`. The next
`chezmoi apply` runs the modify stub, which preserves your live change
**unless** the fragment overrides that exact field. If the change
should be portable, copy the relevant key(s) into the fragment. If
not, leave the fragment alone and the change stays local.

### Bisect a "missing rule"

If a rule visible in the source fragment is absent from the GUI
after `chezmoi apply`, the import-time security pass in
`SettingsStore.importJSON` dropped or disabled it. Five triggers, all
silent:

- **Browser/email entry with path-prefixed `bundleIdentifier`** (starts
  with `/`) → silently disabled.
- **Browser/email entry with non-null `customLaunchArgs`** → silently
  disabled.
- **Rule with path-prefixed `targetBundleId`** (starts with `/`) →
  silently disabled.
- **Rule with non-null `ruleCustomLaunchArgs`** → silently disabled.
- **Rule with `matchType == .regex` and a pattern that fails
  `RegexMatcher.isValid`** → dropped entirely.

Fix the offending field in the fragment, then `chezmoi apply`.

If the rule was already imported once, live carries `enabled: false`
plus the offending field, and the deltas-only merge cannot clear that
field by omission (Universal Rule #2). Either delete the rule in the
Yojam GUI before re-applying, or `jq del`-edit live; either way, add
`"enabled": true` to the fragment entry so the next merge flips live's
`enabled: false` back on.

### Onboarding a new Mac

1. `chezmoi apply` — installs the cask via brew-bundle, runs the
   modify stub. On a fresh Mac the stub runs against an empty stdin,
   so its output is the fragment re-serialized through `json.dumps`
   with 2-space indent.
2. Approve the macOS prompt to set Yojam as the default browser.
3. Yojam launches, imports the fragment, fills upstream defaults,
   auto-discovers browsers/email clients, mirrors state into the
   group container plist (see Schema Notes).
4. To opt a host out, add a host check in `home/.chezmoiignore`
   next to the existing cask-presence gate.

### Bump the schema version

`version` is a desired-wins scalar like any other. After a Yojam
upgrade, both ends must reach the new schema before the next
`chezmoi apply` — a stale fragment silently downgrades live, and an
unmigrated live with a bumped fragment writes the new version onto an
old-shape file (which can confuse Yojam's migrator). Safe order:

1. Read upstream `SettingsExport.init(from:)` for the new `version`
   literal and any new keys whose default differs from what you want.
2. Launch the upgraded Yojam so it migrates live to N+1 in place.
3. Bump the `version` literal in `home/.chezmoiassets/yojam-config.json`
   to N+1 (and pull in step 1's new keys).
4. `chezmoi apply` — both ends now at N+1, the merge is a no-op for
   `version`.

## Schema Notes

Source: `SettingsStore.{export,import}JSON`, `Rule.swift`, and
`BrowserEntry.swift` in upstream Yojam (github.com/fluffypony/yojam).
Required vs default fields:

- **Rule**: only `id` (UUID) is required. Every other field defaults
  (`enabled: true`, `priority: 100`, `matchType: .domain`, `pattern:
  ""`, `targetBundleId: ""`, `rewriteRules: []`, `isBuiltIn: false`).
- **BrowserEntry**: only `bundleIdentifier` is required. `id` defaults
  to a fresh `UUID()`, `enabled: true`, `source: .autoDetected`, etc.
- **Top-level scalars** with notable upstream defaults: `version: 5`,
  `iCloudSync: false`, `verticalThreshold: 8`, `periodicRescanInterval:
  1800`, `recentURLRetentionMinutes: 30`, `activationMode: always`,
  `defaultSelection: alwaysFirst`, `pickerLayout: auto`, `launchAtLogin:
  false`. Defaults belong out of the fragment — except `version: 5`,
  pinned to anchor the bump workflow.

Two state surfaces: `config.json` is the import/export interface
(chezmoi-managed); the per-Mac `~/Library/Group Containers/group.org.yojam.shared/Library/Preferences/group.org.yojam.shared.plist`
mirrors runtime state and is what Yojam falls back to when `config.json`
is missing — so deleting live and relaunching does NOT yield upstream
defaults, it yields the group plist's last state.

## Per-Machine Concerns

- `learnedDomainPreferences` accumulates per-Mac; keep out of fragment.
- Machine-scoped rules (`Rule.machineScopeIdentifiers: [String]?`):
  nil/empty fires on every Mac; non-empty fires only on those IDs.

## Validation

```text
chezmoi diff "$HOME/Library/Application Support/Yojam/config.json"
chezmoi verify
chezmoi apply --dry-run --verbose --exclude=scripts
```

The stub's `semantic_equal` short-circuit returns `current_text`
unchanged on a no-op merge, so chezmoi diff stays clean even if Yojam
reorders keys or shifts whitespace. After editing this skill, run the
parser/frontmatter check from the `chezmoi-management` skill →
`references/meta-skill-maintenance.md`.

## Related

- Cask install + profile gating: the `chezmoi-management` skill →
  `references/packages-and-secrets.md`.
- The `modify_` + deep-merge pattern in general: the `chezmoi-management` skill
  → `references/app-config.md`, plus
  `home/dot_codex/modify_private_config.toml.tmpl` and
  `home/dot_claude/modify_private_settings.json.tmpl` as JSON/TOML
  precedents.
