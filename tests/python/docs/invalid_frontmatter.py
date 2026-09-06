INVALID_DOCS = (
    ('current-plan.md', """---
status: current
doc_type: plan
---

# Current Plan

A plan cannot be steady-state guidance.
""", 'completed plans must be archived or superseded'),
    ('bad-status.md', """---
status: stale
doc_type: reference
---

# Bad Status
""", 'status must be one of'),
    ('empty-status.md', """---
status:
doc_type: reference
---

# Empty Status
""", 'status must be one of'),
    ('bad-type.md', """---
status: current
doc_type: memo
---

# Bad Type
""", 'doc_type must be one of'),
    ('accepted-reference.md', """---
status: accepted
doc_type: reference
---

# Accepted Reference
""", "doc_type 'reference' cannot use status 'accepted'"),
    ('empty-type.md', """---
status: current
doc_type:
---

# Empty Type
""", 'doc_type must be one of'),
    ('no-frontmatter.md', """# No Frontmatter
""", 'missing YAML frontmatter'),
    ('no-h1.md', """---
status: current
doc_type: reference
---

No H1 here.
""", 'Markdown body must start with an H1'),
    ('closed-missing-date.md', """---
status: archived
doc_type: plan
current_guidance: ../current-guide.md
---

# Closed Missing Date
""", 'requires closed'),
    ('closed-invalid-date.md', """---
status: archived
doc_type: plan
closed: not-a-date
current_guidance: ../current-guide.md
---

# Closed Invalid Date
""", 'closed must be an ISO date'),
    ('invalid-created-date.md', """---
status: active
doc_type: plan
created: not-a-date
---

# Invalid Created Date
""", 'created must be an ISO date'),
    ('invalid-updated-date.md', """---
status: active
doc_type: plan
updated: not-a-date
---

# Invalid Updated Date
""", 'updated must be an ISO date'),
    ('open-with-closed-date.md', """---
status: active
doc_type: reference
closed: 2026-05-11
---

# Open With Closed Date
""", 'closed is only valid for archived, superseded, or rejected docs'),
    ('closed-missing-guidance.md', """---
status: archived
doc_type: plan
closed: 2026-05-11
---

# Closed Missing Guidance
""", 'requires current_guidance'),
    ('closed-empty-guidance.md', """---
status: archived
doc_type: plan
closed: 2026-05-11
current_guidance:
---

# Closed Empty Guidance
""", 'requires non-empty current_guidance'),
    ('closed-empty-inline-guidance.md', """---
status: archived
doc_type: plan
closed: 2026-05-11
current_guidance: []
---

# Closed Empty Inline Guidance
""", 'requires non-empty current_guidance'),
    ('closed-quoted-empty-guidance.md', """---
status: archived
doc_type: plan
closed: 2026-05-11
current_guidance: ""
---

# Closed Quoted Empty Guidance
""", 'requires non-empty current_guidance'),
    ('superseded-missing-target.md', """---
status: superseded
doc_type: plan
closed: 2026-05-11
---

# Superseded Missing Target
""", 'requires superseded_by'),
    ('superseded-missing-date.md', """---
status: superseded
doc_type: plan
superseded_by: ../current-guide.md
---

# Superseded Missing Date
""", 'requires closed'),
    ('superseded-empty-target.md', """---
status: superseded
doc_type: plan
closed: 2026-05-11
superseded_by:
---

# Superseded Empty Target
""", 'requires non-empty superseded_by'),
    ('broken-target.md', """---
status: superseded
doc_type: plan
closed: 2026-05-11
superseded_by: missing.md
---

# Broken Target
""", 'superseded_by target must be a repo-local relative path that exists'),
    ('broken-related.md', """---
status: current
doc_type: reference
related: missing.md
---

# Broken Related
""", 'related target must be a repo-local relative path that exists'),
    ('external-target.md', """---
status: archived
doc_type: research
closed: 2026-05-11
current_guidance: ~/dotfiles/docs/current-guide.md
---

# External Target
""", 'current_guidance target must be a repo-local relative path that exists'),
    ('anchor-only-target.md', """---
status: archived
doc_type: research
closed: 2026-05-11
current_guidance: "#current-guide"
---

# Anchor Only Target
""", 'current_guidance target must be a repo-local relative path that exists'),
    ('rejected-missing-rationale.md', """---
status: rejected
doc_type: plan
closed: 2026-05-11
---

# Rejected Missing Rationale
""", "status 'rejected' requires current_guidance or status_detail"),
    ('rejected-empty-guidance.md', """---
status: rejected
doc_type: plan
closed: 2026-05-11
current_guidance: []
---

# Rejected Empty Guidance
""", "status 'rejected' requires current_guidance or status_detail"),
    ('rejected-empty-detail.md', """---
status: rejected
doc_type: plan
closed: 2026-05-11
status_detail: ""
---

# Rejected Empty Detail
""", "status 'rejected' requires current_guidance or status_detail"),
    ('nested-frontmatter.md', """---
status: current
doc_type: reference
owner:
  name: Prateek
---

# Nested Frontmatter
""", 'unsupported nested or indented value'),
    ('block-frontmatter.md', """---
status: current
doc_type: reference
status_detail: |
  Unsupported block value.
---

# Block Frontmatter
""", 'block scalars are not supported'),
    ('duplicate-frontmatter.md', """---
status: current
status: active
doc_type: reference
---

# Duplicate Frontmatter
""", "duplicate key 'status'"),
    ('unsupported-key.md', """---
status: archived
doc_type: plan
closed: 2026-05-11
current_guidance: ../current-guide.md
skill_path: ../../home/dot_agents/skills/example/
---

# Unsupported Key
""", "unsupported frontmatter key 'skill_path'"),
)
