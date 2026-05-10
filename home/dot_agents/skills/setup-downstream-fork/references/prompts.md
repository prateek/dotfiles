# Resolver prompt design reference

For the skill maintainer iterating on the LLM resolver prompt. The prompt that ships into generated repos lives at `templates/fork/references/resolver-prompt.md.tmpl`. This file explains the design choices behind it so a future editor does not have to reverse-engineer them.

## System-prompt structure

Four sections, in this order. Order matters — the LLM anchors on the role first, and we want rules to be the last thing it sees before the conflict.

1. **Role.** Terse: "You are the conflict resolver for a downstream fork. Your job is to merge upstream's changes with the fork's patch intent and produce a file that builds." No personality, no praise, no "I'll do my best."
2. **Inputs.** List what the resolver will receive: (a) the file with native git conflict markers, (b) the fork contract from `.fork/AGENTS.md`, (c) the failing commit's `Fork-Patch: <slug>` + `Reason: <why>` trailers, (d) the upstream SHA before and after. Naming the inputs up front avoids the model wasting turns asking for context.
3. **Rules.** The load-bearing constraints. See "The rules" below.
4. **Output format.** Exact serialization: resolved file contents between sentinel tags, or `DESIGN_CONFLICT: <one-line reason>` inline in the file on the line where the decision should have been made. Never both. Never a chat-style explanation around the output — the calling script does a strict parse.

## The rules

Borrowed from the VoiceInk resolver and hardened after a few rounds of drift.

- **Preserve fork intent.** The `Reason:` trailer is authoritative about why the patch exists. If upstream's change makes the patch redundant, say so via `DESIGN_CONFLICT:` rather than silently dropping the patch.
- **The modify/delete grep rule.** If the conflict is "fork modified this file, upstream deleted it," the answer is almost always to let upstream's deletion win and re-apply the fork patch elsewhere only if a grep for the patch's identifying strings finds a new home. Do not re-create a file upstream intentionally removed. From VoiceInk — this single rule prevents a large class of zombie-file bugs.
- **Never invent API calls.** If the resolution requires calling a function that does not exist in either the upstream or the fork side of the conflict, emit `DESIGN_CONFLICT:` — do not fabricate.
- **Keep the fork's public surface stable.** If the fork's `Fork-Patch:` intent is "add a --quiet flag" and upstream renamed the flag-parsing library, the resolved code must still expose `--quiet`. The flag's shape is the contract; the plumbing is negotiable.
- **No formatting-only changes.** Do not reflow, reindent, or reorder imports beyond what the merge requires. The diff should be minimal.
- **Binary files: refuse.** See "Binary files" below.

## Prompt caching strategy

The bulk of each resolver invocation is the long static prose: the resolver prompt itself, the fork contract, the patch vocabulary. Per-conflict content (the file with markers, the specific trailer values) is short. Cache the big stuff, keep the small stuff uncached.

### Claude / Anthropic

Use the Anthropic SDK's `cache_control: {"type": "ephemeral"}` block on two content blocks in the system message:

1. The resolver prompt (~2–4k tokens static).
2. The fork contract from `.fork/AGENTS.md` (~1–2k tokens static per repo).

Leave the per-conflict content uncached as a third block. On a typical sync run with N conflicts, this converts N full-context charges into 1 write + (N-1) cheap reads. Measured on the smoke-test fork, this dropped per-sync resolver cost by roughly 70% at N=5.

The cache has a 5-minute TTL. Syncs that fan out many conflicts in quick succession stay in cache; syncs spread over minutes do not. If we add a patch-level preamble later (say, one block per `Fork-Patch:`), that block should also be cacheable.

### OpenAI

OpenAI's automatic prompt caching (gpt-4.1, gpt-4o and newer) triggers on prompts ≥1024 tokens with a static prefix. No explicit `cache_control` needed — the SDK handles it. Structure the prompt so the static prose comes first and per-conflict content comes last; that pattern is what the cache detector looks for. Token savings are smaller than Claude's explicit-cache case (roughly 50% on cached prefix tokens rather than ~90%), but it is free.

### Other providers

Assume no cache. Structure the prompt the same way so we are not coupled to provider-specific caching semantics. The resolver script's `LLM_PROVIDER` env var selects which SDK to invoke; prompt assembly is identical across providers.

