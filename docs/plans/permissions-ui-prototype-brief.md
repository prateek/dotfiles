---
status: superseded
doc_type: plan
created: 2026-10-05
updated: 2026-10-05
related:
  - ../research/macos-permission-utility-design.md
  - tcc-onboarding-plan.md
  - ../adr/0046-tcc-onboarding.md
superseded_by: permissions-hybrid-ui-plan.md
closed: 2026-10-05
status_detail: "Comparative prototypes informed the approved hybrid production design."
---

# Permissions utility: comparative prototype brief

Build two independently designed, playable native macOS prototypes: Astra at medium reasoning and Fable. Each has write permission for its own ignored prototype directory. The purpose is to choose a visual philosophy and interaction hierarchy before changing the production helper.

## Product and user direction

This utility helps someone reconcile expected macOS privacy permissions after an opt-in terminal question during `chezmoi apply`. It explains which installed app needs attention, why, and where to grant access. It reads TCC records and checks installed code identity; users grant access in System Settings. A database record does not prove an app can currently exercise a permission.

The user wants a gorgeous, unmistakably Mac utility, with the compact character of excellent menu bar apps and an older delivery-tracking widget. The likely reference is Junecloud's [Delivery Status Dashboard widget](https://junecloud.com/software/dashboard/delivery-status.html?site=junecloud); this identification is tentative. Junecloud describes prominent delivery status and a countdown, and its successor offers menu bar access. Its [official widget image](https://junecloud.com/cache/images/images/entries/688x500/20200529_6613.jpg), visually inspected on 2026-10-05, is retained at `build/design-prototypes/references/delivery-status-widget.jpg`. It has edge-to-edge shipment bands, large left-side numerals or a state mark, strongly grouped row text, and a quiet utility footer. Translate this compact hierarchy into today's macOS, rather than reproducing obsolete Dashboard chrome or using color alone to communicate permission state.

Use a single app and one working surface, without a sidebar or a separate companion. A menu bar entry may reveal the same surface; the task must also be accessible when the extra is hidden. If opening Settings would dismiss the surface and make file dragging awkward, use an explicit pinned/detached presentation of that same surface, with native window behavior. Do not multiply the interface into simultaneous workspaces. The user asked for menu bar character; permanent menu bar residence is an experiment, not a settled product requirement.

## Design philosophy and hierarchy

Choose and name a coherent philosophy in your design notes. Express personality through composition, recognizable app objects, proportion, typography, considered color, and purposeful materials. Native controls support this philosophy but do not supply it automatically. A featureless settings form does not satisfy the brief.

The primary hierarchy is: app identity and the active permission; its concise state and purpose; the exact app/file object and next action. A small overall summary and queue remain visible at lower emphasis. Detailed code identity, provenance, and ambiguous evidence belong in disclosure. Establish one dominant action per active task. Select another app or permission in the same surface without a sidebar.

The research's strongest transferable references are Things' slim view and expanded task, Radio Silence's recognizable app list, AirBuddy's object/status/action card, Dropover and Yoink's tangible file shelf, CleanShot's explicit local actions, Anybox's compact transaction, and Mela's current-step hierarchy. Study their images in the board. Their toggles, elaborate workspaces, marketing layouts, and feature sets are not permission semantics.

Make your own design, independently of the other prototype. Deliver one thoroughly composed direction rather than a pile of lightly styled variants. Explain the typography scale, spacing rhythm, semantic color roles, surface hierarchy, and what deserves visual emphasis. Any illustration or ornament must explain identity, status, or the task.

## Playable behavior and fixture truth

Use native SwiftUI/AppKit. Build a standalone `.app` and a `run.sh` in your assigned directory. Deployment baseline is macOS 14; availability-gate newer APIs and use native fallbacks. Keep production source unchanged. You may read it for actual semantics and reuse its ideas in your isolated prototype.

Use curated synthetic fixtures, not live TCC reads, permission requests, registry mutations, host audits, or `chezmoi apply`. Include GhostPepper (four expectations), WinMux (two), and at least one app with protected-data access. Use recognizable installed app icons where safely available, with good local fallback assets.

The user must be able to select an app, select a permission, disclose evidence, see the correct Settings destination, interact with a file-drag affordance, recheck, defer a task, and inspect completion. A small Demo menu or similarly secondary control lets us switch among missing/denied, allowed-record with matching identity, stale/mismatched identity, unreadable database/bootstrap, app not installed, and completed states. Controls should change fixture state visibly rather than merely animate a button.

Clearly distinguish “record allows access,” “needs a grant,” “identity changed; review in Settings,” and “cannot check.” Do not render an uncertain or stale row as effective access. Avoid green success based on a user clicking Settings or dragging. Never offer a grant toggle, an automated Grant All, or pretend the helper can authorize another app.

In the prototype, “Open Settings” must reveal a useful simulated permission destination and instructions within the same surface, or record the intended deep link, without launching real Settings. Recheck uses deterministic fixture transitions and explicitly simulated feedback. For real native file dragging, use a disposable fixture `.app` made in your prototype directory; never encourage granting it actual permissions. Provide a keyboard-accessible alternative that reveals the exact file information. Document which behavior is simulated, which native mechanics work, and which remains untested.

## Apple guidance: implementation and review contract

