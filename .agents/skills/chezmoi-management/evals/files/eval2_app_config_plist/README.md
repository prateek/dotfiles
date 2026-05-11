# Eval 2 Fixture: Plist Template Literal Escaping

Simulated state: a chezmoi plist fragment in `home/.chezmoitemplates/com.example.geo.plist.tmpl`.

The file mixes legitimate Go template directives (`{{ .chezmoi.username }}`, `{{ .chezmoi.hostname }}`) with literal Moom-style geometry placeholders (`{{width}}x{{height}}+0+0`) that the app itself interprets at runtime.

As written, `chezmoi execute-template` will fail because `width`, `height`, `topleft`, etc. are not template variables.

Expected fix: escape the literal `{{`/`}}` pairs (backtick literal form preferred for whole-string clarity), preserving the chezmoi-owned `{{ .chezmoi.* }}` directives.
