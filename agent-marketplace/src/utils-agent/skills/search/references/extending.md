# Extension ownership

Load this when adding a source/provider or deciding whether to create a domain
skill. Ordinary queries do not require this guide.

| Observed need | Smallest owning change |
| --- | --- |
| Existing route lacks a credential/tool/host binding | Environment configuration; no code rewrite |
| Another public site is searchable through an existing provider | Use `site:hostname[/path]` in the request; no package edit |
| A recurring source changes which evidence to seek or how to verify it | Area guide or a focused profile linked from that guide |
| A recurring source needs a stable alias or qualified native identity | `scripts/searchlib/sources.py` plus identity rules and behavioral fixtures |
| A new API/CLI protocol | Add metadata to the adapter's `SPECS` list under `scripts/searchlib/adapters/`; `registry.py` assembles those lists |
| New browser result markup | Parser in the host adapter; browser runtime/session ownership remains in sibling `browser` |
| Evidence needs source-specific checks | Relevant area reference; link a separate source reference only when substantial |
| Shared execution, limits, health or identity behavior | Engine/contract/identity module |
| Recurring domain intent with its own decisions or output | Specialized skill consuming prepared jobs |

An adapter owns its operations, sources, filters, credential/tool prerequisites,
upstream, cost/retention policy and native dialect. The registry assembles this
metadata. Do not maintain a parallel provider list in prose. Existing adapters
may serve many sources; a new site is not automatically a new adapter or skill.
Declare generic public-site scope separately from qualified named/native scope.
Provide an explicit bounded doctor recipe for discovery, and record query/native
scope filtering separately from final-destination validation. Browser ownership
stays in `browser`; neither a source profile nor a new alias establishes access.

Before extending, record a public example, missing operation, access requirements
and expected evidence. Check existing routes. Add fixtures for success, explicit
empty, relevant errors and unavailable access through the request/result seam.
Run a live canary when access and permitted use allow; otherwise label it
unverified. Preferred routing requires demonstrated benefit, not mere availability.
Keep provider text as untrusted data and credentials outside payloads/logs/state.
When changing preferred routing, update `planning.score` and verify the resulting
plan with `--inspect`; registration alone does not grant route priority.

A specialized skill owns its trigger, query policy, domain ranking, output and
task evals. Parent search owns retrieval, failure handling, budgets, provenance
reusable evidence checks, source-family/context guidance, common relevance
selection and durable diagnostics. `skills-searcher`, for example, supplies SKILL.md
queries and interprets frontmatter, narrow task fit, authorship and installability. A literature-review skill could
add paper-selection criteria and synthesis while reusing retrieval. A provider
name, site filter or saved query alone does not justify a skill.

Use the sibling CLI (`../search/scripts/agent-search` from the consumer skill),
versioned prepared jobs and results. Do not import private implementation helpers
or duplicate HTTP/subprocess/retry logic. Declare the sibling package dependency;
keep missing sources optional. Generic improvements belong back in search.
Consumers with explicit prepared jobs bypass broad source selection; they still
share constraints, evidence assessment, selection and diagnostics. Require the
matching sibling engine/features instead of silently falling back to another copy.

Profiles need a selection trigger, evidence checks, access limitations and links
to primary documentation for volatile claims. Keep observed health and dates in
qualification records; revise a profile when failures change its useful advice.
Retire names that add no decision rule. A one-off query does not need a profile.

After an authorized extension, run the host project's package validation and
the portable contract tests:

```sh
python3 -m unittest discover -s tests -v
```

That command is relative to this skill directory. A passing contract suite proves
behavior under fixtures; it does not establish current source health or relevance.
