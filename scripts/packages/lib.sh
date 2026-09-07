#!/usr/bin/env bash
#
# lib.sh — shared helpers for the scripts/packages renderers.
# Source this; do not execute it.

# render_chezmoi_template --template <path> [--machine-type <name>]
#                         [--output <file>] [--env KEY=VALUE]...
#
# Renders a home/.chezmoitemplates fragment. Without --machine-type the render
# follows the user's own chezmoi config (the current machine); without --output
# it writes to stdout.
render_chezmoi_template() {
  local template="" machine_type="" output=""
  local -a env_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --template) template="$2"; shift 2 ;;
      --machine-type) machine_type="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --env) env_args+=("$2"); shift 2 ;;
      *) printf 'render_chezmoi_template: unknown argument: %s\n' "$1" >&2; return 2 ;;
    esac
  done

  [[ -f $template ]] || { printf 'render: missing template: %s\n' "$template" >&2; return 1; }

  local repo_root
  repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

  # Subshell so the temp config and staged output clean themselves up on any
  # exit path without stomping the caller's EXIT trap.
  (
    local -a config_args=()
    local scratch
    scratch="$(mktemp -d)"
    trap 'rm -rf "$scratch"' EXIT

    if [[ -n $machine_type ]]; then
      # Pin the machine type through a dedicated temp chezmoi config rather than
      # --override-data: a temp --config makes chezmoi IGNORE the user's own
      # config, so a host-local [data.machines_local] (e.g. a groups override)
      # cannot leak into this canonical per-type render. --override-data would
      # merge over the user's config and let machines_local win.
      #
      # chezmoi infers config format from the extension, so the file must be
      # named *.toml; it lives in the scratch dir since BSD mktemp templates
      # end in X's.
      printf '[data]\nmachine_type = "%s"\n' "$machine_type" >"$scratch/chezmoi.toml"
      config_args+=(--config "$scratch/chezmoi.toml")
    fi

    # --source pins the source dir so the renderer works from any cwd and under
    # any user's home chezmoi config. ${arr[@]+"${arr[@]}"} keeps empty arrays
    # safe under macOS Bash 3.2 + set -u.
    render() {
      env -u DOTFILES_INSTALL_MAS_APPS \
        ${env_args[@]+"${env_args[@]}"} \
        chezmoi --source "$repo_root/home" \
        ${config_args[@]+"${config_args[@]}"} \
        execute-template --file "$template"
    }

    if [[ -n $output ]]; then
      render >"$scratch/out"
      mv "$scratch/out" "$output"
    else
      render
    fi
  )
}
