---
status: active
doc_type: research
summary: "Survey of tools that give CRDT- or Automerge-style automatic convergence on top of a git repository: data in git refs, CRDT merge of file content, real-time editors that publish to git, git-compatible VCSs, and auto-sync baselines."
created: 2026-10-19
updated: 2026-10-19
status_detail: "Desk survey of primary sources as of 2026-10-19; nothing was installed or run. Serves a planned Rust/Zig git-transport CRDT sync library; the handoff section lists follow-up searches. No plan or ADR consumes it yet."
---

# CRDT-style sync on top of a git repository

## Short answer

Yes, but only in pieces. Nothing found gives Automerge's whole contract
(edit any file in the repo concurrently, sync, always converge, never stop for a
human) while keeping a normal git repository as the storage and transport.
Projects get close on one of three layers:

1. **Structured records in git refs.** Radicle Collaborative Objects, git-bug,
   git-meta, git-appraise, and Dolt's git remotes keep their data in git objects
   under non-branch refs and merge concurrent writes deterministically, with no
   user conflict step. They do not apply to working-tree files.
2. **CRDT merge of ordinary file content.** Beagle, a git-compatible SCM by
   Victor Grishchenko (gritzko), replaces git's line merge with a token-level
   Causal Tree/RGA merge over plain git blobs. This is the closest match to "every
   file is a CRDT, still a git repo". It is young, its author says some cases
   still produce conflicts, and the CRDT property only holds when merges happen
   in Beagle, not in stock git.
3. **A live CRDT session that publishes to git.** Gitbin (Obsidian), Aldine
   (LaTeX), Quire (Markdown), and the older jotgit (OT, not CRDT) run Yjs or OT
   for live edits and treat git as the snapshot and transport layer. Edits made
   outside the session that arrive by `git pull` still go through git's merge.

Everything else is either a CRDT/patch-theory VCS that is not git-backed
(Pijul, Automerge-based Patchwork and Backstitch, Lix, Bram Cohen's Manyana
demo), a better git merge that can still conflict (Jujutsu, Mergiraf), or an
auto-commit tool that avoids conflicts by choosing a winner or keeping copies
(gitwatch, git-sync, SparkleShare, git-annex, Obsidian Git, Legit).

