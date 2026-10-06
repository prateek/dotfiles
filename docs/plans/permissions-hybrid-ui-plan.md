---
status: active
doc_type: plan
owner: Prateek
created: 2026-10-05
updated: 2026-10-06
related:
  - permissions-ui-prototype-brief.md
  - tcc-onboarding-plan.md
  - ../research/macos-permission-utility-design.md
status_detail: "Hybrid layout approved and implemented in the production app; attended Settings and accessibility validation remain."
---

# A warm workbench, organized around the Settings destination

Combine Astra's warm paper card, rust identity rail, recognizable app objects,
and spacious typography with Fable's explicit queue, state labels, next step,
and file-to-destination handoff. The question is whether grouping by permission
makes reconciliation easier than grouping by app while retaining a clear reason
for every grant.

## Interaction plan

Default to **by permission**: Accessibility, Input Monitoring, Full Disk Access,
Screen Recording, and Microphone. Each section names one Settings destination
and lists every relevant app with its status. One row expands in place into the
warm task card; other rows remain visible. Hide the visible window title and use a compact header without a permanent
status strip or prominent pending count. App identity and
the active permission carry the hierarchy; section counts stay secondary. No sidebar or separate companion.
Keep **by app** available for people configuring a single app. A third prototype
variant puts all eligible app-file chips together in a **drag shelf** for each
permission, so users can compare a batch workflow against the focused queue.

Open a Settings pane once, act on the apps in that section, then recheck the
section's evidence and move on. Reuse an already-open destination rather than
opening it for every app. Next follows the displayed queue, keeping the user
in the same permission until its remaining tasks are addressed or deferred.
A matching row stays selected until the user advances. Switching grouping
preserves task identity and evidence. Grouping changes navigation, never the
meaning or necessity of a grant.

The actual number of pane switches should fall from one per task to one per
needed permission category. Each grant and stale-entry repair still requires
its own macOS action. App-owned requests may require opening each app; there
is no universal drag workflow or bulk authorization.

## Stale-grant evidence

An allow row is insufficient by itself. Resolve the exact installed subject,
validate its code integrity, and evaluate the TCC row's stored code requirement
against that copy. Only a confirmed requirement mismatch is **Identity changed**.
Missing or malformed requirements, unreadable records, damaged signatures,
ambiguous installations, and unexpected Security framework failures are
**Cannot check**, with the specific reason available in evidence.

Refresh inventory and create a fresh requirement-check cache on each recheck,
so replacing an app at the same path is observed. The current production
inventory's default checker is created per inventory call; preserve that
lifetime when integrating the UI. Do not infer staleness from a version change
or an absent allow record. A matching allow record remains **Recorded allow**,
not proof that the app's live feature works.

For a confirmed mismatch, explain which entry needs review. For panes that
support adding files, guide removal of the old entry, addition of the resolved
current copy, enabling it, and relaunch if necessary. For app-request services,
remove only when Settings permits and use the app's feature to request access
again. Never reset TCC or delete records programmatically.

## Native file handoff

Retain the native AppKit dragging source with `NSURL` pasteboard payload,
copy operation, recognizable file icon, exact bundle/helper path, and visible
named destination. Accessibility, Input Monitoring, and Full Disk Access can
show file chips according to service policy. Microphone and Screen Recording
use app-request guidance instead of promising file-drop support.

Allow pinning this same window beside Settings. Include File Details, Copy
Path, and Show in Finder; explain the add button and Command-Shift-G alternative
where available. A drag or Settings launch never changes observed status.
Only a subsequent read establishes new evidence.

## Prototype and comparison

Run `build/design-prototypes/hybrid/run.sh`. The native window's header Presentation menu switches **By permission**, **By app**, and **Drag shelf**. View shortcuts Command-1/2/3 select these layouts. The Demo menu
switches missing/denied, matching, stale, unreadable, not-installed, and complete
scenarios. Settings is a same-window simulation; native file drags use disposable
fixture bundles. State stays in memory. No live TCC reads, real permission
requests, or chezmoi apply are performed by this prototype.

The native format retains the original prototypes' macOS behavior; the skill's
browser-route variant switch is adapted to native Presentation and View menus. A local HTML contact sheet provides screenshots, not a second app.
Following Astra's adversarial review, completion requires matching records for
all installed subjects. Deferral produces a paused review, and the last matched
task stays visible until Summary is chosen. Request-owned services include an
explicit simulated approval path; recheck remains necessary. Window close
preserves session state, menu bar presence is optional, queue arrow navigation
is scoped to queue focus, and larger text reflows at the minimum window width.
The drag shelf has a keyboard-accessible details control per file and replaces
the active card's duplicate handoff. Damaged-signature and ambiguous-install
scenarios demonstrate uncertainty independently of stale requirements.

The user approved the hybrid layout and then requested a lighter utility-panel
presentation. Production now uses a transparent hidden title bar and puts
More alone in the header, manual Recheck inside its menu (⌘R), contextual navigation in the active card,
and the timestamp in Evidence. Keep the experiments ignored; capture the
selected prototype on a throwaway branch with a PR pointer after feedback
settles the question, before production adoption.

## Production adoption and acceptance

1. Choose focused permission groups versus the drag shelf using the playable
   prototype. Confirm that users can identify all needed apps without opening
   each task, and that the active task's purpose and action remain obvious.
2. Move the selected layout into the existing app, retaining the read-only
   inventory, service-specific actions, stable selection, CLI-first apply auditing,
   and toolchain fallback. Use current core semantics rather than copying
   fixture classifiers into production.
3. Validate rechecks after actual app replacement, code requirement mismatch,
   unverifiable evidence, and external Settings changes. Add production coverage
   for queue order and stable selection through the established public seam;
   no new tests are needed for this disposable prototype.
4. During attended E2E, verify real pane navigation, cross-app dragging of the
   exact resolved subject, keyboard alternatives, stale repair, bootstrap,
   relaunch guidance, and CLI-first chezmoi behavior. Audit this Mac first, then
   the mini and eventually the work Mac within the previously agreed scope.
5. Review keyboard focus, VoiceOver, text scaling, light/dark, Increase Contrast,
   Reduce Transparency, and Reduce Motion on the actual app. Source-linked HIG
   review guides this work; screenshots alone do not prove compliance.

The utility split, downloadable releases for hosts without a Swift toolchain,
independently versioned per-app registry updates without rebuilding, publishing
CI/CD, and launch/marketing work remain followups in the
[product plan](permissions-product-plan.md).

Design sources: [Apple designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos),
[drag and drop](https://developer.apple.com/design/human-interface-guidelines/drag-and-drop),
and the [prior research](../research/macos-permission-utility-design.md).

## Implementation evidence

The production app now uses the hybrid warm card, permission-first queue,
alternate app grouping and drag shelf, scoped keyboard navigation, exact-URL
file handoff, optional pin/menu bar, retained matching selection, and session
deferral. The core distinguishes absent decisions from unverifiable evidence,
checks signature integrity across universal-binary architectures before calling
a stored requirement stale, and creates fresh evidence on recheck.

`just test-tcc-onboarding` passes 34 native tests. The two focused hook/installer
Bats files pass 17 cases, including missing-toolchain recovery. A native
LaunchServices smoke check also verified file-open delivery, encoded reconcile
URLs, quiet exit for an empty cold inventory, and retention of the running
process and window on repeated reconciliation. These checks use fixtures and
disposable signed code; real Settings acceptance, application
requests, VoiceOver, and host grant reconciliation remain attended work in the
[runbook](../runbooks/tcc-onboarding.md).
