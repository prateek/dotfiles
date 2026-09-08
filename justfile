set shell := ["bash", "-euo", "pipefail", "-c"]
set quiet := true

# agent-marketplace also holds vendored third-party suites, so roots stay explicit.
python_roots := "tests/config_merge tests/python agent-marketplace/packages/ios/skills/ios-audit/tests"
node_tests := "home/dot_local/share/raycast-extensions/orca-worktree/tests/*.test.mjs"
test_bash := env("TEST_BASH", "bash")
docs_base := env("DOCS_LIFECYCLE_BASE", "HEAD")
tart_image := env("TART_IMAGE", "ghcr.io/cirruslabs/macos-tahoe-base:latest")
# An explicit TART_IMAGE pins both lanes; only the full lane's default differs.
tart_full_image := env("TART_FULL_IMAGE", env("TART_IMAGE", "ghcr.io/cirruslabs/macos-tahoe-xcode:latest"))
tart_cpu := env("TART_CPU", "2")
tart_memory := env("TART_MEMORY", "4096")

# Staged validation reuses the parent runtime instead of resolving mise per recipe.
mise_env := if env("DOTFILES_TEST_RUNTIME_READY", "") == "1" { "" } else { "mise exec -- env DOTFILES_TEST_RUNTIME_READY=1" }

[private]
default: test

# Run the macOS CI lane: marketplace, static, shell, python, node, chezmoi dry-runs.
test: test-ci

# Install pinned test runners and assertion libraries.
test-tools:
    mise run test-tools

# Compose the same suites the macOS CI lane runs.
[group('suite')]
test-ci:
    DOTFILES_SKIP_LAUNCHCTL_SYNC=1 GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
      mise exec -- env DOTFILES_TEST_RUNTIME_READY=1 \
      just _test-ci-suites

[private]
_test-ci-suites: test-agent-marketplace test-static test-shell test-python test-node test-chezmoi-apply

# Bats cases. Focus with a path and/or flags, and BATS_TAGS= to select tagged lanes.
[group('suite')]
test-shell *args:
    {{ mise_env }} "{{ test_bash }}" scripts/tests/shell {{ if args == "" { "tests/bats" } else { args } }}

# Native Python cases across every safe root. Focus with `-k <substring>`.
[group('suite')]
test-python *args:
    DOTFILES_SKIP_LAUNCHCTL_SYNC=1 {{ mise_env }} python3 -B scripts/tests/python {{ python_roots }} {{ args }}

# Native Node cases, which stay with the extension that owns them.
[group('suite')]
test-node *args:
    {{ mise_env }} bash scripts/tests/node {{ node_tests }} {{ args }}

# Syntax and docs checks that need no behaviour fixtures.
[group('suite')]
test-static: check-docs-lifecycle
    {{ mise_env }} zsh -n scripts/trace/run-zsh
    {{ mise_env }} python3 -c 'import ast, pathlib; [ast.parse(pathlib.Path(p).read_text(), filename=p) for p in ("scripts/trace/xtrace-to-perfetto", "scripts/trace/merge-perfetto", "scripts/trace/open-perfetto")]'

# Preview chezmoi apply for every machine type to catch template errors before commit.
[group('suite')]
test-chezmoi-apply:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v chezmoi >/dev/null 2>&1 || { echo "Missing chezmoi for apply validation" >&2; exit 1; }
    for type in ci personal work; do
      {{ mise_env }} ./scripts/chezmoi/test-apply-dry-run.sh "$type" "{{ justfile_directory() }}"
    done

# Validate this checkout's docs frontmatter against DOCS_LIFECYCLE_BASE.
check-docs-lifecycle:
    #!/usr/bin/env bash
    set -euo pipefail
    base="{{ docs_base }}"
    if [ "$base" = none ]; then
      {{ mise_env }} python3 -B docs/validate-doc-lifecycle.py
    elif git rev-parse --verify "$base^{commit}" >/dev/null 2>&1; then
      {{ mise_env }} python3 -B docs/validate-doc-lifecycle.py --base "$base"
    else
      echo "Missing docs lifecycle base '$base'. Fetch it or set DOCS_LIFECYCLE_BASE=<ref>; use DOCS_LIFECYCLE_BASE=none only for current-tree checks." >&2
      exit 1
    fi

# The validator's own fixtures plus this checkout.
test-docs-lifecycle: && check-docs-lifecycle
    {{ mise_env }} python3 -B scripts/tests/python tests/python/docs -t tests/python

# Native acquisition, pristine cache, publication, and patch contracts.
test-agent-marketplace:
    cd agent-marketplace && {{ mise_env }} just check

# Host lane: exercises real materialization through installed Claude and Codex CLIs.
test-agent-skill-packages-native: test-agent-marketplace
    BATS_TAGS=host just test-shell tests/bats/agents/native-plugins.bats

# Crit failure-mode evals: spends tokens and needs network, so it is opt-in.
test-crit-evals *args:
    ./scripts/crit-evals {{ args }}

# mode: verify (authoritative correctness), bench (pinned zsh-bench), selftest (validator's own cases).
zsh-fresh-shells mode="verify":
    zsh ./scripts/audit/zsh-fresh-shells.zsh {{ mode }} --dotfiles-root "{{ justfile_directory() }}"

# Compare tracked Orca settings against the installed app and refresh the snapshot.
audit-orca-settings:
    bash ./scripts/audit/orca-settings.sh

# Install the launch agent that syncs agent sessions to the archive.
install-session-sync-app:
    bash ./scripts/agent-sessions/install-sync-app

# lane: smoke (base image, casks skipped) or full (Xcode image). Add --dry-run to skip installs.
test-install-tart lane="smoke" *flags:
    ./scripts/vm/test-install-tart.sh --lane {{ lane }} \
      --image "{{ if lane == "full" { tart_full_image } else { tart_image } }}" \
      --cpu "{{ tart_cpu }}" --memory "{{ tart_memory }}" {{ flags }}

# Long-lived VM for the inner loop. verb: apply, create, bootstrap, refresh, destroy.
warm-tart verb="apply":
    ./scripts/vm/warm-tart {{ verb }}
