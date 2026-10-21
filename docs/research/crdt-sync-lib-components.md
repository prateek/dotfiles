---
status: active
doc_type: research
summary: "Design and component selection for the encrypted git-transport CRDT file-sync library: Atuin-style per-replica logs, Loro as the CRDT engine, git2-rs for in-process git, and a UniFFI-centred binding pipeline."
created: 2026-10-21
updated: 2026-10-21
related:
  - crdt-sync-atop-git.md
  - launcher-recon/tinycast-migration.md
status_detail: "Desk research as of 2026-10-21 answering the handoff in crdt-sync-atop-git.md (items 1–4). Decisions below are proposed, not accepted; nothing was built or run. Next step is the two-replica prototype in the plan section."
---

# CRDT sync library: design and components

## Short answer

Build it in Rust from three off-the-shelf parts and one small layer of our own:

1. **Transport: Atuin's trick, on any git server.** Each replica owns one ref
   (`refs/sync/<replica-id>`) and only ever appends to it. Every push is a
   fast-forward, so there is no server-side merge, no retry loop, and the server
   is a dumb store of encrypted blobs. This removes the push-race problem the
   [previous survey](crdt-sync-atop-git.md) found in every git-backed design.
2. **Convergence: Loro.** The blobs in those logs are Loro change batches.
   Readers fetch all refs, decrypt, and `importBatch` everything; Loro guarantees
   convergence, parks changes whose dependencies have not arrived, and reports
   exactly which `(peer, counter)` ranges are missing. It is the only engine
   with a stable history-dropping snapshot (for checkpoints) and a movable tree
   type (for file renames).
3. **Git in-process: git2-rs over vendored libgit2.** gitoxide still cannot push
   as of October 2026. libgit2 fetches and pushes over HTTPS and SSH without a
   `git` binary, builds on iOS, and its GPLv2 linking exception allows embedding.
4. **Bindings: UniFFI for Swift, Python, Kotlin and Go; wasm-bindgen for TS; a
   Tauri plugin crate calling the core directly.** rust-nostr's one-repo,
   one-orchestrator release pipeline is the copyable model.

The rest of this document records the evidence and the open risks.

## Goal, restated

