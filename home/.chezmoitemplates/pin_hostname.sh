# shellcheck shell=bash

# An explicit HostName (set by hand or MDM) always wins. The pin keeps the .local
# suffix so gethostname() still resolves through Bonjour; a bare name has no DNS
# entry and breaks tools that resolve their own hostname. Pinning changes the
# kernel hostname immediately, but the running chezmoi resolved .chezmoi.hostname
# at startup, so a mismatch aborts this apply rather than let it render without
# the host layer.
pin_hostname_reconcile() {
  local rendered="$1" current local_name
  current="$(scutil --get HostName 2>/dev/null)" || current=""
  [ -z "$current" ] || return 0

  local_name="$(scutil --get LocalHostName 2>/dev/null)" || local_name=""
  if [ -z "$local_name" ]; then
    warn "HostName and LocalHostName are both unset; name this Mac in System Settings > General > Sharing."
    return 0
  fi

  dotfiles_sudo_start "Pinning HostName to $local_name.local needs administrator access."
  sudo scutil --set HostName "$local_name.local" || return 1
  log "HostName pinned to $local_name.local."
  if [ "$rendered" != "$local_name" ]; then
    die "this apply resolved the hostname as '$rendered', so [machines.host.$local_name] did not apply; run chezmoi apply again."
  fi
}
