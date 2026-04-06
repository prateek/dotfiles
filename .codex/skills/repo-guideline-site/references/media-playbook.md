# Media Playbook

Choose media based on the product surface and the kind of proof users need.

## CLI Products

Prefer deterministic scripted captures.

Recommended stack:

- VHS or an equivalent scripted terminal recorder
- fixture repos or fixture inputs
- text snapshots for ordinary command-output flows
- OCR or frame checkpoints for TUI interactions

Required outputs:

- one hero demo for the homepage
- one “first success” demo for getting started
- workflow-specific demos for the top 2-3 P0 tasks

Avoid:

- hand-recorded demos that are hard to reproduce
- GIFs with no source tapes
- demos that show commands but not their results

## Browser Or End-User Products

Prefer scripted screenshots and short walkthroughs.

Recommended stack:

- browser automation for screenshots and short clips
- viewport matrix for desktop and mobile
- annotation overlays only when they clarify a state transition

Required outputs:

- one hero screenshot or short clip
- setup screenshots for the onboarding path
- stateful screenshots for success, error, and recovery paths

Avoid:

- very long videos
- screenshots that only show marketing chrome and no task state
- desktop-only validation when the product is often used on mobile

## Hybrid Products

Use both:

- terminal demos for the technical workflow
- browser or dashboard screenshots for the operator-facing surface

## Verification

Every media artifact should have:

- a declared source of truth
- a generation method
- a validation method

Examples:

- `terminal-demo` + `tool=vhs` + `validation=snapshot`
- `terminal-demo` + `tool=vhs` + `validation=ocr`
- `browser-screenshot` + `tool=playwright` + `validation=viewport-review`
- `screen-demo` + `tool=playwright+ffmpeg` + `validation=frame-check`

## Accessibility

Include these expectations in the plan bundle:

- alt text for screenshots and diagrams
- captions or transcript plan for videos
- reduced-motion fallback when motion is not essential
- contrast checks for code and UI overlays
