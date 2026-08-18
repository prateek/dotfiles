#!/usr/bin/env zsh

set -euo pipefail

die() {
  print -u2 -- "acpx-model-drift: $*"
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || die "missing output: $needle"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" != *"$needle"* ]] || die "unexpected output: $needle"
}

DOTFILES_ROOT="${0:A:h:h}"
AUDIT="$DOTFILES_ROOT/scripts/audit/acpx-model-drift.sh"
tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

stub_bin="$tmp_root/bin"
mkdir -p "$stub_bin"
catalog_file="$tmp_root/catalog.txt"

cat >"$stub_bin/cursor-agent" <<EOF
#!/usr/bin/env bash
[ "\$1" = "--list-models" ] || { echo "unexpected cursor-agent call: \$*" >&2; exit 1; }
cat "$catalog_file"
EOF
chmod +x "$stub_bin/cursor-agent"

template="$tmp_root/config.json.tmpl"
cat >"$template" <<'EOF'
        "agpt"    (dict "command" "cursor-agent" "args" (list "--model" "gpt-5.6-sol-high-fast" "acp"))
        "aopus"   (dict "command" "cursor-agent" "args" (list "--model" "claude-opus-5-thinking-xhigh-fast" "acp"))
        "agemini" (dict "command" "cursor-agent" "args" (list "--model" "gemini-3.1-pro" "acp")))
EOF

run_audit() {
  PATH="$stub_bin:/usr/bin:/bin" ACPX_TEMPLATE="$template" bash "$AUDIT"
}

# Catalog matching the pins exactly: clean pass.
cat >"$catalog_file" <<'EOF'
Available models

auto - Auto (default)
gpt-5.6-sol-high-fast - GPT-5.6 Sol High Fast
gpt-5.6-luna-high-fast - GPT-5.6 Luna High Fast
claude-opus-5-thinking-xhigh-fast - Claude Opus 5 1M Extra High Thinking Fast
gemini-3.1-pro - Gemini 3.1 Pro
gemini-3.7-flash-high - Gemini 3.7 Flash

Tip: use --model <id> to switch.
EOF
out="$(run_audit)" || die "clean catalog should exit 0"
assert_contains "$out" "ok: gpt-5.6-sol-high-fast"
assert_contains "$out" "ok: gemini-3.1-pro"
assert_not_contains "$out" "NEWER"
assert_not_contains "$out" "STALE"

# A newer generation per family: flagged, nonzero exit. The gemini flash ids
# must not count as newer than the pro pin. The gpt entry advances only the
# xhigh tier: tier matching is deliberately loose (tier names drift across
# generations), so a cross-tier newer id must still flag the high pin.
cat >"$catalog_file" <<'EOF'
gpt-5.6-sol-high-fast - GPT-5.6 Sol High Fast
gpt-5.7-nova-xhigh-fast - GPT-5.7 Nova Extra High Fast
claude-opus-5-thinking-xhigh-fast - Claude Opus 5 1M Extra High Thinking Fast
claude-opus-5-5-thinking-xhigh-fast - Claude Opus 5.5 1M Extra High Thinking Fast
gemini-3.1-pro - Gemini 3.1 Pro
gemini-3.9-flash-high - Gemini 3.9 Flash
EOF
out="$(run_audit)" && die "newer catalog entries should exit nonzero"
assert_contains "$out" "NEWER: gpt-5.6-sol-high-fast"
assert_contains "$out" "gpt-5.7-nova-xhigh-fast"
assert_contains "$out" "NEWER: claude-opus-5-thinking-xhigh-fast"
assert_contains "$out" "claude-opus-5-5-thinking-xhigh-fast"
assert_not_contains "$out" "NEWER: gemini-3.1-pro"

# A newer pro generation does flag the gemini pin.
cat >"$catalog_file" <<'EOF'
gpt-5.6-sol-high-fast - GPT-5.6 Sol High Fast
claude-opus-5-thinking-xhigh-fast - Claude Opus 5 1M Extra High Thinking Fast
gemini-3.1-pro - Gemini 3.1 Pro
gemini-4.0-pro - Gemini 4.0 Pro
EOF
out="$(run_audit)" && die "newer gemini pro should exit nonzero"
assert_contains "$out" "NEWER: gemini-3.1-pro"
assert_contains "$out" "gemini-4.0-pro"

# A pin missing from the catalog: stale, nonzero exit.
cat >"$catalog_file" <<'EOF'
gpt-5.6-sol-high-fast - GPT-5.6 Sol High Fast
gemini-3.1-pro - Gemini 3.1 Pro
EOF
out="$(run_audit)" && die "missing pin should exit nonzero"
assert_contains "$out" "STALE: claude-opus-5-thinking-xhigh-fast"

# The real template's pins must stay parseable by the audit's own extraction.
template="$DOTFILES_ROOT/home/dot_acpx/config.json.tmpl"
real_pins="$(ACPX_TEMPLATE="$template" bash "$AUDIT" --print-pins)"
[[ -n "$real_pins" ]] || die "no --model pins found in the repo acpx template"
sed 's/$/ - Placeholder/' <<<"$real_pins" >"$catalog_file"
out="$(run_audit)" || die "repo template pins should pass against a matching catalog"
assert_not_contains "$out" "STALE"

print "acpx-model-drift: OK"
