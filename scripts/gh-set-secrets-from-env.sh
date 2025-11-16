#!/usr/bin/env bash
set -euo pipefail

# Sets GitHub Actions repository secrets using values from a .env file.
# - Resolves the GitHub repo slug from the git remote named "oai-remote" by default.
# - Safely pipes each secret value to `gh secret set` to avoid leaking via process args.
#
# Requirements:
# - gh (GitHub CLI) authenticated with access to the target repository
# - git, sed, awk (standard macOS/Linux tooling)
#
# Usage:
#   scripts/gh-set-secrets-from-env.sh [--remote <name>] [--env-file <path>] [--dry-run]
#     --remote, -r    Git remote to read repo from (default: oai-remote)
#     --env-file, -e  Path to .env file (default: <git root>/.env)
#     --dry-run       Print which secrets would be set without calling gh
#     -h, --help      Show help
#
# Notes on .env parsing:
# - Lines beginning with '#' are ignored.
# - Supports KEY=VALUE, optional leading 'export '.
# - Values wrapped in single or double quotes will have the quotes removed.
# - Escaped '\n' and '\r' sequences inside double-quoted values are converted to newlines/CR.
# - Inline comments are NOT stripped to avoid corrupting values containing '#'.
#
# Example:
#   scripts/gh-set-secrets-from-env.sh
#   scripts/gh-set-secrets-from-env.sh -r oai-remote -e ./config/.env.production
#   scripts/gh-set-secrets-from-env.sh --dry-run

print_usage() {
  sed -n '1,50p' "$0" | sed -n '/^# Usage:/,$p' | sed 's/^# \{0,1\}//'
}

REMOTE_NAME="oai-remote"
GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${GIT_ROOT}" ]]; then
  echo "Error: not inside a git repository." >&2
  exit 1
fi
ENV_FILE="${GIT_ROOT}/.env"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--remote)
      [[ $# -ge 2 ]] || { echo "Error: --remote requires a value" >&2; exit 1; }
      REMOTE_NAME="$2"
      shift 2
      ;;
    -e|--env-file)
      [[ $# -ge 2 ]] || { echo "Error: --env-file requires a value" >&2; exit 1; }
      ENV_FILE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Use --help for usage." >&2
      exit 1
      ;;
  esac
done

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: gh CLI is not installed. See https://cli.github.com/" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is not installed." >&2
  exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Error: .env file not found at: ${ENV_FILE}" >&2
  exit 1
fi

# Resolve owner/repo from the specified remote
REMOTE_URL="$(git remote get-url "${REMOTE_NAME}" 2>/dev/null || true)"
if [[ -z "${REMOTE_URL}" ]]; then
  echo "Error: remote '${REMOTE_NAME}' not found." >&2
  exit 1
fi

# Support common remote URL formats:
# - git@github.com:owner/repo.git
# - https://github.com/owner/repo.git
# - https://github.com/owner/repo
REPO_SLUG=""
if [[ "${REMOTE_URL}" =~ github\.com[:/]{1}([^/]+/[^/.]+)(\.git)?$ ]]; then
  REPO_SLUG="${BASH_REMATCH[1]}"
fi

if [[ -z "${REPO_SLUG}" ]]; then
  echo "Error: could not parse GitHub repo slug from remote URL: ${REMOTE_URL}" >&2
  exit 1
fi

# Verify repo is accessible (optional but helpful)
if [[ "${DRY_RUN}" -eq 0 ]]; then
  if ! gh repo view -R "${REPO_SLUG}" >/dev/null 2>&1; then
    echo "Error: cannot access repo '${REPO_SLUG}'. Ensure 'gh auth login' has sufficient permissions." >&2
    exit 1
  fi
fi

echo "Target repository: ${REPO_SLUG} (remote: ${REMOTE_NAME})"
echo "Reading secrets from: ${ENV_FILE}"
[[ "${DRY_RUN}" -eq 1 ]] && echo "[DRY RUN] No changes will be made."

# Read .env file line-by-line without evaluation
while IFS= read -r raw_line || [[ -n "${raw_line}" ]]; do
  # Trim leading/trailing whitespace
  line="${raw_line#"${raw_line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"

  # Skip empty or comment lines
  [[ -z "${line}" ]] && continue
  [[ "${line}" =~ ^# ]] && continue

  # Strip optional 'export ' prefix
  if [[ "${line}" =~ ^export[[:space:]]+ ]]; then
    line="${line#export }"
  fi

  # Require KEY=VALUE format with a valid dotenv key
  if [[ ! "${line}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
    continue
  fi

  key="${line%%=*}"
  value="${line#*=}"

  # Remove surrounding single/double quotes if present
  if [[ "${value}" =~ ^\".*\"$ ]]; then
    value="${value:1:-1}"
    # Translate common escaped sequences in double-quoted values
    value="${value//\\n/$'\n'}"
    value="${value//\\r/$'\r'}"
    value="${value//\\t/$'\t'}"
    value="${value//\\\"/\"}"
    value="${value//\\\\/\\}"
  elif [[ "${value}" =~ ^\'.*\'$ ]]; then
    value="${value:1:-1}"
  fi

  # Remove any trailing CR from Windows line endings
  value="${value%$'\r'}"

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "Would set secret '${key}' in repo '${REPO_SLUG}'"
    continue
  fi

  # Safely pipe value via stdin to avoid exposing in process list
  # Use --app actions to explicitly target Actions secrets.
  printf '%s' "${value}" | gh secret set "${key}" -R "${REPO_SLUG}" --app actions --body-file - >/dev/null
  echo "Set secret '${key}'"
done < "${ENV_FILE}"

echo "Done."
