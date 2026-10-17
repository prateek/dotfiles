---
status: draft
doc_type: research
summary: "Local, VPS and Unraid hosting topologies, model placement, pairing, updates, backup and operator journeys from primary sources."
created: 2026-10-12
updated: 2026-10-12
status_detail: "Primary-source feasibility research and candidate flows; no architecture or deployment approved."
---

# Self-hosting, model placement, and composability

The proposed product can separate recording, transcription, text processing, and storage across devices and servers. The reviewed components establish plausible implementation paths; they do not establish acceptable latency, battery use, meeting accuracy, or recovery behavior for this product. No account login, deployment, private-audio upload, or hardware benchmark was performed.

**Explicit requirements from the brief:** an aspirational open-source voice and meeting product spanning Mac, iPhone, and Watch; CLI and MCP interfaces; self-hosting locally, on a provider such as exe.dev, or on Unraid. **Derived candidates:** every flow numbered `SH-F` below, placement controls, device pairing, job persistence, scopes, and operational tooling. **Unresolved choices:** supported device generations, server packaging, default engines and models, account model, encryption design, performance targets, and which features belong in the initial release. Candidate commands describe possible behavior, not existing software. The follow-up adds explicit hooks, XDG dotfiles, retained on-device history, and optional iCloud sync; [product behavior and durability](product-behavior.md) owns those details.

Research date: **2026-10-12**. Eighteen substantive primary sources were opened. Source identifiers below correspond to the [evidence ledger](data/sources.jsonl). Mutable upstream documentation is evidence of documented capability on this date, not a pinned implementation contract.

## Hosting an application and running a model are different choices

The **management functions** establish identities, pair devices, select models, allocate jobs, enforce permissions, and report health. The **content functions** handle recordings, transcripts, summaries, search indexes, and synchronization. Either group can reveal sensitive information: job titles and filenames are content too. A self-hosted management service that forwards recordings to a commercial transcription API is not local audio processing.

| Function | Candidate placement | Decision the user needs to understand |
| --- | --- | --- |
| Capture | Mac, iPhone, or Watch | Which microphone or meeting source is recorded, and where the first durable copy exists |
| Speech-to-text | Capturing device, another owned device, user server, or separately enabled third party | Whether original audio leaves the device |
| Cleanup | Device, user server, or third party | Whether raw transcript and contextual vocabulary leave the device |
| Summary/actions | Device, user server, or third party | Whether full transcript, selected passages, participant names, and notes are sent |
| Search | Local index, user-server index, or third-party embedding service | Where text, embeddings, queries, and retrieved passages are processed |
| Storage | Required retained copy on the capture device; optional additional server/provider copies | Where each artifact persists and who can decrypt it |
| Sync | Required opt-in iCloud support; user-server/direct alternatives to investigate | What is replicated, which devices hold it, and whether the relay can read it |

This is a candidate product model, not a chosen service layout. A “local” badge should describe the current recording's complete route. “Audio stays on iPhone; transcript summarized on your Unraid server” is more useful than a global privacy toggle. Selecting a server for sync must not implicitly select it for transcription.

## What the hosting substrates actually provide

### exe.dev

exe.dev documents VMs sharing an account or work pool's CPU and RAM. Each VM has its own disk on local NVMe; disk changes are streamed to another server in the regional cluster, with a stated lag of a few seconds. That is provider durability, not evidence of user-controlled historical restore points. No GPU entitlement or suitable inference throughput was established by this architecture page. [SH-S01: exe architecture](https://exe.dev/docs/architecture)

