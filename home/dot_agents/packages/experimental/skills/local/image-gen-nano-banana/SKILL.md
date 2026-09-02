---
name: image-gen-nano-banana
description: Self-contained Nano Banana skill for direct Gemini image generation and editing. Use when you want one local skill that handles Flash or Pro generation directly, while doing Kousen-style prompt rewriting instructionally in the skill rather than inside the runner.
---

# Image Gen Nano Banana

Use this skill when the user wants Nano Banana image generation or editing through a direct Gemini path that we own locally.

This skill deliberately splits responsibilities:

- `SKILL.md` handles prompt rewriting and authoring behavior
- `scripts/nano_banana_skill.py` does direct generation or editing
- no retrieval or exemplar lookup
- no runtime dependency on the benchmark reference repos

## Files

- Runner: `scripts/nano_banana_skill.py`

## Workflow

1. Decide whether the user needs prompt help or already has a good prompt.
2. If needed, do Kousen-style prompt rewriting conversationally.
3. When the prompt is ready, run the direct generator script.

Do not use a scripted `plan` flow. The prompt-authoring behavior in this skill is instructional, not encoded as a subcommand.

## Prompt Rewriting

When the user prompt is vague, underspecified, or clearly asks for help crafting the image prompt, follow the original Kousen-style approach in conversation:

1. Ask up to 2-3 targeted questions, not a giant questionnaire.
2. Fill the important missing fields:
   - subject
   - setting/environment
   - mood/atmosphere
   - style/medium
   - composition/framing
   - lighting
   - purpose/use case
   - exact text, if any
3. Write the final prompt in natural language, not keyword soup.
4. Give a short rationale for the main choices.
5. Offer one refinement pass if the user wants changes.

Use the Kousen principles directly:

- natural language over tag soup
- stronger specificity
- use-case context
- composition, lighting, and materiality guidance
- quoted text preserved exactly

Do this instructionally in the conversation, then pass the finalized prompt to the script as-is.

## When To Rewrite

Use prompt rewriting when:

- the user says “help me write the prompt”
- the request is vague or abstract
- the image needs polish for a hero, poster, mascot, or marketing-style result
- exact text, composition, or mood matter and the prompt is still thin

Skip rewriting and use the user prompt directly when:

- the prompt is already precise enough
- it is a reference-preserving edit
- grounded realism or factual fidelity matters more than reinterpretation

## Explicit No-Rewrite Mode

Users can explicitly opt out of prompt rewriting.

If the request either:

- starts with `RAW:`
- contains `[RAW]` anywhere in the request

do all of the following:

- do not ask prompt-authoring follow-up questions
- do not polish, expand, or reinterpret the prompt
- strip the `RAW:` prefix or `[RAW]` marker before sending the prompt
- pass the remaining prompt to the script verbatim

Examples:

- `RAW: A photoreal portrait of a violinist in soft studio light.`
- `A photoreal portrait of a violinist in soft studio light. [RAW]`
- `RAW: Convert this dark UI screenshot into a light theme while preserving layout.`

Treat both `RAW:` and `[RAW]` case-insensitively.

Also treat plain-language requests like `use this exactly`, `do not rewrite`, or `pass this through raw` the same way when the intent is unambiguous.

## Models

- `flash`
  - maps to `gemini-3.1-flash-image-preview`
  - best for fast iteration and default use
  - supports `512`, `1K`, `2K`, `4K`
  - supports the wider Flash aspect-ratio set including `1:4`, `1:8`, `4:1`, and `8:1`
  - supports up to 14 input images
- `pro`
  - maps to `gemini-3-pro-image-preview`
  - use when you want the higher-fidelity path
  - supports `1K`, `2K`, `4K`
  - does not support aspect-ratio overrides in this skill
  - supports at most one input image

## Auth

The runner resolves API auth in this order:

1. `--api-key`
2. `GEMINI_API_KEY`
3. `GOOGLE_API_KEY`

In this experiment repo, the local `.env` file is also read automatically.

## Commands

Generate an image directly:

```bash
skills/image-gen-nano-banana/scripts/nano_banana_skill.py \
  --model flash \
  --prompt "Friendly octopus-robot mascot sticker for a developer tool. Distinct silhouette, expressive face, polished shading, transparent background, production-usable asset." \
  --output /tmp/mascot.png
```

Reference-preserving edit:

```bash
skills/image-gen-nano-banana/scripts/nano_banana_skill.py \
  --model flash \
  --prompt "Convert this dark product UI screenshot into a polished light-theme version while preserving layout, information hierarchy, and product identity." \
  --input-image /path/to/source-ui.png \
  --filename /tmp/ui-light.png
```

High-fidelity Pro generation:

```bash
skills/image-gen-nano-banana/scripts/nano_banana_skill.py \
  --model pro \
  --prompt "Photoreal portrait of a violinist in soft studio light." \
  --output /tmp/portrait.png
```

## Rules

- Do not use retrieval or exemplar lookup with this skill.
- Do Kousen-style prompt rewriting in conversation, not in the runner.
- If the user includes `RAW:` or `[RAW]`, skip rewriting entirely and pass the prompt through verbatim after removing the marker.
- Preserve the user prompt directly when fidelity matters more than reinterpretation.
- Use `--model flash` by default and `--model pro` when the user explicitly wants the higher-fidelity path.
- `--model pro` is intentionally stricter here: no aspect-ratio override and at most one input image.
- `--filename` is supported as an alias for `--output` for compatibility with direct-style usage.
- If resolution is omitted and input images are provided, the runner auto-selects a resolution from the input size, including downshifting Flash to `512` for very small inputs.
- For exact-text tasks, keep quoted text verbatim in the final prompt, but still warn yourself that image text fidelity is imperfect.

## Output Expectations

The runner writes:

- the image file(s)
- a `.json` sidecar with model, prompt, resolution, output paths, and any auto-resolution note

That keeps the execution path direct and inspectable without embedding prompt-planning logic into the script.
