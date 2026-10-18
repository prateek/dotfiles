# Adopt one authoring folder

Pin the complete folder with the repo's existing dependency mechanism. Use an
immutable accepted source revision or a verified artifact. The folder contains
all required workflow references; research, prose, and lifecycle plugins remain
optional. Local formats, paths, and exceptions belong in adopter instructions.
Change shared behavior upstream, then update the whole dependency.

## Declare the owner

Place an explicit pointer in the repo instructions the client loads before the
task, such as `AGENTS.md` or `CLAUDE.md`. Resolve the path from the repo root.
For example:

> For substantial document creation, implementation planning, or revision that changes what a reader should do, the pinned authoring owner is `vendor/doc-coauthoring/SKILL.md`. Resolve conflicting declarations using the client's instruction precedence; if none wins, report the conflict and leave authoring pending. Read the selected entrypoint and wait for its complete result. On a failed read, stop tool use and report the declared path with authoring pending. Then follow that copy, resolving each reference from the file that links it. Repository formats and document ownership remain local.

Verify that the declaration reaches the agent before its first tool choice. A
file on disk is insufficient when the client's settings suppress instruction
loading. Enable the client's repository-instruction support. If that is unavailable,
supply the declaration as startup context or complete a separate instruction-read
turn before starting the authoring task. Record that fallback as explicit loading,
not automatic discovery. The unread skill cannot order its own first read.

Any directory name is valid, including `docs/authoring/SKILL.md`. This is an
authority declaration, not merely a mention. The declaration carries the bootstrap stop rules because they must apply before
the entrypoint is available. Its [authority step](../SKILL.md#select-the-authoring-owner)
provides corresponding checks for catalog and explicit invocations. Direct reading
works without plugin discovery.
An installed description helps discovery but cannot enforce the declaration.

## Vendor when no dependency mechanism exists

Copy to an absent `vendor/doc-coauthoring/` path. Keep a sibling
`vendor/doc-coauthoring.receipt/` containing:

- `provenance.md` with the source repository, full commit and skill subdirectory,
  or the verified artifact identity and digest.
- `SHA256SUMS` generated from that accepted source before copying. It includes
  every regular file, including hidden files, with paths relative to the skill root.

The receipt belongs to the adopter and stays outside the copied folder. It is
not a second authoring policy or a new publisher provenance database.

The bundled `evals/` directory contains test data, including example agent
instructions and unfinished plans. Keep it in the verified copy, but exclude
its contents from the adopter's instructions and current-work searches.

Use Bash and the ordinary `find`, `shasum`, `sort`, and `cmp` commands. Define this
helper before either procedure below. It rejects symlinks and other non-regular
payloads, including a symlink used as the folder root.

```bash
authoring_manifest() (
  set -euo pipefail
  if [ ! -d "$1" ] || [ -L "$1" ]; then
    printf '%s\n' 'Expected a real skill directory' >&2
    exit 1
  fi
  cd "$1"
  if [ ! -f SKILL.md ] || [ -n "$(find . ! -type f ! -type d -print -quit)" ]; then
    printf '%s\n' 'Expected SKILL.md and only regular files/directories' >&2
    exit 1
  fi
  find . -type f -exec shasum -a 256 -- {} + | LC_ALL=C sort -k 2
)
```

Set `authoring_source` to the complete skill in the accepted source. Create the
receipt and copy the folder. The target and receipt must be absent so an old copy or its evidence cannot
be overwritten.

```bash
(
  set -euo pipefail
  authoring_source=/path/to/accepted/skills/doc-coauthoring
  authoring_target=vendor/doc-coauthoring
  authoring_receipt=vendor/doc-coauthoring.receipt
  test ! -e "$authoring_target"
  test ! -L "$authoring_target"
  test ! -e "$authoring_receipt"
  test ! -L "$authoring_receipt"
  mkdir -p "$authoring_receipt"
  authoring_manifest "$authoring_source" > "$authoring_receipt/SHA256SUMS"
  cp -R "$authoring_source" "$authoring_target"
)
```

Write the verified source identity into `provenance.md`. Checksums establish agreement with that source, not who
published it; establish source identity through the existing acquisition process.

## Verify the complete copy

From the adopter repo root, after defining the helper, run:

```bash
(
  set -euo pipefail
  authoring_check=$(mktemp)
  trap 'rm -f -- "$authoring_check"' EXIT
  authoring_manifest vendor/doc-coauthoring > "$authoring_check"
  cmp vendor/doc-coauthoring.receipt/SHA256SUMS "$authoring_check"
  cd vendor/doc-coauthoring
  shasum -a 256 -c ../doc-coauthoring.receipt/SHA256SUMS
)
```

Comparing the complete regenerated manifest detects extra and missing paths as
well as changed bytes. `shasum -c` alone does not detect extra files. An intact
copy passes; a changed file, removed file, extra hidden file, or symlink fails.
These commands are adoption checks, not runtime authoring requirements.

For an update, prepare a fresh copy and receipt from the new accepted source,
verify them, review the complete diff, then replace the dependency and receipt
together using the repo's normal workflow. Preserve local templates and exceptions
outside the dependency. Recheck the pointer after a path change.

## Check a clean adopter

Create a temporary repo with only the copied folder, the declaration, local format
instructions, and ordinary agent tools. Confirm the declaration's startup delivery,
then create and revise a plan without naming the skill in the task. Check that the
entrypoint's complete result arrives before the agent schedules workflow-reference
reads, that references stay inside the folder, and that the output follows the
local format. Exercise missing and conflicting declarations using the entrypoint's
rules.

Test catalog discovery separately in an isolated client profile, with its actual
catalog recorded. Run a task without naming a skill, then with a declared pin and
a deliberately different catalog copy. Record loaded paths and outputs. Keep the
daily installation unchanged. Unsupported discovery remains unverified; direct
file access cannot establish it.