Its HTTPS proxy handles certificates and TLS termination, defaults to private access, and forwards a selected application port. Alternate ports from 3000 through 9999 are documented, with only one selected public port. These are useful ingress primitives, but upload limits, timeouts, streaming behavior under interruption, and application recovery still need qualification. [SH-S02: HTTP proxies](https://exe.dev/docs/proxy)

Browser cookies are not the only access path: VM-scoped bearer tokens are documented. The preferred `X-Exedev-Authorization` header is consumed by the proxy, while signed context and provider identity headers reach the VM. This permits an adapter, but does not supply the product's native-client pairing, recording permissions, OAuth discovery, or account-recovery design. Whether selected MCP clients can send the extra provider header remains unverified. [SH-S03: VM HTTPS tokens](https://exe.dev/docs/https-tokens-for-vms)

**Candidate fit:** host the API, sync, storage coordination, and queued work; qualify CPU inference independently. A local Mac doing inference while exe.dev stores results is another candidate, but adds an unavailable-worker case. A provider-managed machine remains a remote trust boundary even when the user controls the application.

### Unraid

Unraid documents bridge, host, isolated, and custom-IP container networking; bridge exposes explicitly mapped ports. Persistent application data belongs outside the container, commonly in `appdata`, with explicit host/container paths and restrictive access modes. Container installation therefore needs a durable-data mapping contract, not merely an image name. [SH-S04: container configuration](https://docs.unraid.net/unraid-os/using-unraid-to/run-docker-containers/managing-and-customizing-containers/)

Its Docker recovery documentation says recreating `docker.img` preserves variable data only when that data was mapped outside the image. Custom Docker networks must be recreated separately after image deletion. A backup should retain storage mappings and network definitions alongside application state. [SH-S05: Docker recovery](https://docs.unraid.net/unraid-os/troubleshooting/common-issues/docker-troubleshooting/)

The documented Tailscale integration gives containers separate network identities, but has container-compatibility and network-mode restrictions; host-mode integration is unavailable. It also changes the container startup path. Treat this as an optional access method requiring a compatibility test, not universal native-client authentication or Watch connectivity. [SH-S06: Unraid Tailscale](https://docs.unraid.net/unraid-os/system-administration/secure-your-server/tailscale/)

An official Unraid application guide demonstrates NVIDIA-driver setup and an Ollama container, including a different driver choice for 50-series GPUs. That demonstrates a documented installation path, not compatibility of every Unraid GPU, plugin, or model. Record the actual GPU, driver, container runtime, memory availability, and competing workloads before making a support claim. [SH-S18: Unraid model-hosting example](https://docs.unraid.net/guides/paperless-ngx/)

### Local Mac and model engines

Ollama documents a loopback default, configurable model storage, local-only operation through `OLLAMA_NO_CLOUD`, and bounded parallelism/queues. Concurrent requests and longer contexts increase memory demand. Its hardware guide documents Apple Metal acceleration and GPU-specific Linux/Windows constraints. “Ollama installed” therefore proves neither an offline policy nor acceleration of the chosen job. [SH-S07: FAQ](https://docs.ollama.com/faq), [SH-S08: hardware](https://docs.ollama.com/gpu)

WhisperKit's repository now redirects to Argmax's open-source Swift SDK. It documents device-selected downloads, explicit model paths, incremental file loading, a CLI, and a local transcription server with SSE output. The separately described Pro WebSocket service must not be counted as an OSS feature. These documents do not qualify Watch execution or uninterrupted mobile background processing. [SH-S09: Argmax OSS/WhisperKit](https://github.com/argmaxinc/argmax-oss-swift)

whisper.cpp documents CPU inference, Apple acceleration, Linux, and iOS support. Its approximate unquantized model table ranges from tiny at 75 MiB disk/~273 MB memory to large at 2.9 GiB/~3.9 GB. Those are model figures, not a complete process or concurrency budget. [SH-S10: whisper.cpp](https://github.com/ggml-org/whisper.cpp)

llama.cpp's server provides generation and embedding-related endpoints, optional API keys, optional TLS, health checks, and container examples. These are useful engine interfaces; an engine-wide API key is not a per-recording permission model. Engine readiness should be tested separately from application readiness. [SH-S11: llama.cpp server](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md)

## Candidate end-to-end flows

### SH-F01 — Choose and inspect a processing route

On first use, offer understandable routes: entirely on this device where supported; use an owned computer/server; or configure an explicitly selected external processor. Show speech-to-text, cleanup, summary, search, storage, and sync separately. Save a route version with each recording and derived artifact. Before changing a route, show which future content will move and whether existing recordings are affected. A failed local job remains failed or queued until an already authorized alternative is available; fallback to uploading private audio is never implied by selecting self-hosting.

### SH-F02 — Install and bootstrap the service

Provide candidate native-Mac and Linux-container installation paths, with an Unraid template and provider instructions as packaging options. Bootstrap should check CPU architecture, writable durable storage, free space, clock, port conflicts, and the selected engine's availability. Establish the first owner through a one-use setup mechanism, then disable bootstrap access. Expose “service ready, no model installed” as a valid state. Test restart after host reboot and delayed storage availability. Whether the product bundles engines or connects to separately managed ones remains open; installation must explain the ownership of updates and files either way.

### SH-F03 — Establish remote reachability and identity

Enter the server URL, validate TLS, identify the expected service, and complete product authorization. Distinguish DNS failure, certificate failure, provider login, product login, and insufficient permissions. exe.dev ingress, an Unraid private network, or a user-operated reverse proxy are alternative routes with different operator work. Qualify uploads and result streams through the actual route. A browser successfully opening the homepage is insufficient evidence for native background transfers or MCP access. Avoid treating provider headers arriving through an unintended direct port as trusted identity.

### SH-F04 — Pair Mac, iPhone, and Watch

The owner starts pairing on an authorized device, approves the displayed device and server identity, and grants explicit capabilities. A short-lived pairing code or QR exchange is a candidate mechanism, not a selected protocol. Each device receives a separately revocable identity. Show whether the Watch owns a server credential or communicates through the phone; do not silently assume either topology. Exercise pairing with an expired code, wrong account, offline phone, replaced phone, and revoked server. Recovery should not require copying a server administrator credential to every device.

### SH-F05 — Download and qualify a model

Show the exact model, publisher, version/digest, license link, download size, expected additional storage, supported engine, and intended stage. Download resumably; validate integrity before marking it ready. Keep failed downloads separate from usable models. Run a short synthetic diagnostic, then offer a user-controlled sample evaluation. Report cold-start time, transcription speed, peak memory, and errors; do not infer quality from parameter count. Support selecting a smaller approved model, waiting, or cancelling. Deleting a model should identify queued jobs that depend on it and preserve their source recordings.

### SH-F06 — Process one recording reproducibly

After durable capture, transcribe using the selected route, preserve the original transcript, and derive cleanup and summary as separately versioned results. Display stage, processor location, language, model version, and source range. Rerunning a summary must not overwrite a human edit without an explicit replacement choice. If diarization is unavailable, do not present fabricated participant identities. A partial transcript should remain recognizable as partial. U30 requires on-device retention of the original material and history for reprocessing after successful processing. Model-cache cleanup must not delete that history.

### SH-F07 — Work offline, reconnect, and cancel

Show “saved on this device,” “waiting for server,” “uploading,” “processing,” and “available on other devices” as distinct states. Use durable job IDs and an idempotency mechanism so a retry cannot create duplicate recordings or duplicate paid calls. Retain resumable upload state and verify received content. Successful upload must preserve the local source and history (U30). Allow local processing only when an installed, approved model fits the route. Surface server sleep, revoked credentials, full disk, quota exhaustion, and unsupported format with actionable next steps. Cancellation should state whether capture stopped, upload stopped, computation stopped, or only result delivery ended.

### SH-F08 — Use the CLI interactively or in automation

Candidate operations include `record`, `transcribe --file`, `transcribe --stdin`, `search`, `show`, `export`, `jobs status`, and `jobs cancel`. Stdin audio requires a declared format where autodetection is ambiguous; text stdin should have a separate operation. Interactive commands can show progress and choices. Automation needs versioned JSON results, stable error codes, noninteractive authentication, stdout reserved for results, and diagnostics on stderr. For streams, use framed events with a final terminal event. Accept file paths safely, report unsupported inputs, preserve original files, and require an explicit overwrite choice for exports. Document SIGINT semantics and whether a submitted remote job continues.

### SH-F09 — Expose selected capabilities through MCP

Offer local stdio and remote HTTP as candidates, with the same product authorization rules. The current 2026-07-28 transport specification distinguishes client-launched stdio from HTTP POSTs returning JSON or request-scoped SSE. HTTP output streaming is not a microphone-streaming protocol. [SH-S12: transports](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports)

Candidate read permissions cover search, recording metadata, transcript passages, and job status. Separate write permissions cover import, annotation, reprocessing, export, deletion, and route changes. Search results must enforce recording permissions before returning snippets. A tool marked read-only still needs server-side authorization; MCP describes annotations as untrusted unless their source is trusted. Return schemas and recording/source references, not just prose. [SH-S15: tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools)

For remote authorization, implement the chosen MCP revision's discovery and OAuth requirements, including issuer validation and least-privilege scopes. The HTTP authorization specification explicitly treats stdio differently. Product scopes are a design choice; names such as `recordings:read` are not standardized MCP permissions. [SH-S14: authorization](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization)

Long transcription jobs need application-owned durable handles even when a caller lacks an asynchronous extension. In 2026-07-28, the optional Tasks extension supports polling and task cancellation; cancellation acknowledges intent and does not guarantee stopped computation. For request-scoped HTTP SSE, disconnect instead signals cancellation, and resumable `Last-Event-ID` streams are unsupported. Pin protocol versions and test both cases rather than assuming 2025 behavior. [SH-S16: Tasks](https://tasks.extensions.modelcontextprotocol.io/specification/2026-07-28/tasks), [SH-S13: HTTP transport](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http)

MCP access can send returned transcripts to the connecting assistant and its model provider. Local storage alone cannot prevent that disclosure. The grant screen should explain which corpus and operations the assistant can access; an arbitrary-file-read or shell tool is unnecessary for this product interface.

### SH-F10 — Diagnose capacity and enforce quotas

A candidate `doctor` report separates client capture, reachability, authorization, writable storage, queue health, model availability, and engine acceleration. Redact transcript text, paths containing names, and credentials from shareable diagnostics. Measure oldest queued job, available recording space, model storage, per-stage duration, and recent failures. Investigate capacity budgets for new recordings, concurrent jobs, and external-provider spending. A budget for retained bytes must warn or block new writes rather than silently expire history. Provide warning and refusal states before exhausting capacity; never automatically reclaim original recordings or revision history. Capacity limits apply per user/device as well as globally where multiuser operation is supported.

### SH-F11 — Update, roll back, and recover startup

Show application, engine, model, and schema versions separately. Check compatibility, back up durable state, drain or checkpoint jobs, and update one controllable component at a time. A rollback needs the previous binary/image and a compatible data snapshot; switching image tags cannot reverse an incompatible database migration. After restart, verify a synthetic import, transcription, search, export, and paired-client connection. Keep partially migrated data recognizable and prevent incompatible writers from opening it. Decide whether updates are operator-triggered or automatic before promising unattended operation.

### SH-F12 — Back up and restore

Define the backup set: retained source recordings, transcripts and edits, derived artifacts, database, permissions, route settings, encryption material under its own protection, and version metadata. Model caches may be rebuildable if exact artifacts remain obtainable; they are not equivalent to irreplaceable recordings. Produce a consistent snapshot and checksummed manifest, then restore to an isolated destination. Verify artifact counts, hashes, decryption, search rebuild, and completed versus queued jobs. Provider replication and Unraid container recreation do not demonstrate this application-level restore. State the chosen recovery-point and recovery-time targets only after a measured exercise.

### SH-F13 — Migrate and export

Support an inspectable export containing the retained source audio, raw/edited transcripts, timestamps, speaker labels with their provenance, summaries, notes, and a machine-readable manifest. Exported text formats and lossless reimport are separate promises. For migration, prepare the destination, verify its model and schema compatibility, copy and verify a consistent snapshot, then move a test device before changing the main endpoint. Keep the old copy until verification and explicit cleanup. Define how ongoing captures and later edits reconcile during the move; a URL change alone is not migration.

### SH-F14 — Revoke access and remove retained data

List paired devices, CLI credentials, MCP clients, and provider connections with their scope and last use. Revocation must stop new access and define treatment of active uploads/jobs. Rotate affected secrets without disabling unrelated devices. Report that revocation cannot erase an already exported transcript or an offline device's existing copy. A recoverable archive/trash workflow should preserve originals and history. Any deliberate permanent purge must identify originals, derivatives, indexes, replicas, and backup retention separately. Encryption-key recovery and unrecoverable deletion semantics remain design questions; do not promise remote wipe or immediate backup erasure without implementing those guarantees.

## Sizing, licensing, and feasibility questions

**Sizing is a measured envelope.** Candidate disk planning adds retained audio, temporary upload/transcoding files, database/indexes, installed models, download staging, backup staging, and rollback headroom. As arithmetic rather than a benchmark, mono 16 kHz/16-bit PCM is approximately 115 MB per hour before container overhead; stereo or additional tracks multiply it. Compression changes this figure. Model memory, attention/context caches, parallel requests, media decoding, and the OS compete for RAM or VRAM. Test a long meeting alongside live dictation instead of benchmarking only one short file.

**Product openness and model licensing are separate.** OpenAI explicitly releases Whisper code and weights under MIT. That finding does not license every converted artifact, diarization model, embedding model, or cleanup LLM. Track code licenses, exact weight licenses, attribution requirements, redistribution conditions, and any account-gated downloads independently. A product requiring a proprietary processor for essential behavior would need that limitation stated clearly. [SH-S17: Whisper license statement](https://github.com/openai/whisper/blob/main/README.md)

The decisive unknowns are: acceptable dictation latency versus meeting throughput; multilingual/noisy/multi-speaker accuracy; phone and Watch thermal/background limits; exe.dev inference capacity and ingress limits; actual Unraid GPU compatibility; device identity and key recovery; encrypted-sync versus server-processing boundaries; MCP client revision/extension support; and an interoperable export/import contract. These need small qualification experiments and product choices, not an architecture declaration based on component availability.