Consult current primary Apple guidance, including its macOS platform sections. Local snapshots retrieved 2026-10-05 are in `build/design-prototypes/references/` (`.json` authoritative article payloads; `.txt` extracted text). If extracted emphasis is missing, inspect the article JSON. Relevant sources:

- [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos): desktop pointer, keyboard, menus, window conventions, and adaptable presentation.
- [The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar): discoverable commands, accessible template extra icon, and another path when extras are hidden.
- [Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers): focused related tasks, deliberate dismissal, preserved progress, appropriate sizing, and macOS detachment into a panel for work alongside another app.
- [Typography](https://developer.apple.com/design/human-interface-guidelines/typography): system type and platform-specific legibility. Use readable Mac sizes; do not transplant iOS touch or typography rules wholesale.
- [Color](https://developer.apple.com/design/human-interface-guidelines/color): semantic adaptive colors, meaningful accents, and state information conveyed through text and shape as well as color.
- [Materials](https://developer.apple.com/design/human-interface-guidelines/materials): distinct navigation/control and content layers. Gate current Liquid Glass APIs by OS availability; translucent surfaces must not reduce content legibility.
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility): useful VoiceOver labels/order, keyboard and visible focus, legible contrast, increased contrast, reduced transparency, and scalable text/layout.
- [Motion](https://developer.apple.com/design/human-interface-guidelines/motion): purposeful state transitions that respect Reduce Motion.
- [Drag and drop](https://developer.apple.com/design/human-interface-guidelines/drag-and-drop): recognizable source object, appropriate native file representation, accurate destination expectations, and an alternative to dragging.
- [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons): clear verb labels and visible hierarchy; secondary actions remain discoverable.

Use native controls and window/menu behavior where they help. Standard hover, press, focus, escape, dismissal, tooltips, keyboard shortcuts, and cursor behavior should agree with Mac conventions. Support light and dark appearances, keyboard navigation, Reduce Motion, Reduce Transparency, and Increase Contrast using system environment/accessibility settings. Keep essential explanatory text legible and avoid truncated permission names or opaque icon-only state.

Write a source-linked `HIG-REVIEW.md` mapping each applicable topic above to implementation and evidence. Mark checks as implemented, verified, or untested; call out departures with reasons. Do not claim “all Apple guidelines compliant”: a prototype review can cover applicable guidance, but VoiceOver and real Settings/drag behavior require separate validation.

## Inputs and deliverables

Read the [full study](../research/macos-permission-utility-design.md), production `scripts/macos/tcc-onboarding/Sources/PermissionsApp/`, and `home/.chezmoidata/tcc.toml`. The full-resolution board is `/Users/prateek/Documents/Mac_Utility_Design_Research_20261005/reference-board.html`, with source images under its `images/` folder. Open or inspect relevant images rather than relying on prose alone. Shared previews: [board](https://share.onorca.dev/a/IHAtPZVHSZtX), [report and PDF](https://share.onorca.dev/a/4wmzyt6kKCdr).

Place source, built `.app`, fixture files, `run.sh`, screenshots, `DESIGN.md`, and `HIG-REVIEW.md` in your assigned directory. Also produce a small self-contained `index.html` preview with captured screenshots and launch instructions; label it a preview, not a native interactive replacement. Keep the artifact reasonably small for the Orca CLI's 800 KiB envelope. The runnable native prototype is the primary deliverable.

Compile, launch only your own prototype, and exercise its selection, scenario changes, evidence disclosure, recheck, and completion. Capture at least the primary task, stale/unknown state, and dark appearance; use an app-owned snapshot mode if desktop automation is unavailable. Do not capture unrelated windows or change system accessibility preferences. Close only your own app after validation so both variants can be launched deliberately for comparison.

Completion requires buildable source, successful build and owned-app launch, a working scenario selector, a runnable script, visual evidence, design philosophy, and an honest HIG review. Report remaining runtime uncertainties and exact launch command. Prototype code stays isolated; adopting a direction into the production helper is a later decision.

## Delivered comparison

Both prototypes were built and launched on this Mac on 2026-10-05. They remain local, ignored experiments under `build/design-prototypes/`; the production helper is unchanged. The local `build/design-prototypes/index.html` comparison switches among captured light, dark, stale, unreadable, and completed states. It is a screenshot viewer; use the native apps to exercise interactions.

- Astra medium: `build/design-prototypes/astra/run.sh` launches Permission Parcel, a focused warm task surface with an app object and a quiet horizontal queue. It includes six native content captures, a source-linked HIG review, authored-color contrast calculations, fixture-transition checks, and verified native Command-R routing.
- Fable 5: `build/design-prototypes/fable/run.sh` launches Waybill, a permission queue with one expanded ticket and a file-to-destination handoff. It includes thirteen native captures, a source-linked HIG review, and a passing self-test covering twenty-four fixture/interaction assertions, including native arrow-key selection. The final review clarified record-only wording and strengthened essential text; it was rebuilt and recaptured, with the self-test passing again.

Each directory contains `DESIGN.md`, `HIG-REVIEW.md`, an embedded screenshot preview, source, and the built `.app`. Recheck preserves unresolved observations until a demo explicitly simulates an external change. Real TCC/Settings grants, attended pointer dragging, VoiceOver, and complete system accessibility-mode/contrast checks remain unverified. The next decision is which composition to adopt and refine, followed by attended validation of that direction.
