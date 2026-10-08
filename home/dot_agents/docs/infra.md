# Personal Infrastructure

Use this document for homelab hosts, home network, Home Assistant, and personal
devices or peripherals that need setup or documenting.

The private `prateek/infra` repository is the record for that infrastructure.
Work in an Orca worktree created with `ohc prateek/infra` (see
[worktrees.md](worktrees.md)), then follow its `AGENTS.md` and setup workflow.

Machine configuration managed by chezmoi stays in the dotfiles repository. A
device record in `prateek/infra` links to the dotfiles change when a device also
needs machine config.