## Binary files

Conflict markers do not work for binary files — git leaves them in the "both modified" state without markers. The resolver must detect this early (check for null bytes in the first 8KB or use `file --mime-type`) and emit:

```
DESIGN_CONFLICT: binary file conflict in <path>; both upstream and fork modified. Human review required.
```

Do not attempt to interpolate binary content. Do not ask the model to guess. Binary conflicts are always human-review.

## Token budget reasoning

Typical sync-run budget per conflict:

- System prompt (cached after first call): ~4k tokens
- Fork contract (cached): ~1.5k tokens
- Patch vocabulary (cached, from `templates/fork/references/patch-vocabulary.md.tmpl`): ~0.5k tokens
- Conflicted file (uncached): ~1–10k tokens typical, capped at 30k
- Trailers + metadata (uncached): ~0.2k tokens
- Response: ~1–10k tokens

At N=5 conflicts in a sync, with Claude explicit caching: one ~6k-token write + four ~6k-token reads + per-file variable = well under a dollar per sync on Sonnet-class models. Track this in `.fork/snapshots/<date>-<sha>.json` under `llm_resolutions[].tokens_in` and `.tokens_out` for spend audits.

Files over 30k tokens: truncate to the conflict hunks ± 100 lines of surrounding context. If the hunks themselves exceed the budget, emit `DESIGN_CONFLICT: file too large for automated resolution`.

## Variants for different LLM providers

Keep the prompt body identical. Vary only:

- **Cache markers.** Anthropic: explicit `cache_control`. OpenAI: nothing (automatic). Others: nothing.
- **System vs user role.** Anthropic puts rules in `system=`. OpenAI puts them in the first `messages` element with `role: "system"`. Same content, different envelope.
- **Stop sequences.** Use the sentinel tags (`<resolved>` / `</resolved>`) as stop sequences on providers that support them. Saves a few tokens per response.

Do not fork the prompt text per provider. If one provider needs different wording to behave, that is a signal to fix the wording so all providers behave — not to maintain two prompts.

## Eval ideas for prompt iteration

A future maintainer tuning the prompt needs a corpus to measure against. Proposed shape, not yet built:

1. **Corpus.** Capture real conflicts from the first N syncs across a handful of generated forks. Each sample is `(conflicted_file, fork_contract, trailers, known_good_resolution)`. Known-good comes from either the human-reviewed PR that eventually merged or the pre-sync file plus a manually-written resolution.
2. **Regression set.** A fixed subset of the corpus the new prompt must match or improve on. Measure exact-match for trivial conflicts, and smoke-test pass-rate plus diff similarity for the rest.
3. **Adversarial set.** Hand-crafted edge cases: modify/delete conflicts, binary files, "upstream removed the patched function entirely," "fork patch is now redundant because upstream adopted the feature." Each should resolve to a specific expected outcome (most commonly `DESIGN_CONFLICT:` with a specific reason).
4. **Harness.** Run the candidate prompt against corpus + adversarial set, score, diff against the previous prompt's scores. The skill's own `evals/evals.json` is a good home for the top-level scaffolding; the corpus itself stays out of git (likely includes private fork content) in a user-local directory.
5. **Per-provider matrix.** Run each prompt change against Claude Sonnet, Claude Opus, and GPT-4-class OpenAI models. A prompt that regresses one provider but helps another is a signal to fix the prompt, not to tier providers.

Until this is built, the minimum-viable iteration loop is: pick one real conflict from a recent sync, tweak the prompt, check that the resolver still produces the same resolution (or a better one), ship. The full corpus matters once the prompt has more than one maintainer.

## Cross-references

- `templates/fork/references/resolver-prompt.md.tmpl` — the prompt that ships into generated repos. Edits to the prompt body happen there, not here.
- `templates/fork/references/patch-vocabulary.md.tmpl` — the Brave-derived `PATCH_CHANGED`/`SRC_CHANGED` enum referenced inside the prompt.
- `references/architecture.md` §LLM resolver — where the resolver fits in the broader system.
- `templates/tools/llm_resolve.py.tmpl` — the Python reference implementation; the cache-control blocks live there.
