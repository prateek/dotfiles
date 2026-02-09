#!/usr/bin/env zsh
# vim:syntax=sh
# vim:filetype=sh

# git aliases
alias gs='autoload_scmpuff_status'
alias ga="git add"
alias gd="git diff"
alias gb="git branch"
alias gca="git commit -a"
alias gco="git checkout"
alias lg="lazygit"

# Open Neogit (in Neovim) for a given path (defaults to current directory)
ng() {
  if ! command -v nvim >/dev/null 2>&1; then
    print -u2 "ng: nvim not found"
    return 127
  fi

  local target="${1:-.}"
  if [[ -f "$target" ]]; then
    target="${target:h}"
  fi
  local root
  root="$(git -C "$target" rev-parse --show-toplevel 2>/dev/null)" || {
    print -u2 "ng: not a git repository: $target"
    return 1
  }

  (cd "$root" && nvim -c "Neogit")
}

# via https://stackoverflow.com/questions/1057564/pretty-git-branch-graphs
alias gl1="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(auto)%d%C(reset)' --all"
alias gl2="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(auto)%d%C(reset)%n          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)'"
alias gl="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(auto)%d%C(reset)'"
alias gla="gl1"

alias gp='git pull origin $(git rev-parse --abbrev-ref HEAD)'
alias gpo='git pull origin $(git rev-parse --abbrev-ref HEAD)'
alias push='git push origin $(git rev-parse --abbrev-ref HEAD)'
alias pushf='git push origin $(git rev-parse --abbrev-ref HEAD) --force'
g_pull_fast() {
  # If not in a git repo, behave like git pull and fail
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "pull: not a git repository" >&2
    return 1
  fi

  # If the user passes arguments, don't be clever – just defer to git pull
  if [[ "$#" -gt 0 ]]; then
    git pull "$@"
    return $?
  fi

  # Try to determine the upstream (<remote>/<branch>) of the current branch
  local upstream remote branch
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null) || {
    # No upstream configured: fall back to normal git pull
    git pull --ff-only
    return $?
  }

  # Expect something like "origin/main"
  if [[ "$upstream" != */* ]]; then
    git pull --ff-only
    return $?
  fi

  remote=${upstream%%/*}
  branch=${upstream#*/}

  # Fast, branch-specific, tag-free fetch, then fast-forward merge
  git fetch --no-tags "$remote" "$branch" && \
    git merge --ff-only "$remote/$branch"
}
alias pull='g_pull_fast'
alias grim='git rebase -i $(git symbolic-ref refs/remotes/origin/HEAD | sed "s@^refs/remotes/origin/@@")'
alias grimb='BASE=$(git symbolic-ref refs/remotes/origin/HEAD | sed "s@^refs/remotes/origin/@@") && git rebase -i $(git merge-base $BASE HEAD)'
# add an alias for git spice
alias gsp="$(brew --prefix)/opt/git-spice/bin/gs"

# use fzf to autocomplete git branches
gcf() {
    git checkout $(git branch | fzf)
}

# use fzf to delete branches, allow multiple selections
gbd() {
    # use TAB/S-TAB to select multiple branches
    git branch -D $(git branch | fzf -m)
}

# adapted from https://github.com/Phantas0s/.dotfiles/blob/master/zsh/scripts_fzf.zsh
# git log browser with FZF
fgl() {
  git log --graph --color=always \
      --format="%C(auto)%h%d %s %C(black)%C(bold)%cr" "$@" |
  fzf --ansi --no-sort --reverse --tiebreak=index --bind=ctrl-s:toggle-sort \
      --bind "ctrl-m:execute:
                (grep -o '[a-f0-9]\{7\}' | head -1 |
                xargs -I % sh -c 'git show --color=always % | less -R') << 'FZF-EOF'
                {}
FZF-EOF"
}

# # adapted from: http://stackoverflow.com/questions/14031970/git-push-current-branch-shortcut
# function gpb()
# {
#     if git rev-parse --abbrev-ref --symbolic-full-name @{u} > /dev/null 2>&1; then
#         git push origin HEAD
#     else
#         git push -u origin HEAD
#     fi
# }

# FIXME: alias ssh=sshrc

# Aliases
alias ls='ls -G'
alias ll='ls -lhG'
alias vimd='vim -d'
alias psef='ps -ef | grep -i'
alias ps='ps -T'
# alias cat='bat --style=plain'
alias grep='egrep --color=auto'
alias egrep='egrep --color=auto'

# Prefer fastcp when available
if command -v fastcp >/dev/null 2>&1; then
  alias cp='fastcp'
fi

## zshrc modification aliases
alias sz='exec zsh'
alias ez='code ~/dotfiles'
alias jz='cd ~/dotfiles'

alias ec='code ~/.claude'
# alias jc='cd ~/.claude'
#
# c: mnemonic for "code editor" — opens current dir in Cursor/VS Code
alias c='$DOTFILES/scripts/c'

alias yo='open -a Yoink'
unalias yolo 2>/dev/null
yolo() {
  codex --dangerously-bypass-approvals-and-sandbox "$@"
}
unalias yoloo 2>/dev/null
yoloo() {
  OPENCODE_PERMISSION='{"*":"allow"}' opencode "$@"
}
alias yoloc='claude --dangerously-skip-permissions'

# Worktree: create + agent (Worktrunk docs-style shorthand)
alias wsc='w run'

# One-shot Codex: cdx "do x y and z"
# via https://gist.github.com/cameroncooke/9efe289b3251f290ecc5bf0dd87f92bd
cdx() {
  codex --ask-for-approval on-request \
    --sandbox danger-full-access      \
    exec --skip-git-repo-check        \
    "$*" 2>/dev/null
}

# FIXME: Pipe Aliases
# alias L=' | less '
# alias G=' | egrep --color=auto '
# alias T=' | tail '
# alias H=' | head '
# alias W=' | wc -l '
# alias S=' | sort '
