---
status: active
doc_type: plan
owner: Prateek
created: 2026-10-05
updated: 2026-10-05
related:
  - ../adr/0044-tcc-onboarding.md
  - ../references/chezmoi-hook-lifecycle.md
  - ../references/chezmoi-architecture.md
  - ../runbooks/tcc-onboarding.md
status_detail: "Implemented in source with automated checks; opt-in. Attended E2E and mini/work audits remain pending."
---

# TCC onboarding during chezmoi apply

`chezmoi apply` should help the user grant the macOS permissions their apps
need. Store expected grants per app in one manifest. A small SwiftUI app reads
TCC state, opens the relevant System Settings pane, and offers the exact app
or helper executable as a draggable file.

The user makes each permission change in macOS. The tool reconciles the
declared expectations with recorded grants and explains unresolved entries.

## Agreed scope

- Read-only TCC inventory is the primary status source, including stored code
  requirement checks for stale grants.
- An enabled interactive apply asks in the terminal before opening the helper.
  The default answer is no. After yes, the helper checks recorded grants and
  shows a window only when attention is needed; apply does not wait for grants.
- Start the expected-grant inventory from audits of this Mac and the mini.
  The work Mac will follow later. Observations do not automatically become
  expectations, and denied grants are not requests to broaden access.
- `tcc_onboarding` is opt-in on every machine through the existing feature layers.
- Implement and run automated checks now. The user explicitly deferred attended
  end-to-end testing until they are available; native behavior remains unverified.

The [operator runbook](../runbooks/tcc-onboarding.md) owns current setup commands,
validation coverage, and audit status. [ADR 0044](../adr/0044-tcc-onboarding.md)
records the architecture.

## Evidence and simplification

| Source | Reuse | Boundary |
| --- | --- | --- |
| [GhostPepper permission UI][ghostpepper] | Drag the exact bundle URL using an AppKit drag source embedded in SwiftUI. | Its permission APIs check its own process. |
| [KeyPath drag controller][keypath-drag] | Open the specific privacy pane, keep the drag source visible, refresh status. | Its floating panel also handles its bundled engine executable. |
| [KeyPath permission oracle][keypath-oracle] | Read-only cross-process inventory with an inconclusive result. | Its own permission checks prefer APIs; its database interpretation should not be copied wholesale. |
| [WinMux doctor][winmux-doctor] | A useful runtime cross-check during validation. | It runs inside the app server; the CLI failed here because the server was not running. |
| [Apple DTS on TCC][apple-tcc] | Treat database access as version-dependent implementation detail. | Apple does not promise the database format or location as API. |

Keep the first version to one manifest, one Swift app, and one apply hook.
Defer per-app diagnostic adapters, a privileged service, a background watcher,
and a general permission-management framework. Use native SwiftUI/AppKit and
SQLite; no third-party onboarding library is needed for a file drag and a
Settings link.

The source review establishes implementation patterns, not a successful live
grant on this machine. KeyPath reports cases where Input Monitoring works
without a readable database row; that is upstream evidence, not a reproduced
result here. A TCC inventory reports recorded authorization, not proof that
every feature in the target app works.

## First functional slice and current blockers

The first slice is: install the helper in a disposable Mac VM, grant it Full
Disk Access through its own drag tile, read one target app's Accessibility
entry, drag that app into Settings, observe the changed entry, and repeat an
apply without another permission window.

The attended session must establish the following, in order. Implementation
and fixture validation may proceed now, as requested; they do not close these
native-validation items:

1. Establish the helper's own identity and launch context. It must read TCC
   when launched as an app, without inheriting the terminal's Full Disk Access.
   Verify both user and system database access on the tested macOS version.
2. Establish reliable observation of a real change. Identify the relevant
   schema and database for Accessibility; distinguish inaccessible data from
   an absent entry. Prove that refresh sees Settings changes.
3. Establish the grant flow. Verify the Settings link and actual file drop,
   including any administrator prompt, then observe the recorded grant.
