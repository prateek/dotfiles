# Devland 1Password operations

Use the repo's `scripts/chezmoi-hooks/op-service-account` wrapper for Devland
item operations. Include `--vault` for both list and get. Search for matching
items before creating anything: `$DOTFILES_CHECKOUT/scripts/1password/find-item --vault <vault> --title <exact-title>`
returns either one ID or an explicit no-match result. When editing an existing item, retain all
unrelated fields; inspect its current JSON first. Keep retrieved values out of
argv and logs.

For an SSH Key item, read `private_key.ssh_formats.openssh`, not
`private_key.value`. The installed CLI cannot edit an SSH Key item, so store
connection metadata in its related Login. For a local key file, use the repo's
`scripts/1password/export-ssh-key`; it writes mode 0600, validates with
`ssh-keygen -y`, and refuses to replace an existing file. Test the connection
with `ssh -o IdentitiesOnly=yes -i <file> <target>` after the authorized
installation. The helper has dummy-secret tests; it makes no live vault changes.
