load '../../support/common'

setup() {
  setup_fixture
  export DOTFILES_INSTALL_XCODE=false DOTFILES_SKIP_PLIST_HOOKS=1
  export GHPATH="$FIXTURE/code/github.com"
  export ZDOTDIR="$HOME/.config/zsh"
  mkdir -p "$GHPATH"
  cat > "$FIXTURE/bin/launchctl" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >> "$FIXTURE/launchctl.calls"
if [[ $# -eq 2 && "$1" == bootout && "$2" == gui/*/com.prateek.wiki-sessions-sync ]]; then exit 0; fi
printf 'launchctl %s\n' "$*" >> "$FIXTURE/unexpected.calls"
exit 64
STUB
  cat > "$FIXTURE/bin/orca" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >> "$FIXTURE/orca.calls"
if [[ "$*" == 'automations list --json' ]]; then
  printf '{"ok":true,"result":{"automations":[]}}\n'
  exit 0
fi
printf 'orca %s\n' "$*" >> "$FIXTURE/unexpected.calls"
exit 64
STUB
  cat > "$FIXTURE/bin/goku" <<'STUB'
#!/bin/sh
printf 'goku %s\n' "$*" >> "$FIXTURE/unexpected.calls"
exit 64
STUB
  chmod +x "$FIXTURE/bin/launchctl" "$FIXTURE/bin/orca" "$FIXTURE/bin/goku"
  chezmoi_args=(--no-pager --no-tty --config "$FIXTURE/chezmoi.toml"
    --cache "$XDG_CACHE_HOME" --persistent-state "$FIXTURE/chezmoi-state.boltdb"
    --override-data '{"chezmoi":{"hostname":"dotfiles-test-host"},"machines_local":{"run_install_scripts":false}}')
}

@test "Chezmoi CI apply converges including empty scripts and only exercises disabled-wiki service cleanup" {
  run_without_reporting_fds 0 chezmoi "${chezmoi_args[@]}" init --promptDefaults --promptChoice machine_type=ci --source "$DOTFILES_ROOT"
  assert_success
  run_without_reporting_fds 0 chezmoi "${chezmoi_args[@]}" apply --exclude=externals
  assert_success
  [[ "$stderr" == *'karabiner-goku:'*'missing; skipping'* ]]
  [[ "$stderr" == *'codex has no mapping for evals; that payload is claude-only'* ]]
  [[ "$stderr" == *'codex has no mapping for hooks; that payload is claude-only'* ]]
  run_without_reporting_fds 0 chezmoi "${chezmoi_args[@]}" status --exclude=externals
  assert_success
  assert_output ''
  [ -z "$stderr" ]
  [ ! -s "$FIXTURE/unexpected.calls" ]
  [ -s "$FIXTURE/launchctl.calls" ]
  [ -s "$FIXTURE/orca.calls" ]
}
