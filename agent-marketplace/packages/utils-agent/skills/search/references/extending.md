# Extension ownership

Load this when adding a source/provider or deciding whether to create a domain
skill. Ordinary queries do not require this guide.

| Observed need | Smallest owning change |
| --- | --- |
| Existing route lacks a credential/tool/host binding | Environment configuration; no code rewrite |
| Another site is searchable through an existing provider | `scripts/searchlib/contracts.py` source declaration, domain filter and identity rules as needed |
| A new API/CLI protocol | Add metadata to the adapter's `SPECS` list under `scripts/searchlib/adapters/`; `registry.py` assembles those lists |
| New browser result markup | Parser in the host adapter; browser runtime/session ownership remains in sibling `browser` |
| Evidence needs source-specific checks | Relevant area reference; link a separate source reference only when substantial |
| Shared execution, limits, health or identity behavior | Engine/contract/identity module |
| Recurring domain intent with its own decisions or output | Specialized skill consuming prepared jobs |

An adapter owns its operations, sources, filters, credential/tool prerequisites,
upstream, cost/retention policy and native dialect. The registry assembles this
metadata. Do not maintain a parallel provider list in prose. Existing adapters
may serve many sources; a new site is not automatically a new adapter or skill.

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
reusable evidence checks, common relevance selection and durable diagnostics. `skills-searcher`, for example, supplies SKILL.md
queries and interprets frontmatter, narrow task fit, authorship and installability. A literature-review skill could
add paper-selection criteria and synthesis while reusing retrieval. A provider
name, site filter or saved query alone does not justify a skill.

Use the sibling CLI (`../search/scripts/agent-search` from the consumer skill),
versioned prepared jobs and results. Do not import private implementation helpers
or duplicate HTTP/subprocess/retry logic. Declare the sibling package dependency;
keep missing sources optional. Generic improvements belong back in search.

After an authorized extension, run the host project's package validation and
the portable contract tests:

```sh
python3 -m unittest discover -s tests -v
```

That command is relative to this skill directory. A passing contract suite proves
behavior under fixtures; it does not establish current source health or relevance.
