# Catalog export plan

This is the current unfinished plan. Owner: Rowan.
Add opt-in JSON output while preserving the default text format.
The implementation must connect `src/settings.py` to `src/report.py`.
The existing unittest suite is the validation seam.

## Remaining decision
Choose how to encode an empty row list in JSON.
