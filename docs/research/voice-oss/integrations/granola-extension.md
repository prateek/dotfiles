---
status: draft
doc_type: research
summary: "Static evidence ledger for the Granola Companion 0.4.18 Meet extension's attribution findings."
created: 2026-10-12
updated: 2026-10-12
status_detail: "Evidence ledger for the static meeting-integration investigation; no live meeting tested."
related:
  - ../meeting-integrations.md
---

# Granola Companion 0.4.18 — static Meet attribution findings

Investigated 2026-10-12. Scope: official Chrome extension only. No extension install, target execution, account login, meeting participation, private backend, or private app data. This is OBSERVED-STATIC code behavior, not observed runtime reliability. No vendor source should be copied into public documentation; the original archive and excerpts are retained in local capture storage.

## Identity and provenance

- Extension ID: `opaadbjlebbbnmjjgdmdllingedoleml`, manifest name Granola Companion, version `0.4.18`, MV3.
- Official source: https://clients2.google.com/service/update2/crx?response=redirect&prodversion=145.0.0.0&acceptformat=crx3&x=id%3Dopaadbjlebbbnmjjgdmdllingedoleml%26uc
- Official extension store linked by vendor help: https://chromewebstore.google.com/detail/opaadbjlebbbnmjjgdmdllingedoleml
- CRX SHA-256: `b9feebce1e443820c27b5c5513ba54c45f9289d88ada0471cecc67781c5590fe`; 522850 bytes.
- CRX3 header body 1308 bytes; ZIP payload starts at byte1320. ZIP SHA-256: `4b9593b58da4b4dc25cc1ae70c8986f0250b379348c8bfcca31a4e975b3c858a`.
- Static extraction rejects traversal, absolute names, symlinks; no package code executed. CRX signature not independently validated. Official transport and hashes do not establish cryptographic signature validation.
- Manifest public-key SHA-256 derived extension ID matches the requested ID; this is an identity consistency check, not a signature validation. All104 retained AST byte ranges/excerpt hashes and evidence file hashes passed validation.
- Capture root: `${XDG_STATE_HOME:-~/.local/state}/dotfiles/captures/voice-oss-integrations/granola-extension`.
- REA root artifact digest: `dba93cfa0b1835d5f35cf629b6dfe6cfb8987efb9d14da7fb47b2a168e2655df` (extracted-directory identity, distinct from ZIP/CRX hashes).

## REA evidence and coverage

Full retained CLI Evidence: `rea-javascript-full.json`, ID `ev_abd1b7ecaa3e4e401c56fb6628d9236d97c2013d1c64dfc63b56571b4bba8477`.

Views retained using exact portable inline parent Evidence, without repeating the analysis:

- `rea-summary.json`: `ev_5960bec80797c5bcbda3d22aba7ea56f639d506ea6c818ff73e1f154adebacec`.
- `rea-modules-page.json`: `ev_0d2b41b4e833e346e64fd785547c96949a88c851f1a7b71bee9aef300493c3e4`.
- `rea-speaker-module.json`: `ev_e7c09d558f964fa30b215521d5387d952c5f8c4b755a0876dcd5211e27913d93`.
- `rea-background-module.json`: `ev_6785f4a555462d55f27cb60db48230209108bbbb8063e8c5b50e150dc25275aa`.
- `rea-meeting-end-module.json`: `ev_e7ded38e7bf664d14df245ac2402aa405cd7728c753b0b58a62171b4456e27f7`.

REA parsed10 JavaScript files without parse failure, but semantic worker heap exhausted at default1024MiB on8 files (including speaker/background). Complete evidence record retention is not complete semantic analysis. The graph/semantic coverage is partial, with8 application unknowns and659 semantic unknowns. REA primarily supplies shipped-file inventory/identity and partial analysis in this run. The mechanism findings below come from direct inert packaged-code reading, supplemented by Babel8.0.4 AST range extraction in `static-anchor-excerpts.json`. Those supplemental observations are not REA-produced evidence and do not inherit a false complete-graph claim. No costly retry was necessary to establish these readable paths.

