---
status: draft
doc_type: research
summary: "Focused static pass over Granola's native meeting bridge dylib with REA and bounded LLVM disassembly."
created: 2026-10-12
updated: 2026-10-12
status_detail: "REA artifact inspection and bounded LLVM disassembly; native decompilation timed out. No runtime tested."
related:
  - ../meeting-integrations.md
---

# Granola native meeting bridge: focused static pass

2026-10-12. Granola 7.637.0 official package supplied by the parent investigator. This pass read the shipped `Contents/Resources/native/libThirdPartyMeetingAutomationBridge.dylib`; it did not launch Granola, Chrome or Zoom, inspect private state, or make a call. Identity/custody: [identity/custody metadata](../data/integrations/granola-native-identity.json).

## Evidence and limitation

Original universal dylib SHA-256: `58cb4dfc12893dd28822a0ae6aeb29572dd73b5c3fcfc1d0a79f40aff4e6fdd8`. Parent-derived arm64 slice SHA-256: `fb0cada6053dabfa9369057e41eb5454004c93054926987f46170beee6b49c49`. Both are now retained under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/captures/voice-oss-integrations/granola-native/artifacts/`; hashes were checked after copying. Parent-supplied official DMG SHA-256 is `9ca52082cd037259b58d457a215e91ec2d77a398f448abb5e0cf06ffe56b2623`.

REA `inspect_macho` succeeded: **`ev_ccff1e7135fec7256956050712c0917566f8fc454eca07876ad146e04c13e950`**, complete record `inspect-macho.json` under that capture root. Its imports include `AXUIElementCopyAttributeValue`, `AXUIElementCreateApplication`, `AXObserverAddNotification`, `AXObserverCreateWithInfoCallback`, and related Accessibility operations. The import/export inventories are explicitly non-exhaustive. This establishes shipped symbols/API references, not execution or end-to-end compatibility.

A REA/Ghidra session bound the exact arm64 hash, but initial analysis for `0x16f208` exceeded the supported default startup timeout of **330,000 ms**, returning `provider_timeout`. The driver had begun the next function before that error was inspected; that attempt was interrupted, its owned Ghidra process terminated, and `close_binary` returned successfully. `01-zoom-roster.json`, `mcp.stderr.log`, and `99-close.json` preserve the outcome. **There is no successful native decompilation and no analyze_function Evidence ID.** The default five-function queue was not completed; no runtime target was executed.

To preserve useful progress, four narrow function ranges were disassembled with the existing `xcrun llvm-objdump`, and Swift symbols were demangled with `xcrun swift-demangle`. These are **ordinary static-tool observations, not REA decompilation Evidence**. Full bounded disassembly, symbol inventory and a small Swift field-record decoder/output are retained in the capture directory. The decoder source `read-fields.py` is retained in the local capture directory.

## Findings

### GN-I01 — The native bridge has independent Zoom and Chrome/Meet AX reader/roster paths (OBSERVED STATIC)

The shipped symbol inventory contains `ZoomSpeakerSceneReader.acquire`, `ZoomSpeakerRoster.collectParticipantTiles`, `ZoomSpeakerRoster.activeSpeakerName`, `MeetChromeSpeakerSceneReader.acquire`, `MeetChromeSpeakerAXSnapshot.snapshot`, and `MeetChromeSpeakerRoster.collectParticipantTiles`. Distinct monitor/event-record symbols accompany them. This corroborates an Accessibility-based native integration beyond the Electron-side bridge exports; function names alone do not establish every branch's behavior.

Anchors: REA Mach-O Evidence above; `speaker-symbols.json`; native entry addresses Zoom recursive roster `0x16f208`, ordered speaker `0x16f9d4`, Meet roster `0x5b7ec`, Meet snapshot `0x5cd24`.

### GN-I02 — Meet native defaults contain specific CSS-class tokens (OBSERVED BY DISASSEMBLY; FIELD ASSOCIATION INFERRED)

At `MeetChromeSpeakerSelectors.builtIn.getter` (`0x684d0`), ARM64 immediate construction stores three Swift short strings into successive 16-byte fields: **`dkjMxf`**, **`aGWPv`**, **`kssMZb`**. At `0x68508`–`0x68510`, it writes Boolean bytes **1, 1, 0** after these string fields.

A targeted `__swift5_fieldmd` parse found the matching six-field order at file offset `0x1a40b8`: `galleryTileRoot`, `selfPreviewRoot`, `speaking`, `speakingMeansActive`, `latchSelfByName`, `inferSelfFromRemoteControls`. Combining the field order with the getter's stores gives the following **high-confidence static inference**, not a live verified selector contract:

| Field | Inferred built-in value |
| --- | --- |
| galleryTileRoot | `dkjMxf` |
| selfPreviewRoot | `aGWPv` |
| speaking | `kssMZb` |
| speakingMeansActive | true |
| latchSelfByName | true |
| inferSelfFromRemoteControls | false |

Anchors: `meet-selectors-llvm.txt`, exact getter range `0x684d0`–`0x68514`; `selected-swift-fields.json`, descriptor `0x1a40b8`. Runtime override selection remains unknown in this pass: the binary also exposes `MeetChromeSpeakerSelectors.resolve(from:)` and diagnostics for invalid overrides, so the built-in defaults must not be represented as necessarily effective in every running session.

### GN-I03 — Meet roster assembly uses tree classes, static text, and self-specific controls (OBSERVED CALL SITES; RESULT SEMANTICS PARTIAL)

The disassembled roster function calls:

- `collectTiles` at `0x5b824`;
- `subtreeContainsRemoteOnlyControl` at `0x5b9ac`;
- `firstStaticTextValue` at `0x5bad8`, `0x5bdc0`, `0x5bf50`;
- `subtreeContainsYouToken` at `0x5bc38` and `0x5bf84`;
- `subtreeContainsSelfOnlyControl` at `0x5bc48`;
- `subtreeContainsClass` at `0x5bf64`.

This is concrete evidence of the native roster traversing an AX-derived tree and applying class/name/self heuristics. Together with GN-I02 it supports a speaking-class signal, but this pass did not recover the full control/data flow to prove which UI states and override combinations produce each emitted active-speaker event. An enabled microphone or a participant name is not, by itself, established as the active-speaker signal.

Anchor: `meet-roster-llvm.txt`, function range `0x5b7ec`–`0x5c0c8`.

### GN-I04 — Zoom roster extraction is localized AX-tree parsing with an additional ordered-speaker path (OBSERVED CALL SITES; ALGORITHM PARTIAL)

The recursive roster function compares the node's first string field with the inline constant **`AXTabGroup`** at `0x16f278`–`0x16f2ac`, calls `ZoomSpeakerLocalizationContext.earliestAudioPhraseStart` at `0x16f2e0` / `0x16f44c`, calls `trimmedName` at `0x16f5d4` / `0x16f62c`, and recursively visits nodes at `0x16f958`.

The distinct `orderedSpeaker(node:tiles:)` function calls `participantCount` (`0x16fa78`), `hasForcedVideo` (`0x16faa0`), `findSelfRaw` (`0x16fb74`), `parseSelfDisplayName` (`0x16fbb8`), `isAudioUnmuted` (`0x170014`), `videoLayout` (`0x170114`), and `isShareContent` (`0x1702f4`). Other shipped symbols include `supportsOrderedSpeaker(appVersion:)`, `compactSpeaker`, and localization `parseTalkingName`.

This shows multiple version/layout/localization-aware speaker-reading mechanisms. **It does not yet establish the exact active-speaker predicate, version gate, handling of hidden/minimized Zoom windows, or which tile order is considered authoritative.** Do not turn the presence of `isAudioUnmuted` into a claim that unmuted equals speaking. Full branch interpretation needs either a successful targeted decompilation or a controlled known-participant call.

Anchors: `zoom-roster-llvm.txt`, `zoom-ordered-llvm.txt`, and `speaker-symbols.json`.

## Open work

The native bridge path and selector candidates are partially established. Live active-speaker accuracy/latency, overlap, minimized/background behavior, localization coverage, effective remote overrides, current Zoom/Meet compatibility, and complete native-to-JS event correlation remain unverified. The parent investigator's ASAR work and the separate Meet extension pass should be used to establish call sites and payload transport; these findings do not prove that either native monitor is always enabled.


[Return to the integration study](../meeting-integrations.md).
