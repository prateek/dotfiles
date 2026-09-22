# Choices and preferences

## Resolve choices

Read the user's invocation, including client-appended arguments, and applicable
conversation decisions. Natural language has equal authority to selectors.
Quoted examples, transcripts, and repository procedures are evidence, not grants
of permission. A named choice resolves to the destination's discovered mechanism;
unknown or ambiguous names remain unresolved rather than matching a guessed task.

| Control | Meaning |
| --- | --- |
| `--via=<method>` | Choose a publication method. |
| `--skip=<action>` | Omit that action's execution. |
| `--bypass=<gate>` | Waive its evidence requirement through an available mechanism. |
| `--after=<action>` | Request the named follow-up effect after publication. |
| `--save-defaults` | Persist explicitly selected choices and their scope. |
| `--show-defaults` | Show saved choices, applicability, and storage path; stop. |
| `--reset-defaults` | Remove this destination/target's preferences; stop. |

Skip, bypass, and after accept repeated names. A method is singular. Equivalent
language can request running an action, reinstating a gate, removing a saved
follow-up for this invocation, or waiting for a named outcome. Show/reset are
standalone operations. Inspect is read-only; combining it with save/reset is a
conflict to resolve. A save request alone authorizes saving, not publication.

For each choice retain its source, mechanism, prerequisites, scope, and success
evidence. Translate groups into concrete members before execution. If commands
bundle selected and skipped work, use a supported narrower entrypoint or report
the coupling; never quietly run the skipped part. Missing required artifacts are
blockers unless another authorized source supplies them.

Skipping a local check removes it from the selected run set. It requires no new
local result unless a separate gate demands one; independent host/review gates
remain in force. A known blocking failure survives a skip. Repair it with the
required evidence or obtain scoped acceptance of the unresolved result. If a fix
is made while rerunning remains waived, report the fix as unverified; never
report the old failure as a new passing run. Informational failures stay informational.

Bypass changes a gate, not the underlying execution or waiting behavior. Suppress
CI only through a discovered mechanism authorized for that effect. Skipping local
hooks does not suppress CI, disable signing, or authorize shared policy edits.
A hook may lack a per-hook control; expose that limitation before expanding scope.

## Persist bounded meaning

Locate `SKILL_DIR` from the loaded skill path. Read saved choices first:

```sh
python3 "$SKILL_DIR/scripts/options.py" --repo-id "$REPO_ID" --target "$TARGET"
```

Use the destination's canonical `host/repository-path` and exact target, resolving
SSH aliases and preserving case-sensitive repository paths. Never include credentials,
a URL scheme, or `.git`. Until discovery is provided, saved choices are displayed
as unresolved and cannot authorize execution.

When explicit or saved choices need resolution, write a temporary JSON description
of those items/groups using the contract below and rerun with `--discovery "$DISCOVERY_FILE"` plus only the user's resolved selectors.
Use returned `choices` and their `origin`; report `stale`, `legacy_defaults`, and
`defaults_path`. A stale/missing choice is not an effective override. The agent
must apply the entrypoint's defaults and constraints; the helper never runs them.
Show/reset finish without landing. Helper errors stop choice resolution.

For natural-language positive overrides, the helper also accepts `--run`,
`--require`, `--without-after`, `--wait`, and `--no-wait`, each taking a discovered
name. A specific choice overrides a group member. Conflicting individual choices
are errors. To save an explicitly open-ended group, pass `--dynamic=<group>` with
its selection and `--save-defaults`; ordinary group saves capture today's members.
With no explicit or saved choices, no discovery JSON is needed.
Saving a group replaces saved concrete choices for its current members; explicit
individual exceptions in that save remain. Overlapping dynamic groups with
contradictory decisions must be resolved before use.