4. Establish update behavior. An unchanged apply must preserve the app binary.
   Rebuild it with a source change and determine whether Full Disk Access
   survives; document reauthorization if it does not.
5. Exercise the implemented renderer and gated apply hook through the same
   flow, including Later and a second apply. Validate the other declared
   services individually before claiming their native grant flows work.

Keep disposable spike files in ignored scratch storage. Preserve the OS
version, app/signing identities, observations, and sanitized evidence with the
implementation handoff; exclude raw TCC databases and unrelated grant rows.

## Declaration and file ownership

Implemented ownership:

| Path | Responsibility |
| --- | --- |
| `home/.chezmoidata/tcc.toml` | Expected grants grouped by stable app key. |
| `home/dot_config/dotfiles/tcc.json.tmpl` | Render the manifest as JSON for Swift's `Decodable`. |
| `scripts/macos/tcc-onboarding/` | Swift source, app metadata, and focused native tests. |
| `scripts/macos/install-tcc-onboarding` | Build and install `~/Applications/Dotfiles Permissions.app`. |
| `home/.chezmoiscripts/run_after_80-tcc-onboarding.sh.tmpl` | Gated install and desktop reconciliation after app installation. |

Keep permission metadata out of native preference plists. One dedicated
catalogue fits the repo's structured-data convention without reviving the
retired `.chezmoidata/apps/*.toml` system.

Each app entry declares its display name, bundle identifier, and expected
permissions with a short user-facing reason. An optional explicit bundle path
disambiguates multiple installed copies. A helper subject names an executable
relative to its owning bundle; it is a distinct TCC client and drag target.
Keep service identifiers and action behavior in a small code-owned table.
The manifest contains data, never arbitrary shell commands.

Resolve installed bundles from their identity and verify the resolved bundle
ID. Ambiguous copies require selection or an explicit configured path; never
silently drag a different copy. A missing app is **Not installed** and does not
trigger onboarding or installation. The package catalogue continues to own
installation. List missing apps in the helper's full inventory.

An app's manifest expresses desired use, not every permission it could request.
For example, GhostPepper's optional Screen Recording feature should become an
expectation only if that feature is wanted. Do not infer requirements from
usage-description keys alone. Record source links beside initial entries.

## Status model and read-only TCC reader

Use SQLite's read-only open mode against the original databases. Bind query
parameters, bound lock waits, and take one snapshot per database per refresh.
Do not copy databases or modify their schema, journal settings, or contents.
Read only declared clients and the helper's bootstrap status.

Keep schema detection and service/database mapping inside the reader. Start
with the schema observed on the validation OS; unknown layouts yield a reasoned
**Needs review** result. Avoid speculative compatibility with legacy schemas.

| UI state | Meaning |
| --- | --- |
| Allowed in macOS | A supported record allows this permission for the resolved client. |
| Not allowed | A supported record denies the permission. |
| Needs reauthorization | An allow record's stored code requirement does not match the installed app or helper. |
| Needs review | No record, inaccessible database, unsupported value/schema, unverifiable identity, or conflicting evidence. |
| Not installed | The declared app or helper could not be resolved. |

Only an exact supported allow value counts as allowed. Do not copy KeyPath's
generic `value >= 2 || value == 1` rule: its shared interpretation of modern
`auth_value` and legacy `allowed` is too permissive for this inventory. Limited
or unfamiliar values remain unresolved until supported per service.

Match the client type as well as its bundle ID or executable path. Check an
allow record's `csreq` against the resolved app or helper using Security.framework:
decode the stored blob with `SecRequirementCreateWithData`, resolve the on-disk
code with `SecStaticCodeCreateWithPath`, and evaluate that stored requirement
with `SecStaticCodeCheckValidity`. These APIs are documented by Apple in
[requirement decoding][apple-requirement] and [static validation][apple-validation].

