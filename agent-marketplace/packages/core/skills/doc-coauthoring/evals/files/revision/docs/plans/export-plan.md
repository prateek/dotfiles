# JSON export

Owner: Rowan. User note: keep the review checklist accessible to keyboard users.

## Request
Switch the default report format to JSON and remove text output.

## Design
Change `Settings.format` and the parser default to `json`. Replace `render_rows`
with a JSON serializer. Existing callers need to migrate to JSON in the same release.

## Deliverables
1. Replace the renderer and remove the old default-text test.
2. Change parser defaults after the JSON renderer is available.
3. Migrate consumers after step 2 and remove the format option.

## Acceptance
Calling with no flags returns JSON. Text requests fail.

## Open decision
Should text remain the default for compatibility?
