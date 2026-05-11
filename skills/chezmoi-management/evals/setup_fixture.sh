#!/usr/bin/env bash
# Copy an eval fixture into a fresh per-run working dir.
# Usage: setup_fixture.sh <fixture_name> <dest_dir>
# Available fixtures: see evals/files/ (one directory per eval).
#
# Safety model: this script REFUSES to operate on a pre-existing DEST. No
# `rm -rf` is performed — that closes the TOCTOU window between path
# validation and destructive operation. If you want to re-run a fixture,
# pick a fresh DEST or delete the prior one yourself.
#
# Additionally, DEST must be absolute, must not equal $HOME, /, the skill
# directory, or the experiment root, and must be a STRICT CHILD of one of:
# $TMPDIR (only the validated leaf under /tmp or /var/folders, NOT those
# directories themselves), $DOTFILES_SKILL_SCRATCH (if set and not a broad
# system path), or <experiment-repo>/chezmoi-management-workspace/.

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <fixture_name> <dest_dir>" >&2
  exit 2
fi

FIXTURE="$1"
DEST="$2"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXPERIMENT_ROOT="$(cd "$SKILL_DIR/.." && pwd)"
SRC="$SKILL_DIR/evals/files/$FIXTURE"

if [[ ! -d "$SRC" ]]; then
  echo "Fixture not found: $SRC" >&2
  exit 1
fi

# Resolve `.`/`..`/symlinks even for nonexistent paths.
realpath_safe() {
  realpath -m -- "$1" 2>/dev/null \
    || python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1"
}

# --- Safety checks on DEST before rm -rf ---