From [the survey](crdt-sync-atop-git.md#goal-this-research-serves) plus the
2026-10-21 clarifications:

- Sync a **tree of many text files** (Tinycast snippets and notes, an
  Obsidian-style vault, "all of the above") across Prateek's machines and,
  later, between users.
- **Encrypted at rest on the server.** The server never sees plaintext.
- Git repositories as the transport and storage; no `git` binary required.
- Rust or Zig (Rust chosen, see below); first-class Swift, Go, Python,
  TypeScript and Tauri bindings; small enough to embed.
- Text-only merging is fine to start. Binary files get a whole-file policy.
- Plain-git-readable files are **not** required. Encryption rules them out of
  the server; an optional plaintext mirror branch is a later nice-to-have.

## Decisions

Proposed on 2026-10-21; none accepted yet.

| Decision | Choice | Why |
| --- | --- | --- |
| Language | Rust | Every CRDT engine with bindings, both in-process git options, and every binding generator are Rust. Zig would mean wrapping libgit2 and hand-writing a C ABI. |
| Unit of sync | A repo: one Loro doc per file plus one Loro tree doc for paths | A vault must not load as one blob; renames and moves must converge rather than fork into duplicates. |
| Transport layout | One append-only ref per replica | Single writer per ref means every push is a fast-forward. Borrowed from Atuin's per-host record store. |
| Convergence | Loro 1.16 | Stable shallow snapshots, `UpdatesInRange` export, pending-queue import, movable tree, first-party Swift/Python/TS. |
| Git engine | git2-rs 0.21 (libgit2 1.9.6, vendored), HTTPS + token first | Only option that pushes in-process today. |
| Encryption | v0: one symmetric key (mnemonic), XChaCha20-Poly1305 per blob, Atuin-style. v1: per-repo data key wrapped to recipient public keys, age-style. | Easy to use now; adding a second user later is a key-wrap, not a re-encrypt of history. |
| Binding tool | UniFFI (proc-macro, library mode) for Swift, Python, Kotlin, Go; wasm-bindgen for TS; Tauri plugin crate on the core | Matches what Loro, Automerge, Matrix and rust-nostr ship. |

## Architecture

### Ref layout

```text
refs/sync/<replica-uuid>          append-only log of encrypted Loro update blobs
refs/sync/<replica-uuid>/ckpt     optional: this replica's latest shallow snapshot
```

- A commit on a replica's log holds one blob: `export(UpdatesInRange{spans})`
  covering only that replica's new ops since its last commit, encrypted. The
  commit message carries the Loro frontier it reaches so a reader can skip
  commits it already has without decrypting them.
- Committer, author and timestamps are pinned to constants. The server then
  sees ref names, blob sizes and commit counts, which is at or below what
  Atuin's server sees.
- Readers fetch `refs/sync/*`, walk each log from the last-seen commit, decrypt
  and `importBatch`. A non-empty `ImportStatus.pending` means a dependency
  lives in a ref not yet fetched; fetch again.
- Push is `Remote::push(["<sha>:refs/sync/<id>"])`, fast-forward by
  construction. Force-push (`+` refspec) is used only on a replica's own ref,
  to compact.
- `refs/sync/<uuid>` collides with no documented reserved namespace on GitHub,
  GitLab, Gitea or stock git. Avoid `refs/pull/`, `refs/for/`,
  `refs/merge-requests/`, `refs/pipelines/`, `refs/environments/`,
  `refs/keep-around/`, `refs/notes/`.

### Checkpoints

New replicas should not replay every blob ever written. A replica periodically
writes `ShallowSnapshot(frontier)` to its `ckpt` ref. The one rule Loro imposes:
a shallow document cannot import updates concurrent with its start frontier, so
the checkpoint frontier must be one every known replica has already pushed past,
never the local head. Loro's docs put it as "coordinate before trimming".

### File model

- `tree.loro`: a Loro **movable tree** whose nodes are files and directories;
  node metadata holds the name and a content-doc id. Renames and moves are tree
  ops and converge.
- One Loro doc per text file, keyed by the node id, holding a `Text`
  container. Opened lazily; only files the host touches are loaded.
- Binary files: whole-file blobs with a last-writer-wins register in the tree
  node; no merge.
- The host API never sees any of this:
  `open(remote_url, key) -> Repo`, `repo.read("notes/todo.md")`,
  `repo.write(path, text)` or an editor-style `apply_delta`, `repo.sync()`,
  `repo.subscribe(callback)`.

### Encryption

- **v0.** One 256-bit key per repo, shown once as a BIP-39 mnemonic. Each blob
  is `XChaCha20-Poly1305(key, nonce, plaintext, aad = ref name + commit index)`.
  The AAD binds a blob to its position so the server cannot replay or reorder.
  This is Atuin's model exactly.
- **v1.** Blob header gains a key id; a per-repo data key is wrapped to each
  recipient's X25519 public key (age's recipient stanza). Adding a user wraps
  the data key once; removing one rotates it from the next checkpoint on.
- Keys never leave clients. The server authenticates with its own means (PAT
  over HTTPS, later SSH keys); that is access control to ciphertext, not to
  content.

## Component evidence

### CRDT engines

Compared on 2026-10-21 for: per-replica export of own ops, out-of-order and
idempotent import, history compaction with a stable format, a tree type, and
binding coverage.

