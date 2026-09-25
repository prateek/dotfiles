# Observability Conventions

Use this document before creating or editing a dashboard, monitor, or
notebook, and before rolling out a change to any environment. Repository-local
guidance takes precedence.

## Artifact kinds

- A *durable* artifact is managed as code. Before building one, find how the
  neighbouring artifacts are generated and use the same path.
- A *preview* is a rendering of a durable artifact made by tooling. The tool
  may force its own location; the title rule below still applies.
- A *scratch* artifact is built by hand in the UI or API. Anything hand-built
  is scratch unless Prateek says otherwise.

## Scratch artifacts

Scratch artifacts pile up under generic names in shared folders, so give each
one a findable home and title:

- Put it in Prateek's personal scratch folder for that system. If the folder
  does not exist, ask Prateek to create it rather than creating it yourself.
- Title it `YYYY-MM-DD <1-3 word purpose slug>`, for example
  `2026-09-25 otlppb rollout`.

## Dashboard layout

- Make the top row answer the dashboard's headline question across the whole
  fleet at a glance, such as "what is rolled out, and is it healthy?". Follow
  it with rolled-up breakdowns (per tenant, per cluster) before raw series.
- Keep what a reader needs visible without scrolling. Order table columns by
  importance, most important first.
- Name panels, columns, and series for what the reader is looking at, in
  plain words rather than internal shorthand.
- Put each fact in a tooltip or description on its own line.

## Rollouts

Prateek's designated sandbox is fair game: deploy, load, and experiment there
without asking. Any rollout past the sandbox needs Prateek's explicit go-ahead
for each step, however small the change.

## Chronosphere

- The scratch folder is the `prateek-test` collection in whichever tenant the
  work is in.
- The sandbox is Prateek's test tenant.
- The rollout ladder past the sandbox is rc, then meta, then customer tenants.

## Completion

- The artifact lives where its kind says it should, and a scratch artifact
  follows the folder and title rules.
- You have viewed the rendered dashboard, through a screenshot or the browser,
  and checked it against the layout rules.
- No rollout step went past the sandbox without Prateek's go-ahead.
