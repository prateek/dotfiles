#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

log() { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

is_file() { [ -e "$1" ] && [ -f "$1" ]; }

tty_available() { [ -r /dev/tty ] && [ -w /dev/tty ]; }

read_tty_line() {
  local prompt="$1"
  local line=""
  if tty_available; then
    read -r -p "$prompt" line </dev/tty || true
  else
    read -r -p "$prompt" line || true
  fi
  printf '%s\n' "$line"
}

timestamp() { date +%s; }

backup_if_exists() {
  local path="$1"
  if [ -e "$path" ] || [ -L "$path" ]; then
    mv "$path" "${path}.backup-$(timestamp)"
  fi
}

ensure_symlink() {
  local src="$1"
  local dest="$2"

  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ "$(readlink "$dest" 2>/dev/null || true)" = "$src" ]; then
      return 0
    fi
    backup_if_exists "$dest"
  fi
  ln -snf "$src" "$dest"
}

copy_file() {
  local src="$1"
  local dest="$2"

  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    backup_if_exists "$dest"
  fi
  cp "$src" "$dest"
}

copy_dir_contents() {
  local src_dir="$1"
  local dest_dir="$2"

  mkdir -p "$dest_dir"
  # Copy *contents* (not the folder itself) so the destination shape is stable.
  # macOS cp treats trailing `/.` as "copy contents".
  cp -R "$src_dir/." "$dest_dir/"
}