| | Loro | Automerge | Yrs | diamond-types |
| --- | --- | --- | --- | --- |
| Version / date | 1.16.2, 2026-09-21 | 0.12.0, 2026-09-16 | 0.28.0, 2026-09-17 | 1.0.0, 2022-08; repo at unpublished 2.0 |
| Last push / active maintainers (12 mo) | 2026-10-19 / 1 (+1 minor) | 2026-10-20 / 3–4 (Ink & Switch) | 2026-09-30 / 1 | 2026-09-02 / 1 |
| Text algorithm | Fugue, Eg-walker-style storage | RGA-family list | YATA (Yjs-compatible) | Eg-walker reference implementation |
| Tree with moves | Yes (Kleppmann move op) | No | No (XML tree, no move) | No |
| Own-ops export | `UpdatesInRange{peer, counter, len}` | `save_after(heads)` | `encode_diff(state_vector)` | `encode_from(version)` |
| Compacted snapshot, stable | `ShallowSnapshot`, `StateOnly` | `bundle()` experimental, "do not use for durable data" | n/a: GC model, no history kept | Not implemented |
| Format declared stable | Yes, since 1.0 | Published spec; no explicit guarantee found | De facto (Yjs v1/v2) | "still in flux" |
| Out-of-order import | Pending queue + `ImportStatus` | Change queue, topo-sorted | Stashed until predecessors arrive | Errors on unknown parents |
| Swift | First-party, UniFFI, SwiftPM xcframework, iOS 13+ | First-party, UniFFI, current | yswift stale (yrs 0.18, 2024) | macOS-only experiment |
| Python | First-party pyo3 | First-party pyo3, dev pre-releases only | pycrdt, very active | None |
| TS | wasm, 1.1 MB gz | wasm, 1.1 MB gz, nightly to build | Yjs itself, ~300 KB pure JS | npm from 2023 |
| Go | Community `loro-go` via uniffi-bindgen-go, core 1.13.6 | Org repo frozen on core 0.5.0 (2023) | Community pure-Go `reearth/ygo` | None |
| License | MIT | MIT | MIT | ISC |