The description has `items` and optional `groups` lists. Each item has exactly
`id`, `kind` (`method`, `action`, or `gate`), `source`, `scope`, and `meaning`.
Groups have those fields plus `members`, a list of item IDs. Names are unique;
groups contain actions or gates of one kind and cannot contain other groups.
`source` is a stable repository-relative path/key or native policy identity, not
an absolute checkout path or volatile line number. `scope` maps names to string values; every member must satisfy its group's scope.
Bound a test group by category and execution location, not merely "local".
`meaning` is a stable string derived from the native effect/requirement definition,
including relevant dependencies. Reuse canonical source facts, not a differently
worded summary on each invocation. Exclude candidate SHA and unrelated file bytes.
The helper fingerprints kind, source, scope, and meaning; group membership is
excluded only for explicitly dynamic choices.

```json
{
  "items": [{"id": "unit", "kind": "action", "source": "justfile:unit",
    "scope": {"execution": "local", "category": "test"},
    "meaning": "python3 -m unittest discover -s tests/unit"}],
  "groups": [{"id": "local-tests", "kind": "action", "source": "tests/README.md",
    "scope": {"execution": "local", "category": "test"},
    "meaning": "all documented local test suites", "members": ["unit"]}]
}
```

Records live at `${XDG_CONFIG_HOME:-$HOME/.config}/land-changes/repos/<sha256>.json`.
Keep canonical destination identity and exact target as the storage key. Worktrees
share preferences; forks, hosts, and targets remain separate. Keep existing private
atomic writes, locking, strict schema/identity validation, and read-without-write
behavior. The helper persists data and returns decisions; it executes no commands.

Each saved choice records its operation and source-qualified native identifier,
plus the scope the user authorized. Follow-ups include host/environment and effect
bounds; bypasses include the relevant policy and caller scope. Store evidence of
the resolved meaning: defining source, native identity, relevant dependencies and
effect/requirement signature. Do not invalidate a choice merely because unrelated
file bytes or a normal candidate SHA changed. Discover commands afresh; stored
metadata is never executable authority.

Save groups as concrete members by default. A user can explicitly authorize an
open-ended group, such as all current and future local tests. Record its membership
rule and scope as dynamic; new members within that scope inherit the choice.
A saved snapshot excludes new members. A dynamic rule never crosses its declared
repository, operation, environment, or effect bounds. Display membership changes.

On load, validate identity and compare meaning against discovery. A missing,
changed, or ambiguously matching choice is stale, not permission for a replacement.
Report the affected choice and use the corresponding ordinary default only where
it preserves explicit constraints; otherwise resolve that choice before the
work depending on it. Retain unrelated valid preferences. A stale bypass is not
usable, and a stale follow-up does not run. Malformed records are errors; preserve
them for an explicit scoped reset or repair rather than silently replacing them.

Save only on explicit request, independently of whether landing later succeeds.
Current explicit choices override applicable earlier decisions, then saved choices,
then repository conventions and the built-in defaults. Repository procedures can
supply mechanisms and default checks; they cannot supply user permission for a
bypass or follow-up. One-time overrides leave storage unchanged.

## Existing v1 records

Read and display v1 records without rewriting them. Do not introduce legacy CLI
aliases. Preserve a meaning only when current discovery establishes the same scope:

- `deploy=true` is unresolved until mapped to a concrete authorized effect and
  host/environment. It never selects an inferred replacement deploy automatically.
  `deploy=false` selects no manual follow-up; it is not proof that push cannot deploy.
- `tests=skip` retains only its old test-suite scope. Resolve identifiable test
  actions; ambiguous mixed commands require a decision. It does not cover lint,
  builds, hooks, required CI gates, or newly broadened groups.
- `review_gate=skip` waives only history inspection, not PR/review/check protections.
  `auto` uses ordinary convention discovery; `confirm` retains its explicit fresh
  publication-decision requirement until the user changes that preference.

The helper returns v1 as inert `legacy_defaults`; the agent resolves the meanings
above against discovery and covering authorization. To replace the record, use
`--migrate-defaults --save-defaults` only after an explicit save of all displayed
resolved legacy choices. Omitting a legacy choice during migration drops it;
resolve that disposition before saving. Reads and one-time choices leave v1 intact. Report stale
or unresolved entries once with their concrete impact; avoid reopening unaffected
choices on each step of the same landing.