expand_path() {
  local path="$1"
  if [ -z "$path" ] || [ "$path" = "null" ]; then
    printf '%s\n' ""
    return 0
  fi
  case "$path" in
    ~) path="$HOME" ;;
    ~/*) path="$HOME/${path:2}" ;;
  esac
  path="${path//\$HOME/$HOME}"
  printf '%s\n' "$path"
}

request_sudo_keepalive() {
  if [ "${DOTFILES_SUDO_KEEPALIVE_STARTED:-0}" = "1" ]; then
    return 0
  fi

  log "Requesting sudo (to avoid repeated password prompts)…"
  if tty_available; then
    sudo -v
  elif sudo -n true >/dev/null 2>&1; then
    :
  elif [ -n "${DOTFILES_SUDO_PASSWORD:-}" ]; then
    printf '%s\n' "$DOTFILES_SUDO_PASSWORD" | sudo -S -v
  else
    die "sudo requires a password but no TTY is available. Run from a terminal or set DOTFILES_SUDO_PASSWORD."
  fi

  local sudo_pid="$$"
  while true; do sudo -n true; sleep 60; kill -0 "$sudo_pid" || exit; done 2>/dev/null &
  export DOTFILES_SUDO_KEEPALIVE_STARTED=1
}

ensure_macos() {
  if [ "$(uname -s)" != "Darwin" ]; then
    die "macOS only."
  fi
}

ensure_cmd() {
  local cmd="$1"
  local install_hint="${2:-}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    if [ -n "$install_hint" ]; then
      die "Missing required command: $cmd (install: $install_hint)"
    fi
    die "Missing required command: $cmd"
  fi
}

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/macos/gui-apps.sh plan  [--manifest PATH]
  ./scripts/macos/gui-apps.sh apply [--manifest PATH] [--dry-run=true|false] [--force]

Notes:
  - `apply` defaults to `--dry-run=true` (preflight check only).
  - `--dry-run=false` performs installs + config + launches and runs a guided permissions wizard.
  - To skip the interactive confirmation prompt: DOTFILES_GUI_APPS_YES=1
USAGE
}

MANIFEST_PATH="$REPO_ROOT/osx-apps/gui-apps.yaml"
MANIFEST_JSON=""

DEFAULT_INSTALL="true"
DEFAULT_CONFIG="true"
DEFAULT_CONFIG_MODE="set_once"
DEFAULT_LICENSE="false"
DEFAULT_LICENSE_MODE="set_once"
DEFAULT_LAUNCH="true"
DEFAULT_PERMISSIONS="true"

OP_ENABLED="false"

STATE_DIR=""
STAMPS_DIR=""
SEED_DIR=""

load_manifest() {
  local manifest="$1"
  if ! is_file "$manifest"; then
    die "Manifest not found: $manifest"
  fi

  ensure_cmd yq "brew install python-yq"
  ensure_cmd jq "brew install jq"

  MANIFEST_JSON="$(yq '.' "$manifest")"

  local schema_version
  schema_version="$(printf '%s\n' "$MANIFEST_JSON" | jq -r '.schema_version // empty')"
  if [ -z "$schema_version" ]; then
    die "Manifest missing: schema_version"
  fi
  if [ "$schema_version" != "1" ]; then
    die "Unsupported schema_version: $schema_version (expected: 1)"
  fi

  DEFAULT_INSTALL="$(printf '%s\n' "$MANIFEST_JSON" | jq -r 'if .defaults.install == null then true else .defaults.install end')"
  DEFAULT_CONFIG="$(printf '%s\n' "$MANIFEST_JSON" | jq -r 'if .defaults.config == null then true else .defaults.config end')"
  DEFAULT_CONFIG_MODE="$(printf '%s\n' "$MANIFEST_JSON" | jq -r '.defaults.config_mode // "set_once"')"
  DEFAULT_LICENSE="$(printf '%s\n' "$MANIFEST_JSON" | jq -r 'if .defaults.license == null then false else .defaults.license end')"
  DEFAULT_LICENSE_MODE="$(printf '%s\n' "$MANIFEST_JSON" | jq -r '.defaults.license_mode // "set_once"')"
  DEFAULT_LAUNCH="$(printf '%s\n' "$MANIFEST_JSON" | jq -r 'if .defaults.launch == null then true else .defaults.launch end')"
  DEFAULT_PERMISSIONS="$(printf '%s\n' "$MANIFEST_JSON" | jq -r 'if .defaults.permissions == null then true else .defaults.permissions end')"

  OP_ENABLED="$(printf '%s\n' "$MANIFEST_JSON" | jq -r 'if .onepassword.enabled == null then false else .onepassword.enabled end')"

  local state_dir_override
  state_dir_override="$(printf '%s\n' "$MANIFEST_JSON" | jq -r '.state.dir // ""')"

  local state_base
  state_base="${XDG_STATE_HOME:-$HOME/Library/Application Support}"
  if [ -n "$state_dir_override" ] && [ "$state_dir_override" != "null" ]; then
    STATE_DIR="$(expand_path "$state_dir_override")"
  else
    STATE_DIR="$state_base/dotfiles/gui-apps"
  fi

  STAMPS_DIR="$STATE_DIR/stamps"
  SEED_DIR="$STATE_DIR/seed"
}

stamp_path() {
  local app_id="$1"
  local step="$2"
  printf '%s\n' "$STAMPS_DIR/${app_id}__${step}.stamp"
}

is_cask_installed() {
  local cask="$1"
  brew list --cask "$cask" >/dev/null 2>&1
}

install_cask() {
  local cask="$1"
  brew install --cask "$cask"
}

killall_quiet() {
  local proc="$1"
  killall "$proc" >/dev/null 2>&1 || true
}

open_bundle_id() {
  local bundle_id="$1"
  local label="$2"
  if [ -z "$bundle_id" ]; then
    warn "No bundle_id set for $label; cannot auto-launch."
    return 0
  fi
  if open -gj -b "$bundle_id" >/dev/null 2>&1; then
    log "Started: $label"
    return 0
  fi
  warn "Could not start $label ($bundle_id). Is it installed?"
  return 0
}

config_supported() {
  local app_id="$1"
  case "$app_id" in
    alfred|bettertouchtool|cursor|ghostty|google-chrome|karabiner-elements|leader-key|moom|orbstack|visual-studio-code)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

apply_config_karabiner() {
  local mode="$1"

  local src="$REPO_ROOT/.config/karabiner/karabiner.json"
  local dest="$HOME/.config/karabiner/karabiner.json"
  if [ ! -f "$src" ]; then
    die "Karabiner config missing: $src"
  fi

  if [ "$mode" = "sync" ]; then
    ensure_symlink "$src" "$dest"
  else
    copy_file "$src" "$dest"
  fi

  # Best-effort: select the expected profile to ensure the daemon picks up the new config.
  local karabiner_cli="/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli"
  if [ -x "$karabiner_cli" ]; then
    local profile="${DOTFILES_KARABINER_PROFILE_NAME:-Default profile}"
    "$karabiner_cli" --select-profile "$profile" >/dev/null 2>&1 || true
  fi

  # Best-effort: restart the user server.
  local uid
  uid="$(id -u 2>/dev/null || true)"
  if [ -n "$uid" ]; then
    launchctl kickstart -k "gui/$uid/org.pqrs.service.agent.karabiner_console_user_server" >/dev/null 2>&1 || true
  fi
}

apply_config_moom() {
  local src="$REPO_ROOT/osx-apps/Moom.plist"
  if [ ! -f "$src" ]; then
    die "Moom defaults export missing: $src"
  fi
  defaults import com.manytricks.Moom "$src" >/dev/null 2>&1 || true
  killall_quiet Moom
}

apply_config_alfred() {
  local mode="$1"

  local defaults_plist="$REPO_ROOT/osx-apps/defaults/com.runningwithcrayons.Alfred-Preferences.plist"
  if [ -f "$defaults_plist" ]; then
    defaults import com.runningwithcrayons.Alfred-Preferences "$defaults_plist" >/dev/null 2>&1 || true
  fi

  local prefs_src="$REPO_ROOT/osx-apps/alfred"
  if [ ! -d "$prefs_src" ]; then
    die "Alfred prefs folder missing: $prefs_src"
  fi

  local sync_dir
  if [ "$mode" = "sync" ]; then
    sync_dir="$prefs_src"
  else
    sync_dir="$SEED_DIR/alfred"
    backup_if_exists "$sync_dir"
    copy_dir_contents "$prefs_src" "$sync_dir"
  fi

  defaults write com.runningwithcrayons.Alfred-Preferences syncfolder -string "$sync_dir" >/dev/null 2>&1 || true
  killall_quiet Alfred
}

apply_config_leader_key() {
  local mode="$1"

  local defaults_plist="$REPO_ROOT/osx-apps/defaults/com.brnbw.Leader-Key.plist"
  if [ -f "$defaults_plist" ]; then
    defaults import com.brnbw.Leader-Key "$defaults_plist" >/dev/null 2>&1 || true
  fi

  local config_src="$REPO_ROOT/osx-apps/leader-key"
  if [ ! -d "$config_src" ]; then
    die "Leader Key config folder missing: $config_src"
  fi

  local config_dir
  if [ "$mode" = "sync" ]; then
    config_dir="$config_src"
  else
    config_dir="$SEED_DIR/leader-key"
    backup_if_exists "$config_dir"
    copy_dir_contents "$config_src" "$config_dir"
  fi

  defaults write com.brnbw.Leader-Key configDir -string "$config_dir" >/dev/null 2>&1 || true
  killall_quiet "Leader Key"
}

apply_config_bettertouchtool() {
  local btt_repo_dir="$REPO_ROOT/osx-apps/bettertouchtool"
  if [ ! -d "$btt_repo_dir" ]; then
    die "BetterTouchTool config not present in repo: $btt_repo_dir (set config:false or add it)"
  fi

  killall_quiet BetterTouchTool

  local btt_dest_dir="$HOME/Library/Application Support/BetterTouchTool"
  mkdir -p "$btt_dest_dir"
  local src base
  for src in "$btt_repo_dir"/*; do
    [ -e "$src" ] || continue
    base="$(basename "$src")"
    case "$base" in
      btt_data_store.version_*|btt_user_variables.plist)
        copy_file "$src" "$btt_dest_dir/$base"
        ;;
    esac
  done
}

apply_config_chrome_policies() {
  local src="$REPO_ROOT/osx-apps/chrome/policies/com.google.Chrome.plist"
  if [ ! -f "$src" ]; then
    die "Chrome policies plist missing: $src"
  fi
  sudo mkdir -p "/Library/Managed Preferences"
  sudo install -m 0644 "$src" "/Library/Managed Preferences/com.google.Chrome.plist"
  killall_quiet "Google Chrome"
}

apply_config_orbstack() {
  local docker_src="$REPO_ROOT/osx-apps/orbstack/config/docker.json"
  local vm_src="$REPO_ROOT/osx-apps/orbstack/vmconfig.json"

  if [ -f "$docker_src" ]; then
    copy_file "$docker_src" "$HOME/.orbstack/config/docker.json"
  fi
  if [ -f "$vm_src" ]; then
    copy_file "$vm_src" "$HOME/.orbstack/vmconfig.json"
  fi
}

apply_config_ghostty() {
  local mode="$1"

  local src="$REPO_ROOT/osx-apps/ghostty/config"
  if [ ! -f "$src" ]; then
    die "Ghostty config missing: $src"
  fi

  local dest="$HOME/Library/Application Support/com.mitchellh.ghostty/config"
  if [ "$mode" = "sync" ]; then
    ensure_symlink "$src" "$dest"
  else
    copy_file "$src" "$dest"
  fi
  killall_quiet Ghostty
}

apply_vscode_settings() {
  local mode="$1"
  local user_dir="$2"

  mkdir -p "$user_dir"

  local settings_src="$REPO_ROOT/osx-apps/vscode/settings.json"
  local keybindings_src="$REPO_ROOT/osx-apps/vscode/keybindings.json"
  local snippets_src="$REPO_ROOT/osx-apps/vscode/snippets"

  if [ ! -f "$settings_src" ]; then
    die "VS Code settings missing: $settings_src"
  fi
  if [ ! -f "$keybindings_src" ]; then
    die "VS Code keybindings missing: $keybindings_src"
  fi
  if [ ! -d "$snippets_src" ]; then
    die "VS Code snippets missing: $snippets_src"
  fi

  if [ "$mode" = "sync" ]; then
    ensure_symlink "$settings_src" "$user_dir/settings.json"
    ensure_symlink "$keybindings_src" "$user_dir/keybindings.json"
    ensure_symlink "$snippets_src" "$user_dir/snippets"
  else
    copy_file "$settings_src" "$user_dir/settings.json"
    copy_file "$keybindings_src" "$user_dir/keybindings.json"

    if [ -e "$user_dir/snippets" ] || [ -L "$user_dir/snippets" ]; then
      backup_if_exists "$user_dir/snippets"
    fi
    copy_dir_contents "$snippets_src" "$user_dir/snippets"
  fi
}

apply_config_vscode() {
  local mode="$1"
  apply_vscode_settings "$mode" "$HOME/Library/Application Support/Code/User"
}

apply_config_cursor() {
  local mode="$1"
  apply_vscode_settings "$mode" "$HOME/Library/Application Support/Cursor/User"
}

apply_config_for_app() {
  local app_id="$1"
  local mode="$2"

  case "$app_id" in
    karabiner-elements) apply_config_karabiner "$mode" ;;
    moom) apply_config_moom ;;
    alfred) apply_config_alfred "$mode" ;;
    leader-key) apply_config_leader_key "$mode" ;;
    bettertouchtool) apply_config_bettertouchtool ;;
    google-chrome) apply_config_chrome_policies ;;
    orbstack) apply_config_orbstack ;;
    ghostty) apply_config_ghostty "$mode" ;;
    visual-studio-code) apply_config_vscode "$mode" ;;
    cursor) apply_config_cursor "$mode" ;;
    *) die "Config not implemented for app id: $app_id" ;;
  esac
}

op_preflight() {
  if [ "$OP_ENABLED" != "true" ]; then
    die "1Password integration disabled (set onepassword.enabled: true)."
  fi
  ensure_cmd op "brew install --cask 1password-cli"
  if ! op whoami >/dev/null 2>&1; then
    die "Not authenticated to 1Password CLI. Run: op signin"
  fi
}

apply_license_for_app() {
  local app_id="$1"
  local app_json="$2"

  local op_uri install_type domain dest mode
  op_uri="$(printf '%s\n' "$app_json" | jq -r '.license.op_uri // ""')"
  install_type="$(printf '%s\n' "$app_json" | jq -r '.license.install.type // ""')"
  domain="$(printf '%s\n' "$app_json" | jq -r '.license.install.domain // ""')"
  dest="$(printf '%s\n' "$app_json" | jq -r '.license.install.dest // ""')"
  mode="$(printf '%s\n' "$app_json" | jq -r --arg d "$DEFAULT_LICENSE_MODE" '.license.mode // $d')"

  if [ -z "$op_uri" ]; then
    die "license.enabled=true but license.op_uri is empty for: $app_id"
  fi
  if [ -z "$install_type" ]; then
    die "license.enabled=true but license.install.type is empty for: $app_id"
  fi

  op_preflight

  case "$install_type" in
    defaults_import)
      if [ -z "$domain" ]; then
        die "license.install.domain is required for defaults_import ($app_id)"
      fi
      local tmp
      tmp="$(mktemp -t "dotfiles-${app_id}-license.XXXXXX")"
      op read "$op_uri" >"$tmp"
      defaults import "$domain" "$tmp" >/dev/null 2>&1 || true
      rm -f "$tmp"
      ;;
    copy_file)
      if [ -z "$dest" ]; then
        die "license.install.dest is required for copy_file ($app_id)"
      fi
      dest="$(expand_path "$dest")"
      mkdir -p "$(dirname "$dest")"
      local tmp
      tmp="$(mktemp -t "dotfiles-${app_id}-license.XXXXXX")"
      op read "$op_uri" >"$tmp"
      backup_if_exists "$dest"
      mv "$tmp" "$dest"
      ;;
    *)
      die "Unsupported license.install.type: $install_type ($app_id)"
      ;;
  esac

  # Default best-effort restart hooks.
  case "$app_id" in
    moom) killall_quiet Moom ;;
    alfred) killall_quiet Alfred ;;
    bettertouchtool) killall_quiet BetterTouchTool ;;
  esac

  # Mode is currently only used by the outer stamp logic; keep for forward-compat.
  : "${mode:?}"
}

permission_url() {
  local perm="$1"
  case "$perm" in
    accessibility) printf '%s\n' "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" ;;
    input_monitoring) printf '%s\n' "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent" ;;
    screen_recording) printf '%s\n' "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture" ;;
    full_disk_access) printf '%s\n' "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" ;;
    automation) printf '%s\n' "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation" ;;
    system_extension) printf '%s\n' "x-apple.systempreferences:com.apple.preference.security" ;;
    *) printf '%s\n' "" ;;
  esac
}

permission_title() {
  local perm="$1"
  case "$perm" in
    accessibility) printf '%s\n' "Accessibility" ;;
    input_monitoring) printf '%s\n' "Input Monitoring" ;;
    screen_recording) printf '%s\n' "Screen Recording" ;;
    full_disk_access) printf '%s\n' "Full Disk Access" ;;
    automation) printf '%s\n' "Automation" ;;
    system_extension) printf '%s\n' "Privacy & Security (System Extensions)" ;;
    *) printf '%s\n' "$perm" ;;
  esac
}

permissions_fingerprint() {
  # Stable fingerprint of permissions required by enabled apps.
  printf '%s\n' "$MANIFEST_JSON" | jq -r --argjson d "$DEFAULT_PERMISSIONS" '
    .apps
    | map(select((if .enabled == null then true else .enabled end) == true))
    | map(select((if .permissions == null then $d else .permissions end) == true))
    | map(.permissions_needed // [])
    | add // []
    | unique
    | sort
    | join(",")
  '
}

permissions_wizard() {
  local dry_run="$1"
  local force="$2"

  local perms_fp
  perms_fp="$(permissions_fingerprint)"
  if [ -z "$perms_fp" ]; then
    log "No macOS permissions listed in manifest; skipping."
    return 0
  fi

  log
  log "macOS permissions (manual) — cannot be auto-granted without MDM:"
  log "  Required: $perms_fp"

  if [ "$dry_run" = "1" ]; then
    log "DRY RUN: would open System Settings panes and prompt you to toggle the apps."
    return 0
  fi

  mkdir -p "$STAMPS_DIR"
  local stamp="$STAMPS_DIR/permissions.json"
  if [ "$force" = "0" ] && [ -f "$stamp" ]; then
    local prev
    prev="$(cat "$stamp" 2>/dev/null || true)"
    if [ "$prev" = "$perms_fp" ]; then
      log "Permissions wizard already completed for this manifest; skipping."
      return 0
    fi
  fi

  if ! tty_available; then
    log "No TTY available; printing checklist only (rerun from a terminal to step through System Settings)."
    return 0
  fi

  local perm url title
  IFS=',' read -r -a perm_list <<<"$perms_fp"
  for perm in "${perm_list[@]}"; do
    url="$(permission_url "$perm")"
    title="$(permission_title "$perm")"

    log
    log "== $title =="
    log "Enable the relevant toggles for:"
    printf '%s\n' "$MANIFEST_JSON" | jq -r --arg p "$perm" --argjson d "$DEFAULT_PERMISSIONS" '
      .apps[]
      | select((if .enabled == null then true else .enabled end) == true)
      | select((if .permissions == null then $d else .permissions end) == true)
      | select(((.permissions_needed // []) | index($p)) != null)
      | ("  - " + (.name // .id))
    '

    if [ -n "$url" ]; then
      read_tty_line "Press Enter to open System Settings for '$title'…" >/dev/null
      open "$url" >/dev/null 2>&1 || true
    else
      warn "No deep link available for permission: $perm"
    fi

    read_tty_line "Press Enter when you're done with '$title'…" >/dev/null
  done

  printf '%s\n' "$perms_fp" >"$stamp"
  log
  log "Permissions wizard complete."
}

plan_apps() {
  local manifest="$1"

  load_manifest "$manifest"

  log "GUI apps plan"
  log "  manifest: $manifest"
  log "  state:    $STATE_DIR"
  log

  if ! command -v brew >/dev/null 2>&1; then
    warn "brew not found; install checks will be incomplete."
  fi

  while IFS= read -r app; do
    local app_id app_name enabled
    app_id="$(printf '%s\n' "$app" | jq -r '.id')"
    app_name="$(printf '%s\n' "$app" | jq -r '.name // .id')"
    enabled="$(printf '%s\n' "$app" | jq -r 'if .enabled == null then true else .enabled end')"

    if [ "$enabled" != "true" ]; then
      log "- $app_name ($app_id): disabled"
      continue
    fi

    local install_enabled config_enabled launch_enabled permissions_enabled
    local config_mode brew_cask bundle_id

    install_enabled="$(printf '%s\n' "$app" | jq -r --argjson d "$DEFAULT_INSTALL" 'if .install == null then $d else .install end')"
    config_enabled="$(printf '%s\n' "$app" | jq -r --argjson d "$DEFAULT_CONFIG" 'if .config == null then $d else .config end')"
    launch_enabled="$(printf '%s\n' "$app" | jq -r --argjson d "$DEFAULT_LAUNCH" 'if .launch == null then $d else .launch end')"
    permissions_enabled="$(printf '%s\n' "$app" | jq -r --argjson d "$DEFAULT_PERMISSIONS" 'if .permissions == null then $d else .permissions end')"
    config_mode="$(printf '%s\n' "$app" | jq -r --arg d "$DEFAULT_CONFIG_MODE" '.config_mode // $d')"

    brew_cask="$(printf '%s\n' "$app" | jq -r '.brew_cask // ""')"
    bundle_id="$(printf '%s\n' "$app" | jq -r '.bundle_id // ""')"

    log "- $app_name ($app_id)"

    if [ "$install_enabled" = "true" ]; then
      if [ -n "$brew_cask" ] && command -v brew >/dev/null 2>&1; then
        if is_cask_installed "$brew_cask"; then
          log "    install: yes (cask: $brew_cask) [installed]"
        else
          log "    install: yes (cask: $brew_cask) [missing]"
        fi
      else
        log "    install: yes"
      fi
    else
      log "    install: no"
    fi

    if [ "$config_enabled" = "true" ]; then
      if config_supported "$app_id"; then
        local stamp
        stamp="$(stamp_path "$app_id" "config")"
        if [ "$config_mode" = "set_once" ] && [ -f "$stamp" ]; then
          log "    config:  yes (mode: $config_mode) [already applied]"
        else
          log "    config:  yes (mode: $config_mode)"
        fi
      else
        log "    config:  yes (unsupported; set config:false or add implementation)"
      fi
    else
      log "    config:  no"
    fi

    local license_enabled
    license_enabled="$(printf '%s\n' "$app" | jq -r --argjson d "$DEFAULT_LICENSE" 'if .license.enabled == null then $d else .license.enabled end')"
    if [ "$license_enabled" = "true" ]; then
      log "    license: yes (1Password)"
    else
      log "    license: no"
    fi

    if [ "$launch_enabled" = "true" ] && [ "${DOTFILES_START_APPS:-1}" != "0" ]; then
      if [ -n "$bundle_id" ]; then
        log "    launch:  yes (bundle_id: $bundle_id)"
      else
        log "    launch:  yes"
      fi
    else
      log "    launch:  no"
    fi

    if [ "$permissions_enabled" = "true" ]; then
      local perms
      perms="$(printf '%s\n' "$app" | jq -r '.permissions_needed // [] | join(",")')"
      if [ -n "$perms" ]; then
        log "    perms:   $perms"
      fi
    fi
  done < <(printf '%s\n' "$MANIFEST_JSON" | jq -c '.apps[]')

  log
  log "Permissions checklist (manual):"
  log "  $(permissions_fingerprint)"
}

apply_apps() {
  local manifest="$1"
  local dry_run="$2"
  local force="$3"

  load_manifest "$manifest"

  if [ "$dry_run" = "1" ]; then
    log "GUI apps apply (dry-run)"
  else
    log "GUI apps apply"
  fi
  log "  manifest: $manifest"
  log "  state:    $STATE_DIR"
  log

  ensure_cmd brew "install Homebrew first"

  # Keep password prompts to a minimum by requesting sudo once, early.
  request_sudo_keepalive

  if [ "$dry_run" = "0" ]; then
    mkdir -p "$STAMPS_DIR"
    mkdir -p "$SEED_DIR"
  fi

  while IFS= read -r app; do
    local app_id app_name enabled
    app_id="$(printf '%s\n' "$app" | jq -r '.id')"
    app_name="$(printf '%s\n' "$app" | jq -r '.name // .id')"
    enabled="$(printf '%s\n' "$app" | jq -r 'if .enabled == null then true else .enabled end')"

    if [ "$enabled" != "true" ]; then
      continue
    fi

    local install_enabled config_enabled launch_enabled permissions_enabled
    local config_mode brew_cask bundle_id

    install_enabled="$(printf '%s\n' "$app" | jq -r --argjson d "$DEFAULT_INSTALL" 'if .install == null then $d else .install end')"
    config_enabled="$(printf '%s\n' "$app" | jq -r --argjson d "$DEFAULT_CONFIG" 'if .config == null then $d else .config end')"
    launch_enabled="$(printf '%s\n' "$app" | jq -r --argjson d "$DEFAULT_LAUNCH" 'if .launch == null then $d else .launch end')"
    permissions_enabled="$(printf '%s\n' "$app" | jq -r --argjson d "$DEFAULT_PERMISSIONS" 'if .permissions == null then $d else .permissions end')"
    config_mode="$(printf '%s\n' "$app" | jq -r --arg d "$DEFAULT_CONFIG_MODE" '.config_mode // $d')"

    brew_cask="$(printf '%s\n' "$app" | jq -r '.brew_cask // ""')"
    bundle_id="$(printf '%s\n' "$app" | jq -r '.bundle_id // ""')"

    log "== $app_name =="

    if [ "$install_enabled" = "true" ] && [ -n "$brew_cask" ]; then
      if is_cask_installed "$brew_cask"; then
        log "Already installed (cask): $brew_cask"
      else
        if [ "$dry_run" = "1" ]; then
          log "DRY RUN: would install (cask): $brew_cask"
        else
          log "Installing (cask): $brew_cask"
          install_cask "$brew_cask"
        fi
      fi
    fi

    if [ "$config_enabled" = "true" ]; then
      if ! config_supported "$app_id"; then
        die "Config requested but not supported for app id: $app_id (set config:false or implement it)"
      fi

      local config_stamp
      config_stamp="$(stamp_path "$app_id" "config")"
      if [ "$config_mode" = "set_once" ] && [ "$force" = "0" ] && [ -f "$config_stamp" ]; then
        log "Config (set_once): already applied; skipping."
      else
        if [ "$dry_run" = "1" ]; then
          log "DRY RUN: would apply config (mode: $config_mode)"
        else
          log "Applying config (mode: $config_mode)…"
          mkdir -p "$STAMPS_DIR"
          mkdir -p "$SEED_DIR"
          apply_config_for_app "$app_id" "$config_mode"
          printf '%s\n' "$(timestamp)" >"$config_stamp"
        fi
      fi
    fi

    local license_enabled license_mode license_stamp
    license_enabled="$(printf '%s\n' "$app" | jq -r --argjson d "$DEFAULT_LICENSE" 'if .license.enabled == null then $d else .license.enabled end')"
    license_mode="$(printf '%s\n' "$app" | jq -r --arg d "$DEFAULT_LICENSE_MODE" '.license.mode // $d')"
    if [ "$license_enabled" = "true" ]; then
      license_stamp="$(stamp_path "$app_id" "license")"
      if [ "$license_mode" = "set_once" ] && [ "$force" = "0" ] && [ -f "$license_stamp" ]; then
        log "License (set_once): already applied; skipping."
      else
        if [ "$dry_run" = "1" ]; then
          log "DRY RUN: would verify 1Password access + install license"
          op_preflight
          local op_uri
          op_uri="$(printf '%s\n' "$app" | jq -r '.license.op_uri // \"\"')"
          if [ -n "$op_uri" ]; then
            op read "$op_uri" >/dev/null
          fi
        else
          log "Installing license…"
          mkdir -p "$STAMPS_DIR"
          apply_license_for_app "$app_id" "$app"
          printf '%s\n' "$(timestamp)" >"$license_stamp"
        fi
      fi
    fi

    if [ "$launch_enabled" = "true" ] && [ "${DOTFILES_START_APPS:-1}" != "0" ]; then
      if [ "$dry_run" = "1" ]; then
        log "DRY RUN: would launch"
      else
        open_bundle_id "$bundle_id" "$app_name"
      fi
    fi

    if [ "$permissions_enabled" = "true" ] && [ "$dry_run" = "1" ]; then
      local perms
      perms="$(printf '%s\n' "$app" | jq -r '.permissions_needed // [] | join(\",\")')"
      if [ -n "$perms" ]; then
        log "DRY RUN: permissions needed: $perms"
      fi
    fi

    log
  done < <(printf '%s\n' "$MANIFEST_JSON" | jq -c '.apps[]')

  permissions_wizard "$dry_run" "$force"

  log
  if [ "$dry_run" = "1" ]; then
    log "Dry-run complete (no installs/config changes applied)."
    log "To apply for real: ./scripts/macos/gui-apps.sh apply --dry-run=false"
  else
    log "Done."
  fi
}

cmd="${1:-}"
case "$cmd" in
  plan)
    shift
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --manifest)
          MANIFEST_PATH="$2"
          shift 2
          ;;
        --manifest=*)
          MANIFEST_PATH="${1#*=}"
          shift
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        *)
          die "Unknown arg: $1"
          ;;
      esac
    done
    ensure_macos
    plan_apps "$MANIFEST_PATH"
    ;;
  apply)
    shift
    dry_run="1"
    force="0"
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --manifest)
          MANIFEST_PATH="$2"
          shift 2
          ;;
        --manifest=*)
          MANIFEST_PATH="${1#*=}"
          shift
          ;;
        --dry-run)
          dry_run="1"
          shift
          ;;
        --dry-run=true)
          dry_run="1"
          shift
          ;;
        --dry-run=false)
          dry_run="0"
          shift
          ;;
        --dry-run=*)
          case "${1#*=}" in
            true) dry_run="1" ;;
            false) dry_run="0" ;;
            *)
              die "Invalid --dry-run value: ${1#*=} (expected true|false)"
              ;;
          esac
          shift
          ;;
        --force)
          force="1"
          shift
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        *)
          die "Unknown arg: $1"
          ;;
      esac
    done
    ensure_macos
    if [ "$dry_run" = "0" ] && tty_available && [ "${DOTFILES_GUI_APPS_YES:-0}" != "1" ]; then
      echo
      echo "About to apply macOS GUI apps from:"
      echo "  $MANIFEST_PATH"
      echo
      echo "This will install apps, apply configs, launch apps, and guide permissions."
      answer="$(read_tty_line "Continue? [y/N] ")"
      case "$answer" in
        y|Y|yes|YES) ;;
        *) echo "Aborted."; exit 0 ;;
      esac
    fi
    apply_apps "$MANIFEST_PATH" "$dry_run" "$force"
    ;;
  -h|--help|"")
    usage
    ;;
  *)
    die "Unknown command: $cmd (expected: plan|apply)"
    ;;
esac
