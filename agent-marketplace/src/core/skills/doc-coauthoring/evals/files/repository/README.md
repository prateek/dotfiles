# Catalog report

`python3 -m src.settings --format text` selects the output format. Text is the default.
The producer is `src/settings.py`; `src/report.py` renders rows for the caller.
Run existing checks with `python3 -m unittest discover -s tests`.
Rows have an integer `id` and a string `name`. No third-party dependencies are needed.