Sources: [Loro encoding docs](https://loro.dev/docs/tutorial/encoding),
[Loro import status](https://loro.dev/docs/concepts/import_status),
[Loro shallow snapshot](https://loro.dev/docs/advanced/shallow_snapshot),
[Loro tree docs](https://loro.dev/docs/tutorial/tree),
[loro-swift](https://github.com/loro-dev/loro-swift),
[loro-go](https://github.com/aholstenson/loro-go),
[Automerge CHANGELOG](https://github.com/automerge/automerge/blob/main/rust/CHANGELOG.md),
[automerge-swift](https://github.com/automerge/automerge-swift),
[automerge-go](https://github.com/automerge/automerge-go),
[y-crdt](https://github.com/y-crdt/y-crdt), [pycrdt](https://github.com/y-crdt/pycrdt),
[reearth/ygo](https://github.com/reearth/ygo),
[diamond-types](https://github.com/josephg/diamond-types),
[Eg-walker paper](https://arxiv.org/abs/2409.14252).

**Why Loro.** `UpdatesInRange` lets a replica write exactly its own new ops as
one opaque blob per commit with no dependence on what other replicas have.
`ImportStatus.pending` maps directly onto "which refs have I not fetched yet".
`ShallowSnapshot` is the only stable compaction format. The movable tree is the
only tree-with-moves. Swift and Python are first-party and current; Go is
generated from the same `loro-ffi` UniFFI interface, so regenerating it against
1.16 is a build step, not a rewrite.

**Risks.** Loro's bus factor is about one: roughly 95% of the last year's human
commits are Zixuan Chen. loro-swift still calls itself experimental.
`ExportMode` is `#[non_exhaustive]` and `loro-internal` is explicitly unstable;
depend only on the `loro` facade crate and keep a decode-compatibility test in
CI. If organisational durability outweighs the tree type and compaction, choose
Automerge and accept writing the Go binding over `automerge-c`.

### In-process git

| | gitoxide (`gix` 0.89.0) | git2-rs 0.21 / libgit2 1.9.6 | Pure-Rust newcomers |
| --- | --- | --- | --- |
| Fetch over HTTPS | Yes, pure Rust (reqwest + rustls) | Yes (SecureTransport on Apple) | Yes |
| Push | **No** | Yes, fast-forward and force, per-ref status callback | zerogit-remote 0.5.0 (2026-10-05), puregit 0.0.2 (2026-10-19); days old |
| SSH in-process | No, spawns `ssh` | Yes, libssh2 (drags OpenSSL on iOS) | No / unproven |
| Objects without worktree | Yes | Yes | Yes |
| iOS | Builds; no SSH | Builds via the `apple` branch of its build script; link `iconv` and `z` | Untested |
| License | MIT/Apache | GPLv2 + linking exception (bindings MIT/Apache) | MIT/Apache |

gitoxide's push is unchecked in [crate-status.md](https://github.com/GitoxideLabs/gitoxide/blob/main/crate-status.md)
and the README; tracking issue #306 was closed in July 2026 into
[feature proposal #2776](https://github.com/GitoxideLabs/gitoxide/discussions/2776)
with the maintainer saying review is the bottleneck. Its SSH transport is a
[`SpawnProcessOnDemand`](https://github.com/GitoxideLabs/gitoxide/blob/main/gix-transport/src/client/blocking_io/ssh/mod.rs)
running `ssh`. git2-rs: [`Remote::push`](https://docs.rs/git2/latest/git2/struct.Remote.html),
[`Cred::ssh_key_from_memory`](https://docs.rs/git2/latest/git2/struct.Cred.html),
[libgit2 COPYING](https://github.com/libgit2/libgit2/blob/main/COPYING),
[iOS link issue #1185](https://github.com/rust-lang/git2-rs/issues/1185).
Ref namespaces: [git-check-ref-format](https://git-scm.com/docs/git-check-ref-format),
[GitHub `refs/pull` read-only](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/checking-out-pull-requests-locally),
[Gitea pre-receive hook](https://github.com/go-gitea/gitea/blob/main/routers/private/hook_pre_receive.go).

**Plan.** Ship v1 on `git2` with `features = ["vendored-libgit2", "https"]`,
HTTPS and token basic-auth only, behind a `trait SyncRemote { ls_refs, fetch,
push(ref, old, new, force) }`. Second milestone: a pure-Rust backend from
`gix-transport` + `gix-protocol` for fetch plus a ~300-line `receive-pack`
client over `gix-pack`'s encoder; single-ref, report-status, no deltas is
enough for this access pattern and upstreams naturally into #2776. SSH last,
and only in-process. Never patch vendored libgit2 sources.

**Unverified.** Whether `openssl-sys` lands in an iOS build of `git2` with the
`https` feature (the gate excludes only `macos`); run
`cargo tree --target aarch64-apple-ios`. libgit2 2.0 (rc.1 on 2026-10-14) may
change TLS backends. GitHub accepting `refs/sync/*` via `git push` is widely
relied on but not documented; test it.

### Bindings

| Need | Choice | Evidence |
| --- | --- | --- |
| Swift (SwiftPM + XCFramework) | UniFFI 0.32, proc-macros, library mode; `uniffi-bindgen-swift --xcframework`; stable-only iOS/macOS triples; distribution repo `<name>-swift` with `binaryTarget` url + checksum | [uniffi-bindgen-swift](https://github.com/mozilla/uniffi-rs/blob/main/docs/manual/src/swift/uniffi-bindgen-swift.md), [loro-swift build script](https://github.com/loro-dev/loro-swift/blob/main/scripts/build_swift_ffi.sh), [rust-nostr publish-swift.yml](https://github.com/rust-nostr/nostr-sdk-ffi/blob/master/.github/workflows/publish-swift.yml) |
| Python | UniFFI + maturin `bindings = "uniffi"` (Glean's pattern); ctypes, so version-independent wheels | [Glean pyproject](https://github.com/mozilla/glean/blob/main/pyproject.toml), [maturin bindings guide](https://github.com/PyO3/maturin/blob/main/guide/src/bindings.md) |
| TypeScript | wasm-bindgen for browser and Node from one crate, one npm package with conditional `exports` (Loro/Automerge model); napi-rs native addon only if profiling demands it | [loro-wasm build.ts](https://github.com/loro-dev/loro/blob/main/crates/loro-wasm/scripts/build.ts), [Automerge HACKING.md](https://github.com/automerge/automerge/blob/main/javascript/HACKING.md) |
| Go | uniffi-bindgen-go with loro-go's pattern: static libs built in CI and committed, musl `+crt-static` on Linux, `--print native-static-libs` for Windows LDFLAGS | [loro-go build-libs.yml](https://github.com/aholstenson/loro-go/blob/main/.github/workflows/build-libs.yml), [loro-go libs.go](https://github.com/aholstenson/loro-go/blob/main/libs.go) |
| Kotlin (later) | UniFFI first-party Kotlin via `cargo-ndk` | [uniffi README](https://github.com/mozilla/uniffi-rs) |
| Tauri | `tauri-plugin-<name>` crate with `#[tauri::command]`s over the core; plugin Rust runs on iOS and Android natively | [Tauri plugin development](https://v2.tauri.app/develop/plugins/), [mobile plugins](https://v2.tauri.app/develop/plugins/develop-mobile/) |

**Version coupling is the main hazard.** uniffi-bindgen-go is pinned to
uniffi 0.31.0; [issue #96](https://github.com/NordSecurity/uniffi-bindgen-go/issues/96)
(0.32 support) has been open since July 2026 with no maintainer reply, and a
version mismatch makes it silently emit nothing (loro-go's `updateLoro.sh`
guards against exactly this). Adopting it pins the FFI crate to uniffi 0.31
until that lands; the fallback is a cbindgen C ABI over the core with purego
(Turso) or cgo (automerge-go). Diplomat is lower overhead but has no Swift
backend. uniffi-bindgen-react-native could give TS from the same annotations
but is 0.x and lockstepped to 0.31; rust-nostr maintains a patch script for it.

**Pipeline to copy:** rust-nostr's
[`nostr-sdk-ffi`](https://github.com/rust-nostr/nostr-sdk-ffi): one FFI repo,
one `workflow_dispatch` orchestrator with per-language booleans and a
`publish: false` dry run, reusable per-OS build workflows uploading artifacts,
per-language publish jobs consuming them. One `vX.Y.Z` tag drives everything.

Workspace layout:

```text
crates/core/             pure Rust API; depends on loro, git2 (optional), crypto
crates/ffi/              UniFFI proc-macros; cdylib + staticlib + rlib; uniffi.toml
crates/wasm/             wasm-bindgen; cdylib + rlib
crates/tauri-plugin-x/   tauri::plugin::Builder over core; guest-js/, permissions/
bindings/{swift,python,go,kotlin,js}/
xtask/                   swift build-framework, bindgen, release helpers
```

## Open questions

- **Conflict surfacing.** Loro converges, but concurrent edits to the same line
  can produce text no human wrote. Beagle and Manyana flag "too near" edits;
  decide whether to surface those or trust the merge.
- **Checkpoint coordination.** Who decides a frontier is safe to trim when a
  replica has been offline for months? Probably: never trim below a replica's
  last-seen frontier, and age out replicas explicitly.
- **Log growth.** Per-blob overhead on a vault with thousands of small edits;
  batch edits per sync rather than per keystroke.
- **Key distribution for v1.** Where recipient public keys live (in the repo
  under a signed ref, or out of band).
- **Plaintext mirror.** If a non-secret repo wants plain-git-readable files, a
  separate `main` branch materialised from the CRDT state, Gitbin-style.

## Plan: two-replica prototype

Not accepted; the next concrete step.

1. Cargo workspace with `core` only. Dependencies: `loro`, `git2` (vendored,
   https), `chacha20poly1305`, `bip39`.
2. Implement `SyncRemote` on git2 against a bare repo over local file transport,
   then over HTTPS to a Gitea container and a GitHub test repo. Push and
   force-push to `refs/sync/test-<uuid>`; assert fast-forward acceptance.
3. Two replicas edit the same file concurrently, sync through the remote, and
   converge. Add a rename on one side and an edit on the other; assert the
   tree converges without duplicates.
4. Checkpoint: replica A writes a shallow snapshot at a frontier B has passed;
   a fresh replica C bootstraps from it and imports B's later log.
5. `cargo tree --target aarch64-apple-ios` to settle the OpenSSL question;
   build the `ffi` crate for one iOS triple.
6. Only then: UniFFI surface and the first binding (Swift), since Tinycast
   snippets on a Mac and an iOS reader are the first consumers.

## Handoff

For a fresh agent continuing with no other context: this document and
[crdt-sync-atop-git.md](crdt-sync-atop-git.md) hold the research; the plan
above is the next step. Items marked unverified above are the first things to
check. The three component sections were produced by parallel research passes
on 2026-10-21 whose transcripts are not in the repo; every claim was given a
primary-source link at the time, and the links here are the ones that mattered
for the decision.
