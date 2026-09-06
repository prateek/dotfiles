setup_hooks() {
  setup_fixture
  hook="$FIXTURE/plist-hooks.sh"
  # Shared paths are consumed by the Bats cases.
  # shellcheck disable=SC2034
  pending="$XDG_STATE_HOME/dotfiles/plist-pending.txt" quit_list="$XDG_STATE_HOME/dotfiles/plist-quit-by-guard.txt"
  events="$FIXTURE/events"
  mkdir -p "$XDG_STATE_HOME/dotfiles"
  : > "$FIXTURE/status"
  : > "$FIXTURE/running"
  : > "$FIXTURE/stuck"
  : > "$events"
  cp "$DOTFILES_ROOT/scripts/chezmoi-hooks/render-host-mount" "$FIXTURE/render-host-mount"
  "$TEST_PYTHON" - "$DOTFILES_ROOT/scripts/chezmoi-hooks/plist-hooks.sh" "$hook" "$FIXTURE/bin" <<'PY'
from pathlib import Path
import shlex
import sys
source, target, bin_dir = sys.argv[1:]
text = Path(source).read_text()
for tool in ('lsappinfo', 'osascript', 'killall', 'open'):
    text = text.replace('/usr/bin/' + tool, shlex.quote(str(Path(bin_dir) / tool)))
Path(target).write_text(text)
PY
  cat > "$FIXTURE/bin/app-tool" <<'STUB'
#!/bin/sh
set -eu
case "${0##*/}" in
  chezmoi)
    [ "$1" = status ] && [ "$2" = --path-style=absolute ]
    cat "$FIXTURE/status"
    ;;
  lsappinfo)
    [ "$1" = info ] && [ "$2" = -only ] && [ "$3" = bundleid ]
    if grep -Fxq "$4" "$FIXTURE/running" && [ ! -e "$FIXTURE/quit.$4" ]; then
      printf '"LSBundleIdentifier"="%s"\n' "$4"
    fi
    ;;
  osascript)
    [ "$1" = -e ]
    id="$(printf '%s\n' "$2" | sed -n 's/^tell application id "\(.*\)" to quit$/\1/p')"
    [ -n "$id" ]
    printf 'quit %s\n' "$id" >> "$FIXTURE/events"
    if ! grep -Fxq "$id" "$FIXTURE/stuck"; then : > "$FIXTURE/quit.$id"; fi
    ;;
  killall)
    [ "$1" = -u ] && [ "$3" = cfprefsd ]
    printf 'flush cfprefsd\n' >> "$FIXTURE/events"
    ;;
  open)
    [ "$1" = -b ]
    printf 'open %s\n' "$2" >> "$FIXTURE/events"
    ;;
  *) exit 99 ;;
esac
STUB
  chmod +x "$FIXTURE/bin/app-tool"
  for tool in chezmoi lsappinfo osascript killall open; do
    ln -s app-tool "$FIXTURE/bin/$tool"
  done
}

pending_apps() {
  local id
  for id in "$@"; do
    printf ' M %s/Library/Preferences/%s.plist\n' "$HOME" "$id"
  done > "$FIXTURE/status"
}

hook_dialogue() {
  run_zsh 0 "$DOTFILES_ROOT/tests/support/pty-dialogue.zsh" \
    "$FIXTURE/transcript" '[Y/n]' "$1" bash "$hook" pre
}
