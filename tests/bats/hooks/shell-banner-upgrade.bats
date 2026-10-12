load '../../support/common'

setup() { setup_fixture; }

@test "apply retires the old banner without deleting local overrides or unrelated extras" {
  local source="$FIXTURE/source"
  local legacy="$HOME/.config/dotfiles/chezmoi-drift"
  mkdir -p "$source/dot_config/zsh/extra" "$source/dot_config/dotfiles/chezmoi-drift/bin"
  printf '# legacy loader\n' > "$source/dot_config/zsh/extra/chezmoi-drift.zsh"
  printf '# legacy refresh\n' > "$source/dot_config/dotfiles/chezmoi-drift/bin/executable_refresh"
  printf '# legacy defaults\n' > "$source/dot_config/dotfiles/chezmoi-drift/feature.env"
  : > "$FIXTURE/chezmoi.toml"
  local -a cm=(chezmoi --no-tty --source "$source" --destination "$HOME"
    --config "$FIXTURE/chezmoi.toml" --cache "$XDG_CACHE_HOME"
    --persistent-state "$FIXTURE/chezmoi.db")
  run_without_reporting_fds 0 "${cm[@]}" apply --force --exclude=scripts
  assert_success
  printf 'local override\n' > "$legacy/local.env"
  printf '# local extra\n' > "$HOME/.config/zsh/extra/local.zsh"
  rm -r "$source/dot_config/dotfiles/chezmoi-drift"
  rm "$source/dot_config/zsh/extra/chezmoi-drift.zsh"
  cp -R "$DOTFILES_ROOT/home/dot_config/dotfiles/shell-banner" "$source/dot_config/dotfiles/"
  cp "$DOTFILES_ROOT/home/dot_config/zsh/extra/shell-banner.zsh" "$source/dot_config/zsh/extra/"
  cp "$DOTFILES_ROOT/home/.chezmoiremove" "$source/.chezmoiremove"
  run_without_reporting_fds 0 "${cm[@]}" diff --exclude=scripts
  assert_success
  run_without_reporting_fds 0 "${cm[@]}" apply --force --exclude=scripts
  assert_success
  [ ! -e "$HOME/.config/zsh/extra/chezmoi-drift.zsh" ]
  [ ! -e "$legacy/bin/refresh" ]
  [ ! -e "$legacy/feature.env" ]
  [ "$(cat "$legacy/local.env")" = 'local override' ]
  [ -e "$HOME/.config/zsh/extra/local.zsh" ]
  [ -x "$HOME/.config/dotfiles/shell-banner/bin/refresh" ]
  [ -e "$HOME/.config/zsh/extra/shell-banner.zsh" ]
}