All offsets below are half-open UTF-8 byte ranges in the original packaged file. `static-anchor-excerpts.json` retains full excerpts + full file hashes + per-excerpt hashes. `anchor-index.json` in scratch is the same index without source excerpts.

## Findings

### GE01 — Manifest separates Meet metadata from desktop audio

OBSERVED-STATIC. Manifest requests `nativeMessaging`, `storage`, `alarms`. Speaker detection runs at document_idle, top frame only, on `https://meet.google.com/*`. Other scripts cover Meet and Google Chat frames. There is no Zoom host match. This extension's attribution path is a Meet integration; it does not establish Zoom internals.

Manifest SHA-256 `c27cbae8c3779fd1d096be3971ecfa5703b3f134edc26b2bafeddf5e8235a44a`; declaration is the full1641-byte manifest.

### GE02 — Meet active speaker is inferred from rendered UI styles

OBSERVED-STATIC. `Yt` scans `[data-participant-id]` tiles in main document and optional Document Picture-in-Picture document. It deduplicates IDs, rejects tiles under50px wide/high, requires the highlight detector, extracts a name, filters a Reframe utility tile, and removes self tiles.

The detector `an` checks two ancestors, the tile, and descendants up to depth10. `Le` checks computed border colors/widths and outline. It accepts a border/outline at least2px wide with a sufficiently saturated RGB color; it rejects near-black, near-white, transparent. `dn` also accepts a positive-height colored element at most10px wide, matching a narrow audio/activity bar heuristic. This is reading UI state; it is not calculating voice activity from PCM or an SDK speaker callback.

Anchors: `content-scripts/speaker-detection.js` `Yt[1742,2245)`, `an[4791,5030)`, `on[5030,5123)`, `Pe[5168,5400)`, `Le[5400,5822)`, `dn[5834,6048)`.

### GE03 — Participant names use several DOM fallbacks

OBSERVED-STATIC. Name extraction prefers tile/ancestor `data-self-name`; then tile aria-label; then non-button `span.notranslate`; then other aria-label descendants; then text nodes. Heuristics filter likely control labels, underscores, icon/text button roles, numeric-only text, and impose2–60 character bounds on some fallback paths. Some fallback tests expect a space or initial Latin uppercase letter. Display-name quality therefore depends on Meet UI and language/layout. No email/account identity verification is established here.

Anchors: speaker script `$e[6048,6770)`, `de[6770,6925)`, `ue[6925,6963)`, `ht[6963,7022)`, `un[7022,7536)`.

### GE04 — It deliberately excludes local self tiles and has a1:1 shortcut

OBSERVED-STATIC. Self IDs accumulate from: the only visible participant when participant count is1; mirrored video transform whose first matrix scale is-1; `(you)` text; visual-effects/frame-person controls associated with a participant; optionally a cached normalized self display name when the entire visible participant inventory matches reported count. It then excludes identified self IDs, mirrored videos, and `(you)` tiles from remote active-speaker candidates.

A separate participant message can supply `soleRemote` only when at least one self ID is known, exactly one other participant is present in the scanned map, and reported count is2. This supplies a fallback name/ID independent of highlight detection. Why/how the desktop combines it with local microphone audio is outside this extension scope.

Anchors: speaker `ct[2274,2364)`, `Jt[2463,2841)`, `nn[3385,3774)`, `ft[3774,4343)`, `rn[4343,4625)`, `dr[66586,67176)`.

Self IDs are cached in extension local storage by a `spaces/...` prefix, expiring after4hours; self display name is stored with a timestamp but the inspected reader does not enforce expiry. Anchors `en[2928,2999)`, `er[63572,63900)`, `tr[63900,64111)`, `nr[64111,64372)`, `rr[64372,64564)`, `cr[66143,66301)`, `lr[66301,66586)`.