A definite requirement mismatch means **Needs reauthorization**: the recorded
grant belongs to a different code identity. A missing/malformed requirement,
invalid signature, unreadable code, or other validation error means **Needs
review**, with the reason retained. Evaluate the requirement rather than
comparing requirement blobs, app versions, or modification dates. A legitimate
update can continue to satisfy the original requirement. Do not choose the
most permissive row across conflicting records or databases.

For a stale record, guide the user to remove and re-add the exact current app
in the relevant Settings pane, where supported, and refresh after relaunching
the target. Validate that recovery per service in the VM. A matching on-disk
identity does not detect every stale running-process cache or policy override;
those still need restart guidance or a target-owned runtime check.

Report the evidence source and a concise reason in details. An absent row is
not proof of denial; a successful file drop is not proof of authorization.
Restart guidance may still be needed after the database changes. App-specific
runtime probes can be added later if a demonstrated problem justifies them.

## User flow

1. Resolve installed expectations first; reconciliation exits silently if there
   are none. If expectations remain and database access is blocked, show the
   helper's own Full Disk Access step. Open that pane and offer the installed
   helper bundle as a drag tile. Refresh after focus returns and provide a
   relaunch action if needed.
2. Group unresolved expectations by permission pane. Show each app's icon,
   resolved path, and reason for access. A compact floating panel keeps the
   drag tile accessible while Settings has focus.
3. Open the selected pane and let the user drag the exact bundle or executable
   into its list, then enable the entry. Offer **Reveal in Finder** as a fallback.
4. Refresh on activation and periodically while a permission step is visible.
   Coalesce refreshes; stop polling when the helper closes. Show all expected
   entries, including allowed ones, in a secondary inventory view.
5. Finish when all installed expectations are allowed, or let the user choose
   **Later**. Deferred entries are checked again on the next interactive apply;
   no persistent suppression or user-confirmed “grant” cache is needed in v1.

Drag support is a per-service capability established through live validation.
Begin with Accessibility, Input Monitoring, and Full Disk Access. Validate
Screen Recording separately before enabling its drag instruction. Microphone
and Camera use guidance to launch the target app and trigger its own request;
the helper cannot request those permissions on another app's behalf. Automation
and Files & Folders remain outside the first version's supported services.

If macOS refuses a change because of policy or privileges, retain the unresolved
state and explain the available manual step. The helper never automates Settings
toggles, writes TCC, resets permissions, or installs a management profile.

## Apply and app lifecycle

Use `run_after`, since permission drift can occur without a manifest edit.
Follow `run_install_scripts`, the macOS gate, and the resolved `tcc_onboarding`
flag. Gate the rendered JSON consistently in `.chezmoiignore`.

Build only when source or build inputs change, using the existing
[session-sync installer](../../scripts/agent-sessions/install-sync-app) as a
pattern for staged replacement and signature verification. Keep the rendered
manifest outside the bundle so inventory edits do not rebuild or re-sign it.
A stable bundle ID and path are necessary, but do not assume they preserve
grants across ad-hoc rebuilds. The first slice determines the supported update
and reauthorization procedure; stable certificate signing is a follow-up choice
if local rebuilds prove too disruptive.

For an interactive apply owned by the logged-in console user, ask
`Review macOS app permissions now? [y/N]` using the existing stdin/stdout TTY
convention. Prompt before scanning, even on a repeat apply; this keeps a hidden
GUI preflight or terminal-context permission probe out of the hook. On yes,
launch through LaunchServices with a reconcile argument and the manifest path.
The app reads
its own status and exits without a window when all installed expectations are
allowed. The hook returns after launch; it does not wait for human action.
Opening the app manually shows the inventory and permits refresh at any time.
Reuse an existing instance and refresh its manifest instead of creating duplicate
windows. If an update is needed while the helper is open, defer replacement and
reconciliation with a message to close it and rerun apply. Never wait indefinitely
or terminate an attended permission step.

