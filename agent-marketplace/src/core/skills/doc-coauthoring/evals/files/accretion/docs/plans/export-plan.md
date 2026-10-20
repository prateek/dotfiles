# JSON export

Owner: Rowan.

## Request

Add opt-in JSON output through `--format json`. Text stays the default and its
output stays byte-identical. No new dependencies.

## Design

`parse_args` in `src/settings.py` adds `json` to the `--format` choices and keeps
`text` as the `Settings.format` default. `render_rows` in `src/report.py`
dispatches on `format`: `text` keeps the current join, and `json` returns
`json.dumps` of the row list, so the output is one array whose objects carry an
integer `id` and a string `name`, and no rows produce `[]`. Any other value keeps
raising `ValueError("unsupported format")`.

Alternative considered: a separate `render_json` function that the caller picks.
Rejected because the caller would then own format dispatch, and the existing
tests already target `render_rows`.

## Deliverables

1. The parser accepts `--format json` and still defaults to `text`.
   Prerequisite: none.
   Acceptance: `parse_args(["--format", "json"]).format == "json"` and
   `parse_args([]).format == "text"`.
2. `render_rows(rows, "json")` returns the array described in Design.
   Prerequisite: deliverable 1 fixes the format name.
   Acceptance: tests through `render_rows` for one row, several rows, and no
   rows, asserting the exact JSON text.
3. The connected path works: `render_rows(rows, parse_args(["--format", "json"]).format)`
   returns the array, and the same call with no flags returns today's text.
   Prerequisite: deliverables 1 and 2.
   Acceptance: one test that goes through both functions.

## Acceptance

`python3 -m unittest discover -s tests` passes with the new tests added to
`tests/test_report.py`. `test_default_text` and `test_rejects_unknown_format`
stay unchanged.

## Open decisions

None.