### GE05 — Temporal smoothing is explicit; only one remote candidate is emitted

OBSERVED-STATIC. The scanner takes `speakers[0]` rather than emitting the full set. DOM changes coalesce over100ms. MutationObserver watches subtree childList plus class/style attributes; a3second periodic tick refreshes state and checks for PiP. Loss of an active remote speaker waits500ms before emitting null; a new active candidate cancels that timer. A change in name/ID or layout triggers an event; periodic ticks force a resend of stable identity. These are wall-clock UI observations, not sample-accurate diarization.

Anchors: speaker `Qe[64785,64848)`, `et[64848,65665)`, `jt[65935,66143)`, observer configuration immediately before `Vt[67385,67407)`, `tt[67407,67698)`, `Ft[67698,68314)`; constants `sr=100`, `ar=3e3`, `ir=500` at byte64564 onward.

### GE06 — Chrome Native Messaging is the desktop bridge

OBSERVED-STATIC. Background calls `runtime.connectNative('com.granola.app')`. Speaker script emits `content:active-speaker-changed` to extension runtime with participantId, participantName, layoutRegime. Background requires native port, connected status, and active extension-attribution flag; then it posts `granola:event`, event `active-speaker-changed`, nullable ID/name, optional layoutRegime, and `timestamp: Date.now()` to the native port. The timestamp is assigned in background forwarding, after the content-script scan/message; it is not an audio timestamp.

Participant snapshots similarly forward `selfParticipantIds` and `soleRemote` as `meet-participants-changed`. No meeting code/documentID is included in the active-speaker or participant-snapshot payload itself. Participant-count forwarding separately selects a first source tab and ignores other tabs until reset; that tab filter is not present in the inspected active-speaker branch. Whether desktop state resolves multi-tab ambiguity is UNKNOWN.

Anchors: background `re[61944,63419)`, host constant before that at byte60800 region; active-speaker branch `[69184,69647)`, participant snapshot `[69647,70047)`, participant count `[70047,70543)`. Speaker `jt[65935,66143)`.

### GE07 — Desktop start/stop and heartbeats gate speaker scanning

OBSERVED-STATIC. Native messages include status, recording-started/config, recording-stopped, heartbeat. The background records configuration in extension storage; `extension_attribution` defaults false. Content script begins observing only when recording is active and either extension attribution or participant-count collection is enabled. Inside the scanner, named active-speaker work requires attribution enabled. Heartbeats refresh state; a30minute timestamp check rejects stale stored state on initial read, and unchanged active/config heartbeat storage updates are skipped by listeners. A stop clears state/observers/timers. Disconnect allows15seconds before clearing recording/mute state; a Chrome alarm attempts reconnect after0.5minute.

Anchors: background `xn[63581,63892)`, `wn[64061,64299)`, `En[65680,66717)`, `re[61944,63419)`, `An[67062,67202)`; speaker `Gn[62094,62447)`, `Yn[62447,63265)`, `const fr[68944,69675)`, `nt[68314,68938)`.

### GE08 — Meeting lifecycle comes from DOM presence, with a separate session ID

OBSERVED-STATIC. Meeting detection looks for Leave call button, participant tiles in main document, or PiP participants. On entry it derives meeting code from URL pathname, generates a sessionID (UUID when available), and emits presence immediately then every10seconds with observedAt and participant count. A DOM observer coalesces checks200ms. Loss of meeting signals debounces3seconds before end; restored signals cancel end. beforeunload/pagehide also attempt end and teardown. PiP changes are observed.

Anchors: `content-scripts/meeting-end-detection.js` `_[176,265)`, `z[307,360)`, `K[1618,1698)`, `M[1698,1797)`, `it[2527,2797)`, `L[2797,3127)`, `O[3177,3350)`, `ot[3350,3400)`, `R[3449,3991)`, `x[4092,4150)`, `at[4446,4703)`, `const st[4900,5202)`. Background meeting-end `[70828,71137)` and presence `[71137,71726)`.

