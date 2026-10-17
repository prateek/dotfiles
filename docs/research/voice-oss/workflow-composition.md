---
status: draft
doc_type: research
summary: "Action chaining through Tuna, Raycast and iOS automation: sourced integration surfaces, proposed action contracts, and recovery criteria."
created: 2026-10-12
updated: 2026-10-12
status_detail: "Explicit Mac/iOS workflow requirements with sourced integration options and proposed action contracts. No integration implemented or exercised."
related:
  - requirements.md
  - candidate-journeys.md
  - product-behavior.md
  - apple-platforms-and-ux.md
---

# Chain actions across Mac and iOS apps

U32 requires workflow composition through **Tuna, Raycast and similar macOS tools**. U33 requires the same capability on **iOS**. These extend the existing CLI/MCP/hooks/XDG requirements: a user must be able to make one action's result the next action's input. The exact action set and platform adapters remain proposed.

An example to design around is: choose audio, transcribe it, summarize the resulting transcript, attach the summary to a project note, then pass a link or text to another app. A second workflow might use only transcription and export. Saved recordings and previous results remain available under U29–U30 even if a later step fails.

## Documented integration surfaces

Primary documentation was checked on 2026-10-12. These are integration opportunities, with no installed-app or runtime validation.

| Surface | What its documentation establishes | Implication to investigate |
| --- | --- | --- |
| Tuna commands | Commands combine subjects, actions and optional targets; subjects include text, files and selections. Some results return new subjects to the launcher. [WC-S01](https://tunaformac.com/docs/how-commands-work) | Represent a recording, transcript or note as an actionable item, and return results that can feed another action. |
| Tuna CLI and URLs | The CLI accepts piped content and stages/runs commands through the Mac app, launching it when necessary. URLs can stage or run commands. [WC-S02](https://tunaformac.com/docs/tuna-cli), [WC-S03](https://tunaformac.com/docs/url-schemes) | Explore both launcher-to-product invocation and returning a product result to Tuna. A launched command needs a separate completion contract. |
| Raycast scripts | Script Commands accept declared arguments, display stdout and recognize nonzero exit status as failure. [WC-S06](https://github.com/raycast/script-commands/blob/master/README.md) | A small script can wrap the product CLI; a richer extension can expose search, choices and job progress. |
| Raycast command launches | Deeplinks carry arguments/context and have a confirmation prompt. `launchCommand` can pass context to another command, with permission prompts across extensions; its promise resolves on launch, not when the work finishes. [WC-S04](https://developers.raycast.com/information/lifecycle/deeplinks), [WC-S05](https://developers.raycast.com/api-reference/command) | A sequence of launches is insufficient evidence of a completed data pipeline. Wait for a product result or use an explicit job reference. |
| Apple App Intents and Shortcuts | App intents expose app actions and return results to system experiences. Shortcuts combines actions; sharing actions can pass content to other apps or save/append files. [WC-S07](https://developer.apple.com/documentation/AppIntents/AppIntent), [WC-S08](https://support.apple.com/en-euro/guide/shortcuts/apdf22b0444c/ios), [WC-S09](https://support.apple.com/en-ie/guide/shortcuts/apdaf74d75a5/ios) | Explore individually useful actions with parameters and outputs on iOS and Mac. Share Sheet input, Siri and supported hardware entry points can lead into a chain. Validate each action's platform and execution constraints. |

The requirement is useful composition on both platforms. It does not imply that a Mac shell script can execute unchanged on iOS, that a launcher confirmation can be bypassed, or that a URL invocation returns a processing result. Apple recording/background limits remain in the [platform study](apple-platforms-and-ux.md).

## Proposed action vocabulary

These are candidate capabilities, not implemented commands or an approved API schema. Each should make sense alone and inside a larger workflow.

| Action family | Candidate input | Candidate output |
| --- | --- | --- |
| Capture or import | Recording request or supplied audio/file | Persisted recording reference and capture state |
| Transcribe or reprocess | Recording reference, model profile, language | New transcript revision or durable job reference |
| Transform | Transcript/note revision and chosen instruction/template | New generated result with its source revision |
| Find or organize notes | Query, stable note reference, collection or links | Matching notes or updated note reference |
| Create or append | Supplied text/result and destination note | Note revision and stable link |
| Export or hand off | Chosen revision and output format | Text, file or authorized link usable by the next app |
| Inspect or resume a job | Job reference | Actual state, result reference, error or next recovery action |

Treat an audio file, transcript revision, note, exported file and job as distinguishable values. A launcher adapter might return JSON or a file reference; a Shortcut might expose app entities or file/text values. The core operation should preserve identity and meaning across those representations. Exact formats, IDs and compatibility policy remain open.

The person should be able to choose a model profile, template and destination where relevant, save a reusable recipe, and inspect what each step will send or change. Branches, batches and reusable sub-workflows are candidate needs to test. These may live in the host automation tool; a new in-app visual workflow builder is not yet required.

## Candidate behavior and recovery criteria

- Return a usable output when a short action completes. For long work, return an identifiable job and a way to retrieve its eventual result. Distinguish accepted, running, saved, completed, failed and canceled states.
- Preserve intermediate results and prior revisions. Retrying the export step must not re-record audio, overwrite edits or rerun successful processing unnecessarily.
- Make retry and resume deliberate. Record which steps completed and which external effects are uncertain; a timeout is not proof that another app did nothing. Do not promise exactly-once external effects without a supported mechanism.
- Keep route/profile choices explicit. If an offline iOS action cannot finish, retain its input and show how to continue; do not silently switch to a remote provider.
- Respect destination access, foreground needs, permission denial and OS interruptions. A stopped launcher or Shortcut should leave saved work recoverable, with continuation behavior defined and tested.
- Pass transcript text as data. Keep secrets out of shareable URLs and workflow files; choose scoped references or explicit exports for private content.
- Expose human-readable failure messages and structured results at the appropriate interface. Review behavior for sharing, sending, calling and other external changes needs its own action policy; retrying processing must never redial a call.
- Make recipes discoverable and portable where practical. XDG-based Mac configuration and iOS Shortcuts should share concepts and named profiles; identical configuration files on every platform are not assumed.

## Candidate journeys and unresolved choices

[P-F58–P-F62](candidate-journeys.md#workflow-composition-on-mac-and-ios) cover Tuna selection, a Raycast processing chain, iOS shared-file input, iOS capture-to-note composition, and recovery from a failed downstream step. They are proposals tied to U32–U33, not competitor flow records.

Resolve which actions must ship first; whether Tuna needs a dedicated extension or CLI/script adapter; how Raycast receives completed results; which iOS intents can finish in context; and how long jobs resume after lock, app switching or host termination. Also decide whether recipes need cross-device portability and whether any product-owned workflow runner is necessary. A focused prototype should demonstrate an output passed into a real second action, then recover the same chain after interruption without losing originals or duplicating an external effect.
