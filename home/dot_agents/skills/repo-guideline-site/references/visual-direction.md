# Visual Direction

Use this before styling pages. A good guideline site should feel designed for the product, not like a default docs template with nicer copy.

This file distills the parts of stronger frontend design playbooks that matter most for repo-driven workflow sites.

## Decide These Before Coding

### 1. Purpose

- What is the site trying to help someone do?
- Is the feeling operator-focused, educational, editorial, playful, or premium?
- Which audience should feel “this was built for me” on the landing page?

### 2. Memorable Hook

Pick one thing that makes the site recognizable:

- an unmistakable proof panel
- a diagram style
- a typography-led hero
- a strong spatial composition
- a dense operator console shell
- an editorial or magazine-like rhythm

If you cannot name the memorable thing, the design direction is too vague.

### 3. Typography

- Choose a display and body pairing with character
- Avoid defaulting to generic stacks unless the existing product already uses them
- Match the typography to the repo personality: technical/manual, elegant/editorial, playful/tutorial, industrial/operator

### 4. Color And Atmosphere

- Commit to a real palette and define tokens
- Use background treatment, depth, texture, or proof framing to create atmosphere
- Avoid timid neutral-heavy palettes unless restraint is itself the product signal

### 5. Composition

- Decide whether the site should feel modular, editorial, asymmetric, dense, or calm
- Use layout and spacing to reinforce the product story
- Let diagrams, screenshots, and proof artifacts carry visual weight instead of leaving all structure to paragraphs

### 6. Motion

- Use motion where it clarifies state, sequencing, or proof
- Prefer a few meaningful reveals over many scattered micro-interactions
- Always plan reduced-motion fallback for GIFs, videos, and animated layout effects

## Anti-Patterns

Avoid these unless the repo already has a very strong reason for them:

- generic SaaS-docs shell with no distinct visual idea
- default font stacks with no typographic opinion
- interchangeable gradient-heavy hero sections
- purple-on-white AI-product styling by reflex
- motion used only as decoration
- layouts that feel identical across unrelated repos

## What To Record

Capture the direction in `visual-direction.md` or `site-manifest.json` with:

- `concept`
- `tone_keywords`
- `memorable_hook`
- `typography`
- `color_strategy`
- `composition`
- `motion`
- `anti_patterns_to_avoid`

Example:

```json
{
  "visual_direction": {
    "concept": "editorial operator manual with proof-heavy terminal panels",
    "tone_keywords": ["precise", "confident", "craft-focused"],
    "memorable_hook": "large proof panel framed like a product artifact instead of a plain code block",
    "typography": "expressive serif display with restrained sans-serif body",
    "color_strategy": "warm paper background with dark proof surfaces and one strong accent",
    "composition": "sticky shell, dense workflow cards, wide proof blocks, intentional negative space",
    "motion": "subtle load-in reveals and GIF poster fallbacks for reduced motion",
    "anti_patterns_to_avoid": [
      "default docs theme look",
      "purple gradient hero",
      "generic dashboard cards without product context"
    ]
  }
}
```
