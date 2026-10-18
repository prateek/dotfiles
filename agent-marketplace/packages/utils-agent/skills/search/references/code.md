# Code and repositories

Choose the operation before the provider: `repo.discover`, `code.discover`,
`issue.discover`, `repo.inspect` or `repo.commits`. Native GitHub routes take priority
for their supported operations. Search GitHub code with gh's legacy REST dialect;
GitHub website regex syntax is not portable to that API. Sourcegraph native queries
must name the `sourcegraph` dialect. MCP grep.app requires a real host binding;
the public HTTP endpoint is not an automatic substitute for a blocked MCP route.

For implementation examples, inspect the file at a revision and confirm that the
match is production code rather than a test, fixture, comment or generated file.
Keep repository, path, revision and match spans. Unknown revisions remain distinct
from pinned ones. For issues, inspect state/date and the relevant comment or fix.
Repository popularity and a matching README do not establish a working solution.

GitHub enrichment is optional and spends the same call budget as discovery.
Missing stars/commit counts stay unknown, not zero. Respect rate-limit results;
do not cycle credentials or website sessions to evade them. A browser login gate
is an access gap, not proof that code does not exist.

For installable agent skills, use sibling `skills-searcher`. It owns SKILL.md
query policy, frontmatter interpretation, author/popularity ranking and preview/
install output. It invokes the shared engine through prepared jobs; it does not
need another pass through this skill's intent routing.
