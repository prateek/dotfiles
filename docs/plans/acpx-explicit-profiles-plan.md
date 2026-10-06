---
status: archived
doc_type: plan
created: 2026-10-05
updated: 2026-10-05
closed: 2026-10-05
current_guidance: ../references/acpx-routing.md
related:
  - ../adr/0045-acpx-explicit-model-profiles.md
status_detail: "Implementation complete, independently reviewed, and locally validated. Source publication follows the landing workflow; host activation is a separate follow-up."
---

# ACPX explicit profiles

Replace automatic generation/tier/effort selection with the profiles accepted
in [ADR 0045](../adr/0045-acpx-explicit-model-profiles.md). Preserve machine route
policy, full advertised launch IDs, environment sanitization, ownership,
retirement, and deterministic publication.

## Work

- [x] Declare current, previous, writing, and escalation profiles in model data.
- [x] Resolve exact targets and efforts; retain anchored previous-generation
  selection for Gemini and reject unavailable requests.
- [x] Update the routing reference and published ACPX skill; bump utils-agent.
- [x] Exercise the real rendered-policy/CLI seam with catalog fixtures,
  including ownership, route exclusions, exact launch settings, and failures.
- [x] Validate package builds and documentation; run an independent sub-agent
  review and address its findings. The review found no actionable issues.
- [x] Prepare the reviewed source for landing; the landing workflow owns source
  publication and the read-only post-landing chezmoi preview.

Host applies, adapter upgrades, and inference calls are separate follow-ups.
The existing skill-rewrite flow's run-local model overrides retain their own
explicit model/effort contract.

## Validation and limits

The 34 focused ACPX, Crit, and machine-policy tests passed, as did all 51
marketplace tests and repeated artifact builds, 38 docs-lifecycle tests, and
chezmoi apply previews for ci, personal, work, and devbox. The reviewer
independently passed 31 routing/machine tests and found no actionable issues.

Existing ownership, launch, exclusion, and failure guarantees remain covered.
Automatic GPT generation/tier selection and effort stepping were deliberately
replaced by exact-profile assertions; numeric generation and highest-tier
selection remain covered for previous Gemini.

Prompt-free discovery on personal-mbp found that the installed Codex and
Claude adapters do not yet advertise GPT-6/6.1 and Opus 5.5. The same catalogs
resolve Opus 5 medium, Fable 5.1 medium, and Gemini 3.8/3.7 Flash high. These are
local availability observations, not inference results. The new source is not
applied by this change; adapter/catalog freshness is an activation prerequisite.
