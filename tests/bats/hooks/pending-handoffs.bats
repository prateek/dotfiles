load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  # Fake gh: serves $FIXTURE/handoff.md for the WinMux handoff path and logs API calls.
  # GH_NO_AUTH fails `auth token`; GH_FAIL fails the API call with gh's 404 text.
  cat > "$FIXTURE/bin/gh" <<'STUB'
#!/bin/bash
if [ "$1 $2" = "auth token" ]; then [ -z "${GH_NO_AUTH:-}" ]; exit; fi
printf '%s\n' "$*" >> "$FIXTURE/gh-calls"
[ -z "${GH_FAIL:-}" ] || { echo "gh: Not Found (HTTP 404)" >&2; exit 1; }
[ "$1 $2" = "api repos/prateek/winmux/contents/docs/dotfiles-handoff.md" ] || exit 2
cat "$FIXTURE/handoff.md"
STUB
  chmod +x "$FIXTURE/bin/gh"
  render_template home/.chezmoiscripts/run_after_95-pending-handoffs.sh.tmpl personal > "$FIXTURE/handoffs.sh"
}

write_handoff() {
  cat > "$FIXTURE/handoff.md" <<MD
# Dotfiles handoff

Intro text with a - dash that is not an entry.

## Pending
$1
## Done

- **2026-10-17, from the relay.** Already reconciled.
MD
}

@test "pending entries are listed with the handoff command" {
  write_handoff $'\n- **2026-10-18, #241.** Change Option-9.\n* **2026-10-19, #250.** Second change.\n\n## Pending review\n\n- Not a handoff entry.\n'

  run_bash 0 "$FIXTURE/handoffs.sh"
  assert_success
  [[ "$stderr" == *"prateek/winmux has pending dotfiles changes in docs/dotfiles-handoff.md:"* ]]
  [[ "$stderr" == *"    **2026-10-18, #241.** Change Option-9."* ]]
  [[ "$stderr" == *"    **2026-10-19, #250.** Second change."* ]]
  [[ "$stderr" == *"/utils-agent:ho reconcile the prateek/winmux dotfiles handoff (docs/dotfiles-handoff.md)"* ]]
  [[ "$stderr" != *"Already reconciled"* ]]
  [[ "$stderr" != *"Not a handoff entry"* ]]
}

@test "an empty Pending section prints nothing" {
  write_handoff ''

  run_bash 0 "$FIXTURE/handoffs.sh"
  assert_success
  [ -z "$output" ]
  [ -z "$stderr" ]
}

@test "an unreachable repo warns with gh's error and does not fail the apply" {
  GH_FAIL=1 run_bash 0 "$FIXTURE/handoffs.sh"
  assert_success
  [[ "$stderr" == *"could not read prateek/winmux:docs/dotfiles-handoff.md: gh: Not Found (HTTP 404)"* ]]
}

@test "a host where gh is not signed in skips without calling the API" {
  GH_NO_AUTH=1 run_bash 0 "$FIXTURE/handoffs.sh"
  assert_success
  assert_output --partial "gh is not signed in; skipping the dotfiles handoff check."
  [ ! -e "$FIXTURE/gh-calls" ]
  [ -z "$stderr" ]
}
