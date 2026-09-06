load '../../support/common'

setup() {
  setup_fixture
  audit="$DOTFILES_ROOT/scripts/audit/acpx-model-drift.sh"
  export ACPX_TEMPLATE="$FIXTURE/config.json.tmpl"
  cat > "$ACPX_TEMPLATE" <<'TEMPLATE'
"agpt" (dict "command" "cursor-agent" "args" (list "--model" "gpt-5.6-sol-high-fast" "acp"))
"aopus" (dict "command" "cursor-agent" "args" (list "--model" "claude-opus-5-thinking-xhigh-fast" "acp"))
"agemini" (dict "command" "cursor-agent" "args" (list "--model" "gemini-3.1-pro" "acp")))
TEMPLATE
  cat > "$FIXTURE/bin/cursor-agent" <<'STUB'
#!/bin/sh
[ "$#" = 1 ] && [ "$1" = --list-models ] || exit 99
cat "$FIXTURE/catalog"
STUB
  chmod +x "$FIXTURE/bin/cursor-agent"
  cat > "$FIXTURE/catalog" <<'CATALOG'
Available models

auto - Auto (default)
gpt-5.6-sol-high-fast - GPT-5.6 Sol High Fast
gpt-5.6-luna-high-fast - GPT-5.6 Luna High Fast
claude-opus-5-thinking-xhigh-fast - Claude Opus 5 1M Extra High Thinking Fast
gemini-3.1-pro - Gemini 3.1 Pro
gemini-3.7-flash-high - Gemini 3.7 Flash

Tip: use --model <id> to switch.
CATALOG
}

@test "Model drift accepts a matching catalog and ignores headers and unrelated tiers" {
  run_bash 0 "$audit"
  assert_success
  [ -z "$stderr" ]
  assert_output --partial 'ok: gpt-5.6-sol-high-fast'
  assert_output --partial 'ok: gemini-3.1-pro'
  refute_output --partial NEWER
  refute_output --partial STALE
}

@test "Model drift flags newer GPT and Claude generations across tiers without treating Gemini Flash as Pro" {
  cat >> "$FIXTURE/catalog" <<'CATALOG'
gpt-5.7-nova-xhigh-fast - GPT-5.7 Nova Extra High Fast
claude-opus-5-5-thinking-xhigh-fast - Claude Opus 5.5 1M Extra High Thinking Fast
gemini-3.9-flash-high - Gemini 3.9 Flash
CATALOG
  run_bash 1 "$audit"
  assert_failure 1
  [ -z "$stderr" ]
  assert_output --partial 'NEWER: gpt-5.6-sol-high-fast'
  assert_output --partial gpt-5.7-nova-xhigh-fast
  assert_output --partial 'NEWER: claude-opus-5-thinking-xhigh-fast'
  assert_output --partial claude-opus-5-5-thinking-xhigh-fast
  refute_output --partial 'NEWER: gemini-3.1-pro'
}

@test "Model drift flags a newer Gemini Pro generation" {
  printf 'gemini-4.0-pro - Gemini 4.0 Pro\n' >> "$FIXTURE/catalog"
  run_bash 1 "$audit"
  assert_failure 1
  [ -z "$stderr" ]
  assert_output --partial 'NEWER: gemini-3.1-pro'
  assert_output --partial gemini-4.0-pro
}

@test "Model drift rejects a pin absent from the catalog" {
  printf '%s\n' 'gpt-5.6-sol-high-fast - GPT-5.6 Sol High Fast' \
    'gemini-3.1-pro - Gemini 3.1 Pro' > "$FIXTURE/catalog"
  run_bash 1 "$audit"
  assert_failure 1
  [ -z "$stderr" ]
  assert_output --partial 'STALE: claude-opus-5-thinking-xhigh-fast'
}

@test "Model drift extracts the managed template's pins through its public CLI" {
  export ACPX_TEMPLATE="$DOTFILES_ROOT/home/dot_acpx/config.json.tmpl"
  run_bash 0 "$audit" --print-pins
  assert_success
  [ -z "$stderr" ]
  [ -n "$output" ]
  printf '%s\n' "$output" | sed 's/$/ - Placeholder/' > "$FIXTURE/catalog"
  run_bash 0 "$audit"
  assert_success
  [ -z "$stderr" ]
  refute_output --partial STALE
}
