---
status: draft
doc_type: research
summary: "Static evidence ledger for Granola desktop 7.637.0 meeting detection and speaker attribution paths."
created: 2026-10-12
updated: 2026-10-12
status_detail: "Evidence ledger for the static meeting-integration investigation; no live meeting tested."
related:
  - ../meeting-integrations.md
---

# Granola desktop 7.637.0: meeting speaker attribution

Investigated 2026-10-12. This is static reading of the official shipped macOS package, with REA artifact extraction, JavaScript inventory/AST analysis, and supplemental manual code-path reading. No app was installed or executed; no account, private app state, call, microphone, or network session was inspected. Runtime availability and accuracy remain unverified.

## Identity and evidence

Official managed-install documentation supplies `https://api.granola.ai/v1/download-latest`. On this date it resolved to `https://dr2v7l5emb758.cloudfront.net/7.637.0/Granola-7.637.0-mac-universal.dmg`. Bundle identity: `com.granola.app`, version/build `7.637.0`.

| Artifact | SHA-256 |
| --- | --- |
| Downloaded DMG, 307058364 bytes | `9ca52082cd037259b58d457a215e91ec2d77a398f448abb5e0cf06ffe56b2623` |
| `Contents/Resources/app.asar` | `93b819456233610aca69b5c35d7beed977d77b47e460c554eddae4b2bbaba482` |
| ASAR member `dist-electron/main/index.js` | `7f8f06319922f6f638752fb0ef4930fdda357678fdb51342447edb68f02d04b8` |
| ASAR member `dist-electron/third_party_meeting_automation_process/index.js` | `8c14d4e570c372fb8dc9c20d6c4ca8e8a034ecc49ddc355e000fb2a0dd1cfcb4` |

REA `extract_artifact`: `ev_913c1cdf1151292ed198e3214bab39767d20230e460e9ef87b78df2d3c9aecc8`.

REA `analyze_javascript_application`: `ev_27baf093670912b86fe3dbb37c37e73dc3e38c231d8b8e06814a13c7f6be50e5`.