SSH, CI, noninteractive, or non-console-user applies do not launch GUI or wait.
Print a command to open the installed app in the user's desktop session. They
must not present a terminal-context TCC read as the GUI helper's result.
Dry runs never build, launch, or access permission databases.

Before launching, run a synchronous validation-only mode sharing the app's
manifest decoder. This mode needs no GUI or TCC access. Malformed manifests and
build failures fail the enabled hook with an actionable error. Missing grants,
unreadable TCC, a failed GUI launch, and Later produce
guidance without failing the rest of apply. The helper reports schema problems
as unresolved status rather than silently marking the machine reconciled.

## Critical path and acceptance

The helper, renderer, gated hook, local audit baseline, and
[operator runbook](../runbooks/tcc-onboarding.md) are implemented. The remaining
critical path is attended native validation of the first slice and each
declared service, followed by the mini and work Mac audits. Keep this plan
active until the native evidence and audit coverage are recorded.

Validation must protect these observable guarantees:

- A fixture database distinguishes allow, deny, absent, inaccessible, unknown
  value/schema, conflicting rows, and mismatched code identity. User and system
  scope are exercised. Tests never access the host's TCC databases.
- Rendering preserves reasons and exact subjects, rejects malformed data, and
  respects machine/OS gates. Uninstalled entries do not open onboarding.
- Hook tests cover dry-run, headless operation, unchanged-build reuse, launch
  failure, and a repeat apply. Use the existing Bats and render-test seams in
  the [tests index](../../tests/README.md).
- Attended VM evidence demonstrates the actual drag, toggle, refresh, Later,
  and reopen flow for each supported service. It also covers a helper rebuild
  and any required restart. Record the tested macOS versions explicitly.
- A controlled signed test app demonstrates a grant whose stored requirement
  matches before an identity change and fails afterward. Missing or corrupt
  requirements stay unresolved. A new build that satisfies the same requirement
  remains allowed; version changes alone never trigger reauthorization.
- A clean second apply opens no permission window once expected grants are
  recorded. Changes or revocation become visible on a later apply.

Source checks and fixture tests cannot establish native Settings behavior.
Keep live validation in a disposable VM until a host apply is requested.
Acceptance requires that native lane; a compiling app alone is insufficient.

## Future follow-up: standalone tool and releases

Extract the native helper into its own repository after the initial onboarding
flow is validated. Keep the expected-grant catalogue and chezmoi integration in
dotfiles. As part of that extraction, publish versioned macOS releases for
Apple silicon and Intel, with artifact verification and an explicit signing
and update policy. Dotfiles should install a pinned release so target hosts
need no Swift or Xcode toolchain; local compilation remains a development path.

This distribution work is deferred. The current installer builds locally and
requires a compatible Swift toolchain and macOS SDK; enabling it on a host
without those tools currently fails the hook.

[ghostpepper]: https://github.com/matthartman/ghost-pepper/blob/5a5b53aadbc1c1f76968cd1c8a9aff690d076887/GhostPepper/PermissionChecker.swift
[keypath-drag]: https://github.com/malpern/KeyPath/blob/d5581754c143914727dca827f96439246138fcef/Sources/KeyPathInstallationWizard/UI/Helpers/DragToAuthorize/DragToAuthorizeController.swift
[keypath-oracle]: https://github.com/malpern/KeyPath/blob/d5581754c143914727dca827f96439246138fcef/Sources/KeyPathPermissions/PermissionOracle.swift
[winmux-doctor]: https://github.com/prateek/winmux/blob/73370c99ac9d6fde28e7d7d8863fd33351ff2506/Sources/AppBundle/command/impl/DoctorCommand.swift
[apple-tcc]: https://developer.apple.com/forums/thread/716916
[apple-requirement]: https://developer.apple.com/documentation/security/secrequirementcreatewithdata(_:_:_:)
[apple-validation]: https://developer.apple.com/documentation/security/secstaticcodecheckvalidity(_:_:_:)
