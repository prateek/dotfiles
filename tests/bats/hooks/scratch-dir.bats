load '../../support/common'
load '../../support/chezmoi'

setup() {
  setup_fixture
  export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
  export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
  scratch="$HOME/code/scratch"
  mkdir -p "$scratch"
  cp "$DOTFILES_ROOT/home/code/scratch/AGENTS.md" "$scratch/AGENTS.md"
  cp "$DOTFILES_ROOT/home/code/scratch/dot_gitignore" "$scratch/.gitignore"
  # Fake Orca: remembers added paths; ORCA_FAIL makes every call fail.
  cat > "$FIXTURE/bin/orca" <<'STUB'
#!/bin/bash
[ -z "${ORCA_FAIL:-}" ] || exit 1
state="$FIXTURE/orca-repos"
case "$1 $2" in
  "repo list")
    printf '{"ok":true,"result":{"repos":['
    [ -f "$state" ] && sed 's/.*/{"id":"repo-1","path":"&"}/' "$state" | paste -sd, -
    printf ']}}\n' ;;
  "repo add")
    printf '%s kind=%s\n' "$4" "$([ -d "$4/.git" ] && echo git || echo folder)" >> "$FIXTURE/orca-adds"
    printf '%s\n' "$4" >> "$state" ;;
  *) exit 2 ;;
esac
STUB
  chmod +x "$FIXTURE/bin/orca"
  render_template home/.chezmoiscripts/run_onchange_after_41-scratch-dir.sh.tmpl personal > "$FIXTURE/scratch.sh"
}

commit_count() {
  git -C "$scratch" rev-list --count HEAD
}

@test "a fresh scratch dir becomes a git repo with both files committed, then registers with Orca" {
  mkdir "$scratch/2026-09-30-task"
  printf 'x' > "$scratch/2026-09-30-task/notes.md"

  run_bash 0 "$FIXTURE/scratch.sh"
  assert_success
  [ "$(commit_count)" -eq 1 ]
  [ "$(git -C "$scratch" ls-files)" = $'.gitignore\nAGENTS.md' ]
  [ -z "$(git -C "$scratch" status --porcelain)" ]
  [ "$(cat "$FIXTURE/orca-adds")" = "$scratch kind=git" ]
}

@test "a second run changes nothing" {
  run_bash 0 "$FIXTURE/scratch.sh"
  head="$(git -C "$scratch" rev-parse HEAD)"

  run_bash 0 "$FIXTURE/scratch.sh"
  assert_success
  [ "$(git -C "$scratch" rev-parse HEAD)" = "$head" ]
  [ "$(wc -l < "$FIXTURE/orca-adds")" -eq 1 ]
  [ -z "$output" ]
}

@test "an updated AGENTS.md lands as one commit touching only that file" {
  run_bash 0 "$FIXTURE/scratch.sh"
  printf '\nMore guidance.\n' >> "$scratch/AGENTS.md"

  run_bash 0 "$FIXTURE/scratch.sh"
  assert_success
  [ "$(commit_count)" -eq 2 ]
  [ "$(git -C "$scratch" show --name-only --format= HEAD)" = AGENTS.md ]
  [ -z "$(git -C "$scratch" status --porcelain)" ]
}

@test "an unreachable Orca warns without failing the apply" {
  ORCA_FAIL=1 run_bash 0 "$FIXTURE/scratch.sh"
  assert_success
  [[ "$stderr" == *"could not register with Orca"* ]]
  [ "$(commit_count)" -eq 1 ]
}

@test "a missing managed file fails loudly instead of creating an empty repo" {
  rm "$scratch/AGENTS.md"

  run_bash 1 "$FIXTURE/scratch.sh"
  [[ "$stderr" == *"$scratch/AGENTS.md is missing"* ]]
  [ ! -e "$scratch/.git" ]
  [ ! -e "$FIXTURE/orca-adds" ]
}
