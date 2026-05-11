# Eval 6 Fixture: Assets vs Templates (Literal JSON)

Simulated state mirrors the real VoiceInk pattern in the dotfiles repo:

- `home/.chezmoitemplates/voiceink-prompts.json` — a raw JSON payload with literal `{{user_input}}`, `{{ context }}`, `{{ tone }}` placeholders that VoiceInk fills at runtime. NOT a chezmoi template; the JSON has no chezmoi-side dynamic content.
- `home/.chezmoitemplates/com.prakashjoshipax.VoiceInk.plist.tmpl` — the plist fragment. It includes the JSON as a base64-encoded `<data>` value for the `customPrompts` key. **This is the broken file**: it currently uses `{{ includeTemplate "voiceink-prompts.json" | b64enc }}`, which evaluates the JSON as a Go template (resolving `user_input`, `context`, `tone`) before encoding — that fails or emits empty strings.
- `home/Library/private_Preferences/modify_private_com.prakashjoshipax.VoiceInk.plist.tmpl` — the standard 3-line modify_ stub (`template prelude`, `includeTemplate fragment | b64enc`, `template postlude`). This file is correct as-is and should NOT be edited.

Expected behavior:
- Agent identifies the bug is in the plist fragment, NOT the modify_ stub. The stub follows the standard 3-line contract; changing it would break the modify_ pattern.
- Agent picks one of two valid fixes for the fragment:
  1. Move JSON to `home/.chezmoiassets/voiceink-prompts.json` and use `{{ include ".chezmoiassets/voiceink-prompts.json" | b64enc }}` in the fragment.
  2. Keep JSON under `home/.chezmoitemplates/` and use `{{ include (printf "%s/.chezmoitemplates/voiceink-prompts.json" .chezmoi.sourceDir) | b64enc }}` (this is what the real-repo VoiceInk fragment uses).
- Agent notes that `include` reads bytes verbatim (no Go-template eval), so the literal `{{user_input}}` etc. survive into the base64-encoded `<data>` value.
- Agent does NOT propose escaping every `{{` in the JSON file (wrong tool for a raw payload).
- Agent does NOT modify the modify_ stub (the bug is one level down, in the fragment).
