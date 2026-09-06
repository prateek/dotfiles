load '../../support/common'

setup() {
  setup_fixture
  export GHPATH="$FIXTURE/code/github.com"
  mkdir -p "$HOME/code" "$GHPATH"
  git init -q "$GHPATH/test-owner/test-repo"
  git init -q "$GHPATH/other-owner/other-repo"
  mkdir -p "$GHPATH/test-owner/worktree-like"
  printf 'gitdir: /tmp/not-a-real-worktree\n' > "$GHPATH/test-owner/worktree-like/.git"
}

@test "Repository index emits canonical clones as TSV and excludes worktrees" {
  run_zsh 0 "$DOTFILES_ROOT/bin/repo-index" --format tsv
  assert_success
  [ -z "$stderr" ]
  assert_line "test-owner/test-repo"$'\t'"https://github.com/test-owner/test-repo"$'\t'"$GHPATH/test-owner/test-repo"
  assert_line "other-owner/other-repo"$'\t'"https://github.com/other-owner/other-repo"$'\t'"$GHPATH/other-owner/other-repo"
  refute_output --partial worktree-like
}

@test "Repository index emits canonical slugs and excludes worktrees" {
  run_zsh 0 "$DOTFILES_ROOT/bin/repo-index" --format slugs
  assert_success
  [ -z "$stderr" ]
  assert_output $'other-owner/other-repo\ntest-owner/test-repo'
}

@test "Repository index rejects an unsupported format" {
  run_zsh 2 "$DOTFILES_ROOT/bin/repo-index" --format nope
  assert_failure 2
  [[ "$stderr" == *'repo-index: unknown format: nope'* ]]
}