if [[ "$DEST" != /* ]]; then
  echo "DEST must be an absolute path; got: $DEST" >&2
  exit 1
fi

DEST_RESOLVED="$(realpath_safe "$DEST")"

# System and user broad paths. These can never be DEST, can never be
# DOTFILES_SKILL_SCRATCH, and can never serve as an allowlist root.
# /var/folders is in here because it contains every macOS user's per-process
# temp namespace; only the *validated TMPDIR leaf* under it should be allowed.
SYSTEM_BROAD=(
  "/" "/private" "/var" "/var/folders" "/var/tmp" "/usr" "/usr/local"
  "/etc" "/bin" "/sbin" "/opt" "/Library" "/System" "/Volumes" "/Users"
  "/tmp" "/private/tmp" "/private/var" "/private/var/folders"
  "$HOME" "$SKILL_DIR" "$EXPERIMENT_ROOT"
)

is_broad() {
  local needle="$1" b
  for b in "${SYSTEM_BROAD[@]}"; do
    [[ -z "$b" ]] && continue
    if [[ "$needle" == "$b" ]]; then return 0; fi
  done
  return 1
}

if is_broad "$DEST_RESOLVED"; then
  echo "Refusing to rm -rf broad path: $DEST_RESOLVED" >&2
  exit 1
fi

# Refuse if DEST_RESOLVED is an ancestor of the skill directory (would wipe the skill).
case "$SKILL_DIR/" in
  "$DEST_RESOLVED"/*) echo "Refusing: DEST ($DEST_RESOLVED) contains the skill directory" >&2; exit 1 ;;
esac

# Validate DOTFILES_SKILL_SCRATCH if set: must not itself be a broad path,
# and must not be an ancestor of any broad path.
if [[ -n "${DOTFILES_SKILL_SCRATCH:-}" ]]; then
  SCRATCH_RESOLVED="$(realpath_safe "$DOTFILES_SKILL_SCRATCH")"
  if is_broad "$SCRATCH_RESOLVED"; then
    echo "Refusing: DOTFILES_SKILL_SCRATCH ($SCRATCH_RESOLVED) is a broad/system path." >&2
    exit 1
  fi
  for BAD in "${SYSTEM_BROAD[@]}"; do
    [[ -z "$BAD" || "$BAD" == "/" ]] && continue
    case "$BAD/" in
      "$SCRATCH_RESOLVED"/*)
        echo "Refusing: DOTFILES_SKILL_SCRATCH ($SCRATCH_RESOLVED) contains a broad path ($BAD)." >&2
        exit 1
        ;;
    esac
  done
fi

# Build the allowed-roots list. CRITICAL: /tmp and /var/folders are NOT in
# the allowed roots themselves — only paths under them via the validated
# TMPDIR leaf, an explicit DOTFILES_SKILL_SCRATCH, or the workspace dir.
# Without this, `DEST=/private/var/folders/zz` (another user's temp namespace)
# would pass strict-child against `/var/folders`.
TMP_RESOLVED="$(realpath_safe /tmp)"
VARF_RESOLVED="$(realpath_safe /var/folders)"
declare -a ALLOWED_ROOTS=("$TMP_RESOLVED")   # only /tmp itself; TMPDIR leaves added explicitly below

if [[ -n "${TMPDIR:-}" ]]; then
  TMPDIR_RESOLVED="$(realpath_safe "$TMPDIR")"
  # Must be a STRICT CHILD of /tmp or /var/folders — equality already broad-rejected.
  case "$TMPDIR_RESOLVED" in
    "$TMP_RESOLVED"/*|"$VARF_RESOLVED"/*)
      if ! is_broad "$TMPDIR_RESOLVED"; then
        ALLOWED_ROOTS+=("$TMPDIR_RESOLVED")
      fi
      ;;
    *)
      echo "Warning: TMPDIR ($TMPDIR_RESOLVED) is not a strict child of /tmp or /var/folders; ignoring it." >&2
      ;;
  esac
fi

if [[ -n "${DOTFILES_SKILL_SCRATCH:-}" ]]; then
  ALLOWED_ROOTS+=("$(realpath_safe "$DOTFILES_SKILL_SCRATCH")")
fi

ALLOWED_ROOTS+=("$(realpath_safe "$EXPERIMENT_ROOT/chezmoi-management-workspace")")

# DEST must not be equal to ANY allowed root. A path can be both a root in
# its own right (e.g., $TMPDIR) and a strict child of a broader root
# (/var/folders); rejecting equality against every root closes that loop.
for ROOT in "${ALLOWED_ROOTS[@]}"; do
  if [[ "$DEST_RESOLVED" == "$ROOT" ]]; then
    echo "Refusing: DEST ($DEST_RESOLVED) is an allowed scratch root itself; pick a path UNDER it." >&2
    echo "  Allowed roots: ${ALLOWED_ROOTS[*]}" >&2
    exit 1
  fi
done

# DEST must be a strict child of at least one allowed root.
ALLOWED=0
for ROOT in "${ALLOWED_ROOTS[@]}"; do
  if [[ "$DEST_RESOLVED" == "$ROOT"/* ]]; then
    ALLOWED=1
    break
  fi
done

if [[ "$ALLOWED" -ne 1 ]]; then
  echo "Refusing: DEST ($DEST_RESOLVED) is not under a known scratch root." >&2
  echo "  Allowed roots: ${ALLOWED_ROOTS[*]}" >&2
  echo "  Set DOTFILES_SKILL_SCRATCH to add an additional root, or pick a path under \$TMPDIR." >&2
  exit 1
fi

# Refuse to operate on a pre-existing DEST. No rm -rf — eliminates the
# TOCTOU window between path validation and a destructive operation.
if [[ -e "$DEST_RESOLVED" || -L "$DEST_RESOLVED" ]]; then
  echo "Refusing: DEST ($DEST_RESOLVED) already exists. Pick a fresh path or remove it first." >&2
  exit 1
fi

# Create parents (idempotent), then create the leaf ATOMICALLY without -p
# so it fails if another process raced in with a symlink-to-dir between
# our existence check and mkdir. After mkdir, double-check it is not a
# symlink — defense-in-depth.
mkdir -p -- "$(dirname -- "$DEST_RESOLVED")"
if ! mkdir -m 0700 -- "$DEST_RESOLVED" 2>/dev/null; then
  echo "Refusing: failed to atomically create DEST ($DEST_RESOLVED). Path may have appeared after the existence check (race)." >&2
  exit 1
fi
if [[ -L "$DEST_RESOLVED" ]]; then
  echo "Refusing: DEST ($DEST_RESOLVED) is a symlink after mkdir; aborting before copy." >&2
  exit 1
fi

cp -R "$SRC"/. "$DEST_RESOLVED"/

echo "Fixture ready at $DEST_RESOLVED"
