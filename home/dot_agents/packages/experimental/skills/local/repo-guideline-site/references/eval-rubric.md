# Evaluation Rubric

The evaluator scores a manifest out of 100. Use this rubric when reviewing output manually too.

## Dimensions

### Repo Comprehension: 10

- Product type is explicit
- Main surfaces are identified
- Positioning reflects the actual repo

### Audience Design: 15

- At least two meaningful audiences when appropriate
- Audience needs are explicit
- Mixed technical and non-technical needs are handled deliberately

### Information Architecture: 20

- Home page has a proof-oriented role
- Getting-started path exists
- Core workflow pages exist
- Reference and troubleshooting are separated from narrative teaching

### Workflow Coverage: 20

- Top workflows are represented
- Workflows reference repo evidence
- Setup and day-two usage are both covered

### Media Strategy: 15

- At least one proof artifact exists for the home page
- Media is matched to the product surface
- Media includes a validation method

### Implementation And Testing: 10

- Stack choice is justified
- Verification commands or gates are concrete
- Rendered-site review is recorded, not implied

### Writing And Accessibility: 10

- Tone is defined
- Plain-language adaptation exists where needed
- Accessibility expectations are present
- Heading hierarchy, focus/keyboard access, and reduced-motion/media fallback are considered
- Visual direction is intentional rather than generic

## Pass Thresholds

- `85+`: strong benchmark-quality output
- `70-84`: usable but incomplete
- `<70`: not ready

## Frequent Failure Modes

- Pages mirror the repo layout rather than the user journey
- The site has lots of reference but no “why” or “how”
- The home page lacks proof
- Media is suggested but not testable
- Non-technical audiences get developer-language onboarding
- Quality gates are generic placeholders instead of runnable checks
- No rendered UI review is recorded for responsive layout, focus states, or motion fallback
- GIF or video proof is used without poster/transcript/reduced-motion support
- Media dimensions are omitted, causing avoidable layout shift
- The site structure is solid but the visual direction is generic or indistinguishable from default docs output
