load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  export DOTFILES_SKIP_LAUNCHCTL_SYNC=1
  # The runner may itself sit inside a mise session (just runs under mise exec).
  unset __MISE_ORIG_PATH __MISE_DIFF __MISE_SESSION MISE_SHELL
  zprofile="$FIXTURE/zprofile"
  render_template home/dot_config/zsh/dot_zprofile.tmpl devbox > "$zprofile"
}

# A zsh started from a mise-activated parent (on the devbox, every tmux pane
# and nested shell) inherits that session, and mise's hook would rebuild PATH
# from the parent's order and keep the parent's tool dirs and [env] variables.
@test "A login shell undoes a parent's mise session so zprofile's PATH order holds" {
  mkdir -p "$FIXTURE/parent-tool/bin"
  export STUB_LOG="$FIXTURE/mise.calls" STUB_ORIG_PATH="$FIXTURE/bin:/usr/bin:/bin"
  cat > "$FIXTURE/bin/mise" <<'STUB'
#!/usr/bin/env bash
printf '%s %s\n' "$MISE_SHELL" "$*" >> "$STUB_LOG"
printf "export PATH='%s'\nunset GOBIN\n" "$STUB_ORIG_PATH"
STUB
  chmod +x "$FIXTURE/bin/mise"
  export __MISE_ORIG_PATH=/usr/bin:/bin __MISE_DIFF=stale __MISE_SESSION=stale MISE_SHELL=bash
  GOBIN="$FIXTURE/parent-tool" PATH="$FIXTURE/bin:$FIXTURE/parent-tool/bin:/usr/bin:/bin" \
    run_zsh 0 -c 'source "$1"; print -r -- "$PATH"
      print -r -- "${GOBIN-unset} ${__MISE_ORIG_PATH-unset} ${__MISE_DIFF-unset} ${__MISE_SESSION-unset} ${MISE_SHELL-unset}"' \
    zsh "$zprofile"
  assert_line --index 1 "unset unset unset unset unset"
  [[ "${lines[0]}" != *"$FIXTURE/parent-tool/bin"* ]]
  [[ "${lines[0]}" == *"$FIXTURE/bin"* ]]
  run cat "$STUB_LOG"
  assert_output "zsh deactivate"
}

# Fresh shells on the Macs never carry a session, and the reversal is the only
# command zprofile may run at source time.
@test "A login shell without a parent mise session never runs mise" {
  export STUB_LOG="$FIXTURE/mise.calls"
  printf '#!/usr/bin/env bash\ntouch "$STUB_LOG"\n' > "$FIXTURE/bin/mise"
  chmod +x "$FIXTURE/bin/mise"
  run_zsh 0 -c 'source "$1"; print -r -- "${__MISE_DIFF-unset} ${MISE_SHELL-unset}"' zsh "$zprofile"
  assert_output "unset unset"
  [ ! -e "$STUB_LOG" ]
}

# The reversal is the devbox's problem; a Mac login shell stays exactly as it was.
@test "A Mac login shell carries no mise session handling" {
  run render_template home/dot_config/zsh/dot_zprofile.tmpl personal
  assert_success
  refute_output --partial "__MISE"
}

# The devbox image's /etc/zsh/zshrc loads nvm after zprofile, which puts the
# image's node ahead of the one mise manages.
@test "An interactive shell drops nvm's node from PATH and keeps everything else" {
  export ZSHCONFIG="$FIXTURE"
  printf "# stub\n" > "$FIXTURE/init.sh"
  local rc="$DOTFILES_ROOT/home/dot_config/zsh/dot_zshrc"
  NVM_DIR=/opt/nvm PATH="/opt/nvm/versions/node/v1/bin:/usr/bin:/bin" \
    run_zsh 0 -c 'source "$1" 2>/dev/null; print -r -- "$PATH"' zsh "$rc"
  assert_output "/usr/bin:/bin"
  PATH="/opt/nvm/versions/node/v1/bin:/usr/bin:/bin" \
    run_zsh 0 -c 'unset NVM_DIR; source "$1" 2>/dev/null; print -r -- "$PATH"' zsh "$rc"
  assert_output "/opt/nvm/versions/node/v1/bin:/usr/bin:/bin"
}