Complete raw results, retained members and manual anchors live under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/captures/voice-oss-integrations/granola/`. The portable evidence index records their file hashes. `manual-static-anchors.json` retains the original excerpts and half-open UTF-8 byte ranges; public research keeps paraphrases and coordinates only.

The initial DMG inventory collided with a separate read-only mount and failed; it is not counted as successful evidence. A subsequent serialized read-only mount/copy/detach succeeded. ASAR extraction and analysis initially rejected declared integrity mismatches. A changed `record-and-continue` policy retained the discrepancies as untrusted observations. Eight unpacked native entries differ from their ASAR-declared hashes; this is not resolved by the analysis and is not proof of malicious modification. No vendor executable was run.

REA read 957 relevant files, parsed 843 JavaScript files, and reported zero parse failures. Graph expansion and semantic coverage are incomplete: the parent reserved remaining capacity for static observations, so semantic analysis of both principal members above was not started. The findings below are **manual inert code-path observations bound to extracted member hashes**, not claims that REA generated complete interprocedural traces. Presence of unrelated bundled components, including a diarizer, does not establish use in this path.

## Findings

### G-D01 — Native speaker monitors run through a dedicated child process

OBSERVED-STATIC. The desktop dispatches `monitor-zoom-speakers` and `monitor-meet-chrome-speakers` with a 500 ms poll parameter. A child process loads `third_party_meeting_automation.node` and calls its matching native methods. Meet accepts optional serialized selectors. Snapshot-enabled variants exist. The parent validates returned record shapes; malformed records terminate the child and invoke its failure callback.

This establishes actual JavaScript-to-native wiring, beyond filenames or symbol names. Native selectors/AX traversal require the separate native bridge investigation. A 500 ms requested interval does not establish measured event latency; native observers may also wake on UI events.

### G-D02 — Active-speaker state is a bounded timeline, with lag correction and self filtering

OBSERVED-STATIC. `yT` rejects known self participant IDs and normalized self display names. Empty or self events clear the active speaker. Changed speakers enter a ring of at most 10000 events. Native records may supply an event time and a platform-specific detection-lag adjustment; otherwise the handler uses receipt time and a 300 ms default lag. Insert times cannot precede the previous ring entry. Repeated same-speaker observations refresh the current state's receipt time.

`bT` converts events to intervals and caps the last open interval at ten seconds past its latest refresh. `Oze` selects a dominant speaker by weighted temporal overlap with a transcript chunk. It ignores intervals shorter than 200 ms; expands the considered chunk by 500 ms before and 300 ms after, with out-of-chunk overlap weighted 0.25. These are observed implementation constants, not recommended defaults or accuracy guarantees.

### G-D03 — Extension events are consumed using desktop receipt time

OBSERVED-STATIC. The incoming extension schema includes participant ID/name, optional layout regime, and timestamp. The active-recording configuration must enable `extension_attribution`. The inspected handler forwards ID/name to `yT` without its optional timestamp argument. Thus this handler uses desktop receipt time, even though the extension emits its own background timestamp. Separate participant-change messages update self IDs and a sole-remote candidate.

This distinction matters: an emitted timestamp is not proof that downstream alignment uses it. The feature also depends on recording configuration, so packaged code alone does not prove entitlement or rollout state in an account.

### G-D04 — Meet AX records are filtered and gated independently

OBSERVED-STATIC. The Meet path checks OS support, a platform feature flag, and workspace `speaker_attribution_enabled`. A record can report `blindReason`; this path records the reason and returns without treating it as fresh speaker evidence. It identifies self from participant entries and clears self-active events. Accepted named events pass the native record timestamp and configured Meet lag to the shared timeline.

A separate two-person fallback examines the visible roster, confirmed self identity, historical remote names and continuity. Missing names suppress its candidate. It is not an acoustic identity match. Its last fresh record expires after ten seconds. Actual behavior when a browser is minimized or AX stops exposing tiles remains untested.

### G-D05 — Zoom records carry roster, layout and self identity

OBSERVED-STATIC. The Zoom branch has its own platform flag and workspace gate. Records carry participant names/active booleans, self/account display names, optional meeting-window presence, participant count, layout regime and timestamp. Self-name evidence can upgrade a lower-confidence account name. When a record explicitly reports no meeting window, it does not refresh normal speaker state; previously retained intervals remain subject to their time bounds. Self-name matches clear the active speaker. Accepted remote events pass the native timestamp and configured Zoom lag into the common timeline.

The two-person fallback requires exactly one candidate remote name and, where participant count is known, a count of two. If earlier observations included other remote names, a stable candidate must persist for 15 seconds. This is deliberately more qualified than assigning every remote segment to the first name in a roster.

### G-D06 — Speaker attribution attaches to system audio and transcript timing

OBSERVED-STATIC. The `xz` attribution function immediately declines non-system audio and checks integration readiness. It asks the timeline for the dominant participant; absent that, it may use a sole-remote fallback. Native Zoom/Meet fallback accessors check freshness. The Meet extension fallback instead reads the cached `soleRemote` value through `Dze()` with no timestamp/expiry check; `Eze` updates it and `jze` resets it. The speaker timeline's ten-second bound does not expire this separate cache. It marks source provenance as `zoom-ax`, `meet-chrome-ax`, `meet-dom` or the separate Teams route. `bz` also maps timed words to participant intervals for final system transcripts when the necessary timing and feature conditions are present.

The bundled code includes an ambiguity/abstention algorithm, but the followed higher-level voice-unit branch is explicitly Teams-gated. This pass does **not** establish that Zoom or Meet uses that same abstention branch. Do not generalize adjacent code to every integration.

### G-D07 — Audio capture is separate from speaker observations

OBSERVED-STATIC. A separate audio child-process message path emits microphone and system buffers, with capture timestamps. Its start request includes a `useCoreAudio` setting. This corroborates the documented mic/system split, but the exact native capture implementation and live permission behavior were not decompiled here. This speaker investigation does not validate durable audio retention.

## Interpretation and gaps

The observed architecture combines UI-derived participant activity with independently captured audio and transcript timing. UI activity is evidence about likely identity, not an isolated per-participant audio track. Names can collide; visual state can lag; hidden windows and overlapping speech may produce ambiguous or absent signals. Those are test hypotheses, not observed defects.

Answered: desktop/native bridge routing, extension consumption, platform gates, self filtering, timing history, chunk/word attribution, and bounded roster fallback. Partially answered: exact native UI signal extraction (separate report), audio capture primitive, runtime rollout/entitlement. Unresolved: actual latency, detection accuracy, layout/localization compatibility, overlapping speech, live multi-tab arbitration, recovery across sleep/disconnect, and retention guarantees.

Primary corroboration: [speaker tags](https://docs.granola.ai/help-center/taking-notes/speaker-attribution), [Zoom](https://docs.granola.ai/help-center/taking-notes/speaker-attribution-zoom), [Meet](https://docs.granola.ai/help-center/taking-notes/speaker-attribution-google-meet), [official managed downloads](https://docs.granola.ai/help-center/getting-started/managed-installations).


[Return to the integration study](../meeting-integrations.md).