### GE09 — Loss behavior does not satisfy a durable event-history design

OBSERVED-STATIC + DESIGN INFERENCE. Active-speaker branch simply does nothing while its native gates are false and catches forwarding errors without queuing the attribution event. Meeting-ended has a separate in-memory queue capped to last20 events and flushes on connected status. It is neither persisted nor an unbounded event journal. Exact consequences after service-worker suspension or native crash were not runtime tested. This matters to the user's retain/reprocess ambition: an OSS design should decide how speaker observations survive disconnection and align to saved audio rather than copying these delivery semantics.

Anchors: background active-speaker branch `[69184,69647)`, `vn[61084,61432)`, `bn[61432,61706)`, `re[61944,63419)`; queue cap20 declared immediately before `ae`.

### GE10 — getUserMedia is a separate video watermark hook

OBSERVED-STATIC. In MAIN world at document_start, overlay code wraps getUserMedia. Audio-only requests return the original stream. For video when pipeline enabled, it wraps the first video track via canvas capture with overlay frames, preserves other tracks, and substitutes the resulting video track. This hook must not be mistaken for speaker/audio extraction merely because getUserMedia exists in the package.

Anchors: `content-scripts/overlay-main.js` `as[61189,62408)`, `os[62707,63267)`, `ds[63267,63589)`; declared main-world injection in manifest.

### GE11 — Bounded absence evidence

Case-sensitive literal byte search across packaged JS/JSON (excluding metadata) found no `RTCPeerConnection`, `getStats`, `getDisplayMedia`, `tabCapture`, `desktopCapture`, `WebSocket`, `AudioContext`, `zoom.us`. Results in `bounded-token-search.json`. This supports the concrete inspected DOM/native-message path; it is NOT proof that no dynamic/private/native path exists. Native app is another artifact and out of this branch.

## Public documentation corroboration

https://docs.granola.ai/help-center/taking-notes/speaker-attribution-google-meet

Official help currently describes both Accessibility-in-Chrome and extension options for speaker tags, based on Meet participant names/current-speaker signals. Either method is enough. Tags apply while transcribing, not retroactively. Docs acknowledge shared room devices, overlap, display names, and unclear active-speaker UI as limitations. Saved official HTML and receipt in capture root. Limit documentation-derived wording to this paragraph; most findings above derive from packaged code.

## Answered / open checklist

- Active-speaker source: ANSWERED STATIC, rendered Meet DOM/CSS heuristics.
- Name/ID source and self-filtering: ANSWERED STATIC.
- Timestamp creation and desktop transport: ANSWERED STATIC; desktop consumption/alignment UNKNOWN.
- Start/stop/reconnect/presence protocol: ANSWERED STATIC.
- Media hook relevance: ANSWERED STATIC, separate video overlay.
- Live robustness across Meet versions/layouts/languages/PiP/overlap: UNRESOLVED, no runtime.
- Native Messaging host authentication/installation and stream attribution policy: parent native artifact scope.
- Granola Zoom mechanism: out of extension scope; no Zoom injection declared.

## Proposed OSS implications (not competitor facts or settled architecture)

Store speaker UI observations as versioned, timestamped hints alongside recoverable audio; keep observation time and receive time separate. Represent unknown/self/multiple remote candidates and source provenance instead of making a display name authoritative. Bind all events to explicit recording+meeting+tab identities. Preserve metadata gaps/disconnects for later reprocessing. Test localization, minimized/hidden tiles, PiP, shared-room devices, overlapping speech, disconnected bridge, process restart, and frontend DOM changes. These are candidate requirements/experiments, not validated implementation.


[Return to the integration study](../meeting-integrations.md).