Grishchenko's own survey reaches the same split. He describes one path as a
native-CRDT format that becomes incompatible with git and another as
git-CRDT, which "abuses the normal git machinery to do distributed database
operations". He calls git "a terrible database". Beagle is his third path.
[gritzko, "My own GitHub: Git, CRDT, Markdown", 2026-08-07](https://github.com/gritzko/replicated.live/blob/master/blog/crdt.html)

## Goal this research serves

Prateek wants a tiny, portable library that syncs files edited on multiple
machines and by multiple users, merges them with CRDTs, and uses ordinary git
repositories as the transport. Requirements as stated on 2026-10-19:

- Written in Rust or Zig.
- First-class bindings for iOS and server-side runtimes: Swift, Go, Python,
  TypeScript, and Tauri apps, among others.
- Small enough to embed; git is the wire and the storage, not a dependency the
  host must shell out to.

This survey found no existing library that meets these requirements. The
[follow-up handoff](#handoff-follow-up-research) lists what to search next.

## What "on top of git" means here

The question allows several readings, and the projects split along them:

- **Storage:** the replicated state lives in git objects (blobs, trees, commits)
  reachable from some ref.
- **Transport:** replicas exchange state with `git fetch` and `git push`
  against an ordinary git server.
- **Convergence:** two replicas that saw the same set of changes compute the
  same state, and no change forces a human resolution step.
- **Scope:** working-tree files, or only side data (issues, reviews, metadata).

A project scores well when it meets all four for working-tree files. None found
does that completely.

## Comparison

Activity is the GitHub `pushed_at` date or latest release observed through
`gh api` on 2026-10-19 unless stated otherwise.

| Project | What converges | Stored in git? | Convergence model | Maturity / activity (2026-10-19) | Link |
| --- | --- | --- | --- | --- | --- |
| Beagle + libdog | Any text file's content (token level) | Yes: plain git blobs, git sync protocol | Causal Tree/RGA ("chronofold") weave merge over tokenized blobs; adjacent concurrent inserts flagged as conflicts | Repo created 2024; last push 2026-08-12; 248 stars; single author | [gritzko/beagle](https://github.com/gritzko/beagle) |
| Radicle COBs | Issues, patches, identity docs, external JSON COB types | Yes: commit DAG under `refs/cobs/<type>/<id>` per peer namespace | Op-based: signed change DAG, evaluated in topological order, ties broken by timestamp then OID | Heartwood pushed 2026-10-19 | [radicle-dev/heartwood](https://github.com/radicle-dev/heartwood) |
| git-bug | Bugs (entities) | Yes: commits with operation packs under `refs/<namespace>/<id>` | Op-based CRDT; Lamport clocks plus DAG order; ties broken by operation-pack ID | v0.11.0 released 2026-09-22; ~10.8k stars | [git-bug/git-bug](https://github.com/git-bug/git-bug) |
| git-meta | Key/value metadata on commits, paths, branches, project | Yes: tree under `refs/meta/...` | Tree merge; lists via timestamped entries, strings last-writer-wins, explicit tombstones | Spec and proof of concept; created 2026-03; pushed 2026-10-08 | [git-meta/git-meta](https://github.com/git-meta/git-meta) |
| git-appraise | Code review records | Yes: git notes under `refs/notes/devtools/*` | One JSON item per line merged with git's `cat_sort_uniq` notes strategy (set union) | Last push 2023-08-12 | [google/git-appraise](https://github.com/google/git-appraise) |
| Dolt (git remotes) | SQL table rows (cell level) | Remote only: Dolt data stored under `refs/dolt/data` in a git repo | Three-way cell-wise merge; same-cell conflicts recorded in `dolt_conflicts` tables | Git remotes since v1.81.10 (2026-02) | [dolthub/dolt](https://github.com/dolthub/dolt) |
| Gitbin | Obsidian vault text files | Yes: readable files on `main` plus `.gitbin` control data | Yjs CRDT merge, then publish snapshot; retry on non-fast-forward; binaries whole-file | Created 2026-10-05; 1 star | [thiagomajesk/gitbin](https://github.com/thiagomajesk/gitbin) |
| Aldine | LaTeX projects | Yes: each project is a git repo, pushed to GitHub/GitLab/Gitea | Yjs inside the editor; git push/pull with conflict resolution for outside commits | Created 2026-07; pushed 2026-10-19 | [trahloff/Aldine](https://github.com/trahloff/Aldine) |
| Quire | Markdown files | Optional `--git` snapshots | CRDT session over plain files; external edits merged into the session as deltas | Pushed 2026-10-01 | [heetdalsania/quire](https://github.com/heetdalsania/quire) |
| chronicle | Agent session JSONL files | Yes | Grow-only set (G-Set) union of lines | Pushed 2026-10-13; 4 stars | [geekmuse/chronicle](https://github.com/geekmuse/chronicle) |
| Irmin (`irmin-git`) | Application values in a key/value store | Yes: git-compatible on-disk format | User-defined three-way merge functions; verified mergeable data types | Release 3.11.0 (2025-06); pushed 2026-10-09 | [mirage/irmin](https://github.com/mirage/irmin) |
| Realtime GitHub (GitHub Next) | Rich-text JSON docs in a repo branch | Yes: each edit produces a new git state on the server | ProseMirror transactions rebased by a central server; explicitly not a CRDT | Prototype; page not fetched (see gaps) | [githubnext.com/projects/rtgh](https://githubnext.com/projects/rtgh/) |
| jotgit | Markdown files | Yes: saves are commits | Operational transformation (ot.js) via a server | Abandoned; last push 2014-07-24 | [jdleesmiller/jotgit](https://github.com/jdleesmiller/jotgit) |
| Jujutsu | Repo operations (refs, heads); file content via merge | Commits in git; op log in `.jj`, not git | Op log merges divergent operations by three-way view merge; conflicts recorded as first-class state, not resolved | v0.46.0 released 2026-10-07 | [jj-vcs/jj](https://github.com/jj-vcs/jj) |
| Mergiraf | File content at merge time | Uses git's merge-driver hook | Syntax-aware tree merge (tree-sitter); falls back to conflict markers when unsure | Active on Codeberg (not measured) | [codeberg.org/mergiraf](https://codeberg.org/mergiraf/mergiraf) |
| Pijul | File content (patches) | No (one-way `pijul git` import) | Commutative patches; conflicts are state, resolved once by a patch | 1.0 beta since 2022 (not measured) | [pijul.org](https://pijul.org/manual/why_pijul.html) |
| Manyana | Single-file text (demo) | No | Line weave CRDT; merges never fail, nearby concurrent edits flagged | Demo, ~470 lines Python; pushed 2026-04-23 | [bramcohen/manyana](https://github.com/bramcohen/manyana) |
| Patchwork / Backstitch (Ink & Switch) | Documents, Godot projects | No: Automerge documents and an Automerge sync server | Automerge CRDT | Backstitch alpha; pushed 2026-10-16 | [inkandswitch/backstitch](https://github.com/inkandswitch/backstitch) |
| Lix | Files and SQL rows | No: own storage (memory, filesystem, OPFS, S3) | Row/column merge, last writer by server acceptance order | Alpha; pushed 2026-10-14 | [opral/lix](https://github.com/opral/lix) |
| Legit | Files through a filesystem API | Yes: standard git repos | Auto-commit every write; on both-sides change, whole file "theirs wins" | Alpha; last push 2026-05-18 | [Legit-Control/monorepo](https://github.com/Legit-Control/monorepo) |
| Teamtype (ex-Ethersync) | Local text files, live | No: lives beside git ("real-time complement to Git") | Automerge CRDT, peer to peer | Pushed 2026-10-15; ~1.9k stars | [teamtype/teamtype](https://github.com/teamtype/teamtype) |
| SparkleShare, git-annex, gitwatch, git-sync, Obsidian Git | Whole files | Yes | No CRDT: keep both copies, rename variants, rebase, or ask the user | Mixed (see baseline section) | See baseline section |

## Layer 1: structured records in git refs

### Radicle Collaborative Objects

The `radicle-cob` crate describes collaborative objects as "graphs of CRDTs"
stored on a git backend, with a create/read/update interface and no delete.
[radicle-cob lib.rs](https://github.com/radicle-dev/heartwood/blob/HEAD/crates/radicle-cob/src/lib.rs)
Each object lives at `refs/cobs/<type name>/<object id>`, namespaced per peer as
`refs/namespaces/<remote>/refs/cobs/<typename>/<object_id>`.
[radicle cob.rs](https://github.com/radicle-dev/heartwood/blob/HEAD/crates/radicle/src/cob.rs),
[radicle git.rs](https://github.com/radicle-dev/heartwood/blob/HEAD/crates/radicle/src/git.rs)

An object is evaluated by starting at its root change and walking dependents.
Branches with invalid signatures, or whose operation fails to apply, are pruned.
Concurrent siblings are ordered by timestamp and then by object ID.
[change_graph.rs](https://github.com/radicle-dev/heartwood/blob/HEAD/crates/radicle-cob/src/change_graph.rs)
Operations are documented as "the operation that is applied onto a state to form a CRDT".
[cob/op.rs](https://github.com/radicle-dev/heartwood/blob/HEAD/crates/radicle/src/cob/op.rs)
Built-in types include `xyz.radicle.issue` and patches.
[cob/issue.rs](https://github.com/radicle-dev/heartwood/blob/HEAD/crates/radicle/src/cob/issue.rs)
External COBs delegate evaluation to a helper program that receives the current
JSON state and an operation, borrowing git's helper-program pattern.
[cob/external.rs](https://github.com/radicle-dev/heartwood/blob/HEAD/crates/radicle/src/cob/external.rs)
That is the only extension point found where someone could plug an arbitrary
CRDT into git refs without writing a new tool.

**How close:** strong on storage, transport (Radicle's own gossip, git objects
underneath), and convergence. Scope is collaboration records, not repository
files.

### git-bug

git-bug's data model doc names operation-based CRDTs as its answer to merge
conflicts. Each edition is an `OperationPack` blob referenced by a tree and a
commit, under `refs/<namespace>/<id>`.
Wall-clock time is treated as unreliable. Lamport clocks are serialized into
tree entry names such as `create-clock-4`. Merging concurrent editions creates
a merge commit in the entity's DAG. Operations are ordered by DAG structure,
then Lamport clock, then the lexicographic order of the pack identifier.
[git-bug data model](https://github.com/git-bug/git-bug/blob/HEAD/doc/design/data-model.md)
Latest release v0.11.0 was published 2026-09-22.
[git-bug releases](https://github.com/git-bug/git-bug/releases/latest)

**How close:** same as COBs, for bugs only.

### git-meta (GitButler's metadata proposal)

git-meta is a spec and reference implementation of "a generic metadata system
for Git projects", written for the GitButler tool, with interest from Jujutsu
and git. Targets are commits, change IDs, paths, branches, and the project;
values are strings, lists, or sets. Local state lives in SQLite under `.git`.
Sharing serializes it into a tree committed to `refs/meta/local/main`, which
peers fetch into `refs/meta/remotes/main` and materialize.
[git-meta README](https://github.com/git-meta/git-meta/blob/HEAD/README.md)

Merge behavior comes from tree layout. Each value is its own tree entry, so
concurrent writes to different keys merge as file additions do. Lists use
`<timestamp-ms>-<content-hash-prefix>` entries so concurrent appends never
collide. Deletion uses explicit tombstones. Concurrent string updates are
last-writer-wins, defaulting to `ours`. On a non-fast-forward push the client
re-merges and retries until the push fast-forwards, keeping history linear.
[strings.md](https://github.com/git-meta/git-meta/blob/HEAD/spec/exchange-format/strings.md),
[lists.md](https://github.com/git-meta/git-meta/blob/HEAD/spec/exchange-format/lists.md),
[materialization.md](https://github.com/git-meta/git-meta/blob/HEAD/spec/exchange-format/materialization.md)

The README and the spec disagree on one rule. For baseless two-way merges the
README says local values win, while the canonical spec says remote wins.
[README](https://github.com/git-meta/git-meta/blob/HEAD/README.md),
[materialization.md](https://github.com/git-meta/git-meta/blob/HEAD/spec/exchange-format/materialization.md)

**How close:** works with any git server (protocol v2) and needs no user
resolution. It is state-based LWW/OR-set style rather than a full CRDT library,
and it covers metadata only.

### git-appraise

Reviews are git notes under `refs/notes/devtools/*`, one JSON item per line, so
that git's built-in `cat_sort_uniq` notes merge strategy can merge them
automatically. [git-appraise README](https://github.com/google/git-appraise/blob/HEAD/README.md)
That makes each note a grow-only set of lines. The last push was 2023-08-12.

### Dolt with a git remote

Since v1.81.10, Dolt can use a git repository (GitHub, GitLab, any SSH/HTTPS
server; not Bitbucket) as a Dolt remote. Dolt's data goes under the ref
`refs/dolt/data` by default.
[Dolt remotes reference](https://github.com/dolthub/docs-2/blob/HEAD/site/dolt/src/content/reference/sql/version-control/remotes.md),
[DoltDataRef in source](https://github.com/dolthub/dolt/blob/HEAD/go/store/blobstore/git_refs.go),
[DoltHub announcement](https://www.dolthub.com/blog/2026-02-13-announcing-git-remote-support-in-dolt/)
Merges are cell-level. A conflict arises only when both sides change the same
row and column to different values. JSON cells merge per key.
[Dolt conflicts](https://github.com/dolthub/docs-2/blob/HEAD/site/dolt/src/content/concepts/dolt/git/conflicts.md)
Beads, the agent issue tracker, uses this as its cross-machine sync path
(`bd dolt push` / `pull` against `refs/dolt/data`).
[Beads README](https://github.com/steveyegge/beads/blob/HEAD/README.md)

**How close:** git is only transport and blob storage for an opaque database.
Same-cell edits still conflict, so this is not CRDT convergence. It does show
that a non-git data model can ride git hosting today.

## Layer 2: CRDT merge of file content

### Beagle and libdog

Beagle presents itself as "100% git-compatible" and says it uses git's storage
model and sync protocol unchanged.
[Beagle README](https://github.com/gritzko/beagle/blob/HEAD/README.md)
Its primitives live in libdog. libdog lists Ragel tokenizers for about 60
languages, git object formats and sync protocol, and "CRDT weave
diff/merge/blame (RGA/CausalTree like)". Its author calls fast tokenization the
"critical finding in applying CRDTs to the git data model": blobs can be parsed
on read, so Causal Tree logic applies to ordinary git blobs.
[libdog README](https://github.com/gritzko/libdog/blob/HEAD/README.md)

The author's posts set out the claims and the limits:

- "All the diffing, blaming and merging is now token-level CRDT over git-stored
  blobs." The granularity is coarser than character-level editors and finer
  than lines. Pushing and pulling to github.com works, but "as long as I do my
  merges locally, it is all CRDT."
  [crdt.html](https://github.com/gritzko/replicated.live/blob/master/blog/crdt.html)
- Merge uses the chronofold (CT/RGA) structure. Two concurrent inserts that
  touch can fuse into one syntactic token, and Beagle marks that case as a
  conflict. Semantic validity is never guaranteed. Map-like fields edited
  concurrently can yield garbage such as `Key: Value1Value2` unless the parser
  normalizes them. [crdt.html](https://github.com/gritzko/replicated.live/blob/master/blog/crdt.html)
- He argues against a separate CRDT metadata store (git-bug, COBs, git-meta)
  and for keeping metadata as Markdown or code annotations, since "with
  Beagle, every text file is effectively a CRDT." He classifies COBs as
  op-based and git-meta and Beagle as state-based.
  [meta.html, 2026-08-31](https://github.com/gritzko/replicated.live/blob/master/blog/meta.html)

The chronofold structure comes from Grishchenko and Patrakeev's paper.
[Chronofold, arXiv:2002.09511](https://arxiv.org/abs/2002.09511)

**How close:** the nearest to the goal. Weaknesses: one author, a custom
JavaScript runtime (JAB), a TUI-first workflow, and convergence only when every
participant merges with Beagle. The README and posts say tokens are parsed from
plain blobs on read, with no stored AST or CRDT sidecar. A stock `git merge` by
a collaborator would therefore fall back to git's line merge. That last point
is an inference from the posts, not a tested behavior.

### Git merge drivers

Git lets `.gitattributes` assign a merge driver per path. The built-in `union`
driver keeps lines from both sides instead of conflict markers. The docs warn
that it "tends to leave the added lines in the resulting file in random order"
and the user should verify.
[gitattributes](https://github.com/git/git/blob/HEAD/Documentation/gitattributes.adoc)
That is the poor man's G-Set merge used by git-appraise above.

Mergiraf is a syntax-aware driver built on tree-sitter. If a line merge is
clean it returns it unchanged. Otherwise it attempts a tree merge, and it errs
toward conflict markers in tricky cases. It needs `diff3` conflict style and
can be used from Jujutsu via `jj resolve --tool mergiraf`.
[Mergiraf introduction](https://mergiraf.org/),
[usage](https://mergiraf.org/usage.html)
It reduces conflicts but does not promise convergence.

`reconcile-text` merges three-way text with an OT-inspired algorithm that always
produces a result with no conflict markers. The README states the trade-off:
for human prose, an imperfect sentence beats conflict markers. Code and legal
text need more care.
[reconcile README](https://github.com/schmelczer/reconcile/blob/HEAD/README.md)
Wired in as a git merge driver, this would give "never stops" without CRDT
metadata, but it is not order-independent across many replicas. That is an
inference; the README does not claim it.

No published Automerge or Yjs git merge driver was found in GitHub repository
searches for "crdt merge driver git" and "automerge git".

### Manyana (not git-backed)

Bram Cohen's Manyana is a CRDT demo for version control. "Merges never fail and
always converge to the same result." Concurrent edits that are "too near" each
other (adjacent, or separated only by whitespace lines) are shown as
conflicts. It never interleaves two blocks inserted at the same point. State
size is linear in every line ever present.
[Manyana README](https://github.com/bramcohen/manyana/blob/HEAD/README.md)
It operates on single files and has no git integration. It matters because it
shows the same weave idea as Beagle, at line granularity, without a git layer.

## Layer 3: live CRDT sessions that publish to git

### Gitbin

An Obsidian plugin that syncs vaults through any git host, with "concurrent
text edits merged automatically".
[Gitbin README](https://github.com/thiagomajesk/gitbin/blob/HEAD/README.md)
Its ADR chooses one authoritative `main` and Yjs CRDT state to resolve
concurrent content changes. The client fetches, combines remote state with
pending local changes, materializes ordinary files, and publishes to `main`.
On a lost race it retries and never force-pushes. Control data lives under
`.gitbin`; binary files resolve atomically.
[git-and-crdts ADR](https://github.com/thiagomajesk/gitbin/blob/HEAD/docs/adrs/git-and-crdts.md)
It depends on `yjs` 13.6.33 and a forked `just-git`.
[package.json](https://github.com/thiagomajesk/gitbin/blob/HEAD/package.json)

**How close:** architecturally the cleanest "Yjs state in git, readable files on
`main`" design found. It is two weeks old with one star, so treat it as a design
reference, not a dependency.

### Aldine

A self-hosted LaTeX editor where real-time collaboration is "CRDT-based (Yjs)"
and "every project is a real git repository". It syncs to GitHub, GitLab,
Gitea, or Forgejo with branches, server-side autopush, and "conflict resolution".
[Aldine README](https://github.com/trahloff/Aldine/blob/HEAD/README.md)
Conflicts with outside commits are still resolved, not avoided, so the CRDT
covers in-editor sessions only.

### Quire

Local-first Markdown collaboration where the filesystem stays the source of
truth. Edits from vim or a mid-session `git pull` merge into the live CRDT
session "as a delta, not an overwrite". Git snapshots are optional and off by
default. [Quire README](https://github.com/heetdalsania/quire/blob/HEAD/README.md)

### chronicle

Syncs AI agent session history across machines with git as storage and
transport. Session files merge with a grow-only set union, which preserves the
append-only JSONL invariant.
[chronicle README](https://github.com/geekmuse/chronicle/blob/HEAD/README.md)
This is the simplest correct case: when data is append-only, a G-Set over lines
in git converges with no metadata.

### GitHub Next "Realtime GitHub"

The project page, read only through search excerpts, describes realtime
multiplayer rich-text editing where each branch is a room and documents are
JSON files in the repo. It acknowledges Yjs and Automerge as well-engineered
off-the-shelf options but takes "a different direction". Its stated reasons:
clients should not have to load the whole tree, branching from any edit state
should be cheap, different artifact types need different merge semantics, and
tools such as build systems and AI assistants should participate. Instead,
ProseMirror transactions are rebased, and each client transaction "produces a
new Git state on the server".
[Realtime GitHub](https://githubnext.com/projects/rtgh/)
This is central-server OT-style rebasing with git as the version store. Treat
the details as unverified until the page is read directly.

### jotgit

A 2014 prototype for collaborative editing of Markdown in a local git repo;
saving commits the files.
[jotgit README](https://github.com/jdleesmiller/jotgit/blob/HEAD/README.md)
It uses `ot.js` operational transformation, not a CRDT.
[jotgit-core package.js](https://github.com/jdleesmiller/jotgit/blob/HEAD/packages/jotgit-core/package.js)

### Teamtype (formerly Ethersync)

Peer-to-peer real-time editing of local files from any editor, described as
"the missing real-time complement to Git".
[Teamtype README](https://github.com/teamtype/teamtype/blob/HEAD/README.md)
It chose Automerge as its CRDT library.
[CRDT library ADR](https://github.com/teamtype/teamtype/blob/HEAD/docs/decisions/05-crdt-library.md)
It runs beside git rather than storing state in it.

## Git-compatible VCSs with stronger merge semantics

### Jujutsu

Jujutsu treats local and remote concurrency the same way. It keeps a
content-addressed operation log; divergent operation heads are merged by
three-way merge of the view objects, and conflicts such as a bookmark moved two
ways are recorded rather than raised. A repo can therefore be synced with
rsync or Dropbox without losing commits, though the docs warn the git backend
"is not entirely lock-free" and corruption is possible.
[jj concurrency](https://github.com/jj-vcs/jj/blob/HEAD/docs/technical/concurrency.md)
Conflicts in file content are first-class and can be committed, rebased, and
resolved later. [jj conflicts](https://github.com/jj-vcs/jj/blob/HEAD/docs/conflicts.md)
In git they appear as `.jjconflict-base-*` and `.jjconflict-side-*` directories.
[jj git compatibility](https://github.com/jj-vcs/jj/blob/HEAD/docs/git-compatibility.md)

**How close:** jj makes operations converge, which is a CRDT-like property for
repository state. File content still needs a human when edits overlap; jj just
never blocks on it.

### Pijul (not git-backed)

Pijul stores patches, not snapshots. Independent changes commute, and "for any
two changes A and B, either A and B can be applied in any order, or A depends
on B, or B depends on A". [Why Pijul](https://pijul.org/manual/why_pijul.html)
Conflicts are modeled in the repository, and a resolution is a change that
applies everywhere. [Pijul conflicts](https://pijul.org/manual/conflicts.html)
`pijul git` imports git history one way, and the 1.0 beta post says making both
conversion directions work together "is tricky".
[Pijul 1.0 beta](https://pijul.org/posts/2022-01-08-beta/)
These pijul.org claims come from search excerpts; the pages were not fetched.

### GitButler and Sapling

GitButler is a git-based client built for parallel branches and AI workflows.
[GitButler README](https://github.com/gitbutlerapp/gitbutler/blob/HEAD/README.md)
Its CRDT-relevant contribution is git-meta (above). Sapling is a
"Git-compatible source control system" used inside its developer, not supported
externally. [Sapling README](https://github.com/facebook/sapling/blob/HEAD/README.md)
Neither documents CRDT merging of file content.

## Adjacent systems that version like git but are not git

- **Ink & Switch Patchwork and Upwelling.** Patchwork explores "universal
  version control" on Automerge, using Automerge's full change history for exact
  diffs. [Patchwork notebook 08](https://www.inkandswitch.com/patchwork/notebook/2024-version-control/08/)
  Upwelling combined real-time editing with private drafts on an Automerge fork.
  [Upwelling](https://www.inkandswitch.com/upwelling/)
  Their production offshoot, Backstitch, does real-time version control for
  Godot with branches and merges, syncing through an Automerge WebSocket server.
  [Backstitch README](https://github.com/inkandswitch/backstitch/blob/HEAD/README.md),
  [sync server](https://github.com/inkandswitch/backstitch-sync-server/blob/HEAD/README.md)
  No git bridge was found among Ink & Switch or Automerge repositories.
- **automerge-repo storage adapters.** Storage is pluggable for any key/value
  store with prefix range queries. [automerge-repo blog](https://automerge.org/blog/automerge-repo/)
  First-party adapters are IndexedDB and Node filesystem.
  [automerge-repo packages](https://github.com/automerge/automerge-repo/tree/main/packages)
  Community adapters found by repository search cover Postgres, SQLite, OPFS,
  S3, Level, and others, but none use git.
- **Lix.** "Why not Git?" heads its README. Storage is memory, filesystem, OPFS,
  or S3. [Lix README](https://github.com/opral/lix/blob/HEAD/README.md)
  Overlapping edits merge automatically: different columns combine, same-column
  edits take the incoming value, and "last" means server acceptance order, not
  client timestamps. [Lix branching](https://github.com/opral/lix/blob/HEAD/docs/branching.md),
  [collaboration and sync](https://github.com/opral/lix/blob/HEAD/docs/collaboration-and-sync.md)
- **Irmin.** A git-like OCaml database with fully automated conflict handling.
  `irmin-git` writes a git-inspectable format, and users define custom merge
  functions. [Irmin README](https://github.com/mirage/irmin/blob/HEAD/README.md)
  The verified mergeable types appear in the Peepul paper.
  [arXiv:2203.14518](https://arxiv.org/abs/2203.14518)
  Irmin is the oldest serious "mergeable data types stored in git format"
  system. It is a library for application data, not a working-tree sync tool.

## Baseline: auto-sync without CRDTs

- **Legit** wraps git as a filesystem SDK; every write is a commit. Its sync
  docs say the merge driver "prefers remote changes (theirs)" and call the
  strategy "basic". [Legit sync API](https://github.com/Legit-Control/monorepo/blob/HEAD/website/src/app/docs/api/sync/page.mdx)
  In code, the driver returns the whole remote file whenever both sides changed it.
  [createLegitSyncService.ts](https://github.com/Legit-Control/monorepo/blob/HEAD/packages/sdk/src/sync/createLegitSyncService.ts)
  Despite the "real-time collaboration" framing, it is auto-commit with
  whole-file LWW.
- **SparkleShare** resolves `UU` (both modified) and add/add conflicts by taking
  the server's version and saving the local one as a timestamped copy.
  [Git.Repository.cs](https://github.com/hbons/SparkleShare/blob/HEAD/Sparkles/Git/Git.Repository.cs)
- **git-annex** sync and assistant resolve conflicts automatically by renaming
  sides to `foo.variant-XXXX`, naming them deterministically from data in git
  so every replica resolves identically.
  [automatic conflict resolution](https://git-annex.branchable.com/automatic_conflict_resolution/),
  [git-annex-resolvemerge](https://git-annex.branchable.com/git-annex-resolvemerge/)
  That is convergent (multi-value-register style) but leaves the human merge for
  later.
- **simonthum/git-sync** fast-forwards or rebases. When the rebase fails,
  "you'll need your git skills".
  [git-sync README](https://github.com/simonthum/git-sync/blob/HEAD/README.md)
- **gitwatch** only watches and commits.
  [gitwatch README](https://github.com/gitwatch/gitwatch/blob/HEAD/README.md)
- **Obsidian Git** shows conflicts in the editor with keep-ours, keep-theirs,
  or keep-both buttons. [obsidian-git README](https://github.com/Vinzent03/obsidian-git/blob/HEAD/README.md)

## Gaps and open questions

- **Beagle's real behavior is unmeasured.** Its CRDT guarantees, conflict rate,
  and interaction with collaborators who use stock git have not been tested
  here. The posts are the author's claims.
- **Unread primary pages.** The GitHub Next Realtime GitHub page and pijul.org
  manual pages were known only through search excerpts, because direct fetch
  is denied on this machine. Their sections above are marked accordingly.
- **Kleppmann's Automerge version-control talk.** A 2022 talk titled
  "Automerge: CRDTs meet version control" appeared in search results
  ([talk page](https://martin.kleppmann.com/2022/03/28/rainbowfs-workshop.html))
  but was not read, so no claims are drawn from it.
- **No Automerge/Yjs git merge driver** turned up. A driver that stores CRDT
  history in a sidecar (as Gitbin does in `.gitbin`) and regenerates files
  appears to be an open niche. That is an inference from the search, not proof
  of absence.
- **Mergiraf, Pijul, and Sapling activity** were not measured; their rows say so.
- **Not surveyed:** Codeberg and SourceHut beyond Mergiraf, Reddit,
  lobste.rs threads (seen only as search results), and the Radicle network itself.

## Handoff: follow-up research

This section is for a fresh agent continuing the work with no other context.
It covers the [goal](#goal-this-research-serves) above. Every item below is a
lead to verify against primary sources, not a finding. The library names come
from the coordinating agent's background knowledge, which may be out of date.

### What this pass did not search

- **Building blocks.** The survey asked "does something already do this?" It
  did not evaluate CRDT engines, git implementations, or binding toolchains as
  components for a new library.
- **Sources.** Reddit, lobste.rs threads (seen only as search titles),
  Codeberg, SourceHut, the Radicle network, crates.io, Zig package indexes,
  academic indexes (arXiv, ACM, PaPoC workshop proceedings), and non-English
  sources.
- **Unread pages.** Kleppmann's 2022 talk, the GitHub Next Realtime GitHub
  page, and the pijul.org manual. Direct fetch was denied on the machine. Use
  `gh api` for GitHub content, and search snippets or a browser route for the
  rest.
- **Hands-on checks.** Nothing was installed or run, including Beagle.

### Next searches, in priority order

1. **CRDT engines with a Rust core and existing bindings.** Check Automerge
   (Rust core; check automerge-swift, automerge-go, automerge-py, and the
   wasm/JS packages), Yrs/y-crdt (yffi C ABI, pycrdt, ywasm, and any Swift
   package), Loro (check its Swift and Python bindings), and diamond-types. For
   each, record:
   - binary size;
   - whether it is `no_std` or wasm-friendly;
   - its file/tree model, including moves and renames;
   - how it compacts history;
   - whether the save format is stable;
   - which bindings are first-party versus community-maintained;
   - the maintenance date.
2. **Git implementations that can be embedded in-process.** iOS cannot shell
   out to `git`, so the library needs smart-HTTP or SSH fetch and push in
   process. Check gitoxide (`gix`) push support and its current status, and
   git2-rs over libgit2 (C dependency, licensing, iOS build). For Zig, check
   whether anything native exists beyond wrapping libgit2.
3. **Binding toolchains.** Check:
   - UniFFI for Swift, Kotlin, and Python, plus the third-party
     `uniffi-bindgen-go`;
   - Diplomat;
   - cbindgen with a C ABI for Go via cgo;
   - napi-rs versus wasm-bindgen for TypeScript;
   - how the result ships to Swift as an XCFramework or SwiftPM binary target.
   Tauri is itself Rust, so a Rust core can ship as a Tauri plugin: a plain
   crate on the Rust side plus a generated TypeScript API for the webview.
   Check Tauri v2's plugin model, including its iOS and Android support. A Zig
   core would need a C ABI and a Rust wrapper crate first. Look
   for one real Rust library that already ships Swift, Go, Python, and TS
   bindings from a single core, and copy its build pipeline. Candidates to
   check: Automerge, Loro, and Mozilla application-services.
4. **How CRDT state maps onto git.** Compare these designs:
   - a sidecar ref (Radicle's `refs/cobs/...`, git-bug);
   - a sidecar file on the branch (Gitbin's `.gitbin`);
   - CRDT metadata derived from plain blobs (Beagle/libdog);
   - a git merge driver that rebuilds files from CRDT state.
   Questions to answer:
   - How does each handle push races? Gitbin retries; nothing found uses
     force-push.
   - How fast does history grow, and how is it compacted?
   - Does it survive collaborators who use stock git?
   - Does git's signing and authentication carry over to the CRDT state?
5. **Prior work on directory trees.** Look for file-tree CRDTs that support
   moves and renames, such as Kleppmann et al.'s move operation for replicated
   trees, and how Patchwork, Lix, and Manyana handle trees.
6. **Dolt or doltlite as the substrate.** [Dolt](#dolt-with-a-git-remote)
   already rides git remotes (`refs/dolt/data`) with cell-level merge. Assess
   whether the library could store files or CRDT ops as Dolt rows instead of
   inventing a git layout. Questions to answer:
   - Can a conflict-free schema get CRDT-like convergence on top of Dolt's
     merge? One option is append-only op rows keyed by (replica, counter),
     so that no two writers touch the same cell.
   - Dolt is written in Go. What does that cost in binary size and embedding on
     iOS and in Tauri, and does it break the Rust/Zig requirement?
   - What is doltlite exactly? Confirm its owner, language, embedding story,
     and whether it supports git remotes. This pass did not look at it, so
     verify it from primary sources before relying on it.
7. **Hands-on prototype.** Clone Beagle/libdog and Gitbin, run a two-replica
   concurrent edit through a plain git remote, and record conflict behavior.
   This turns the author claims in the sections above into observations.

### Decisions still open

- Rust or Zig. Every binding route and git implementation found so far leans
  Rust; a Zig choice probably means wrapping libgit2 and writing the C ABI by
  hand.
- File scope: text-only CRDT merge versus every file type. Binary files need a
  last-writer-wins or keep-both policy.
- Whether readable files on a normal branch are a hard requirement, so that
  plain git users can still read and edit the repo.

### Suggested skills

- `search` to retrieve evidence, including code search over GitHub and crates.io
  routes.
- `research` or `deep-research` to write cited follow-up findings back into
  this document or a sibling research doc.
- `ask` to read version-matched source and docs for Automerge, Yrs, Loro, gix,
  and UniFFI.
- `prototype` for the two-replica git-remote experiment.
- `codebase-design` and `doc-coauthoring` once the work moves from research to
  a library design or plan.
- `document-lifecycle` when this doc's status changes or a plan consumes it.

## Search receipt

```text
Search: partial · 48 fetched → 48 unique → 2 inspected → 4 selected
Providers: github-repos 30 (success); hn 18 (success); host-web 3 (success)
Selection: Task fit (CRDT-style convergence on top of git) -> primary-source inspection -> maintenance; popularity unused
Trace: /Users/prungta/.local/state/agent-search/runs/2026-10-19/db2526ba5fd14b9c99a57c756c6c81b8/state.json
Coverage: English only; GitHub, HN, and general web. Paid web providers (Serper, Brave, Exa, and others) skipped for missing credentials; SearXNG/Degoog unconfigured; Startpage/DDG browser routes not declared.
```

The engine run supplied discovery (GitHub repository search, HN Algolia, one
host WebSearch) and HN item reads. It surfaced Beagle and libdog, the author's
posts, Aldine, Quire, chronicle, and reconcile. Most primary sources were then
read outside the engine's budget:

- **Read through `gh api`:** READMEs, docs, and source for Radicle Heartwood,
  git-bug, git-meta, git-appraise, Beagle, libdog, the replicated.live blog
  source, Dolt, the Dolt docs, Beads, Gitbin, Aldine, Quire, chronicle,
  reconcile, Irmin, Manyana, jotgit, Jujutsu, Lix, Legit, Backstitch,
  automerge-repo, Teamtype, SparkleShare, gitwatch, git-sync, Obsidian Git,
  GitButler, Sapling, and git's `gitattributes` docs.
- **Seen through host WebSearch excerpts:** GitHub Next Realtime GitHub, Ink &
  Switch Patchwork and Upwelling, Pijul manual pages, Mergiraf docs, git-annex
  docs, the DoltHub announcement, the Legit site, and Kleppmann's talk page.
- **Failed:** direct fetches of githubnext.com and other non-GitHub pages
  (`curl`/WebFetch denied by policy). Bare `gh api repos/sparkleshare/sparkleshare/readme`
  404'd; the project lives at `hbons/SparkleShare`. `dolthub/docs` is not
  public; the docs source is `dolthub/docs-2`.
