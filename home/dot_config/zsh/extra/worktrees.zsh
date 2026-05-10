#!/usr/bin/env zsh
# Worktree shortcuts.

# `wsc` = Worktree Switch (fzf picker over centralized worktrees)
unalias wsc 2>/dev/null || true
alias wsc='w switch'
