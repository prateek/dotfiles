# UI Review Checklist

Use this after the first working build and again after proof media is wired in.

If `/Users/prateek/.agents/skills/ui-ux-pro-max/SKILL.md` exists, use that as the broader design review source. This file is the portable subset for repo-driven guideline sites, so the skill still works when that local skill is missing.

## Review Order

1. Home page
2. Getting-started page
3. One core workflow page
4. One media-heavy page

Review at one narrow mobile viewport and one desktop viewport at minimum.

## Checks That Matter For Guideline Sites

### Accessibility

- One clear `h1` per page; section headings follow a sane hierarchy
- Skip link and keyboard path reach the main content
- Focus states are visible on links, buttons, and navigation
- Meaningful screenshots, GIFs, and diagrams have alt text
- Current-page nav state is visible without relying on color alone

### Touch And Interaction

- Primary nav, side nav, and key buttons have touch-friendly targets
- Important actions do not depend on hover only
- Sticky headers or rails do not block links or headings on smaller screens

### Responsive Layout

- No horizontal page scroll at a narrow mobile width
- Long commands, code blocks, and tables are handled intentionally
- Proof sections stay legible when stacked vertically

### Motion And Media

- GIFs or videos are used as proof, not decoration
- Motion has a fallback: poster frame, transcript, captions, or reduced-motion swap
- Proof media declares dimensions or uses stable aspect ratio to avoid layout shift

### Navigation And Wayfinding

- Home, getting started, workflows, reference, and troubleshooting are distinct
- The current page is obvious in nav
- The first next step is visible above the fold on the landing page

## What To Record In The Plan Bundle

Add review-oriented `quality_gates` such as:

- Rendered responsive review
- Focus and keyboard navigation review
- Reduced-motion and media fallback review
- Screenshot/GIF alt text review

When the audit reveals meaningful fixes or tradeoffs, add an optional `ux_review` block to `site-manifest.json`.

Example:

```json
{
  "ux_review": {
    "source": "ui-review-checklist",
    "viewports": ["390x844", "1440x900"],
    "checks": [
      "skip link and keyboard order",
      "visible focus states",
      "touch-friendly nav targets",
      "reduced-motion or poster fallback for proof media",
      "no horizontal scroll on narrow pages"
    ],
    "findings": [
      "homepage used multiple h1 elements before revision",
      "proof GIFs needed static fallback frames"
    ]
  }
}
```
