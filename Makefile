.PHONY: test-shell test-tools
BATS_PATH ?= tests/bats
BATS_ARGS ?=
TEST_BASH ?= bash
# Staged validation reuses the parent runtime instead of loading copied mise config.
TEST_ENV = $(if $(filter 1,$(DOTFILES_TEST_RUNTIME_READY)),,mise exec -- env DOTFILES_TEST_RUNTIME_READY=1)

.PHONY: test-config-merge test-tuna-plist test test-chezmoi-apply hammerspoon hammerspoon-check hammerspoon-reload
.PHONY: test-gemini-meeting-sync test-ghc test-gh-extensions-script test-mise-install-script test-xcode-install-script test-secret-backed-files test-kanata-config test-karabiner-goku test-chezmoi-config test-chezmoi-local-ignores test-chezmoi-script-status test-chezmoi-drift-banner test-agents-doc-pointers test-finder-copy-path test-codex-config test-cursor-cli-alias test-cursor-config test-agentsview-config test-reconcile-wiki-clone test-claude-settings test-claude-statusline test-pi-settings test-pi-statusline test-orca-settings test-crit-config test-vendor-skill-patches test-crit-evals test-agent-skill-packages test-agent-skill-packages-native test-ios-audit test-cmux-plist test-orbstack-plist test-selected-app-plists test-thaw-plist test-package-gated-configs test-machines-features test-elevation-render test-moom-plist test-nvalt-colors test-nvalt-plist test-voiceink-plist test-tartelet-settings test-tartelet-softnet-wrapper test-plist-hooks test-sudo-keepalive test-macos-defaults-script test-acpx-model-drift test-acpx-poll-stream test-brew-inventory test-brew-install-wrapper test-brew-bundle-script test-fork-reconcile test-retired-packages test-render-brewfile test-docs-lifecycle test-repo-index test-raycast-orca-worktree test-skill-console test-raycast-extensions-script
.PHONY: test-zed-settings test-zsh-prompt-host test-zsh-fresh-shells verify-zsh-fresh-shells bench-zsh-startup
.PHONY: test-host-mounts
.PHONY: test-tart-install-helper test-trace-perfetto test-vm-install-log-scan test-vm-postflight-macos test-install-tart-dry-run test-install-tart-smoke test-install-tart-full test-install-tart-warm test-install-tart-warm-bootstrap test-install-tart-warm-refresh test-install-tart-warm-destroy

HAMMERSPOON_SRC := home/dot_hammerspoon/init.fnl
HAMMERSPOON_OUT := build/hammerspoon/init.generated.lua
TART_IMAGE ?= ghcr.io/cirruslabs/macos-tahoe-base:latest
TART_SMOKE_IMAGE ?= $(TART_IMAGE)
ifneq ($(filter command line environment,$(origin TART_IMAGE)),)
TART_FULL_IMAGE ?= $(TART_IMAGE)
else
TART_FULL_IMAGE ?= ghcr.io/cirruslabs/macos-tahoe-xcode:latest
endif
TART_CPU ?= 2
TART_MEMORY ?= 4096
TART_FLAGS ?=
DOCS_LIFECYCLE_BASE ?= HEAD

## Compile Hammerspoon config (Fennel -> Lua).
hammerspoon: $(HAMMERSPOON_OUT)

$(HAMMERSPOON_OUT): $(HAMMERSPOON_SRC)
	@command -v fennel >/dev/null 2>&1 || { echo "Missing 'fennel' (brew install fennel)"; exit 1; }
	@mkdir -p $(dir $(HAMMERSPOON_OUT))
	@fennel --compile $(HAMMERSPOON_SRC) > $(HAMMERSPOON_OUT).tmp
	@mv $(HAMMERSPOON_OUT).tmp $(HAMMERSPOON_OUT)

## Compile and validate generated Lua (syntax only).
hammerspoon-check: hammerspoon
	@command -v luac >/dev/null 2>&1 || { echo "Missing 'luac' (brew install lua)"; exit 1; }
	@luac -p $(HAMMERSPOON_OUT)

## Compile and reload Hammerspoon (requires hs.ipc loaded).
hammerspoon-reload: hammerspoon
	@command -v hs >/dev/null 2>&1 || { echo "Missing 'hs' CLI"; exit 1; }
	@hs -c 'hs.reload(); "ok"' -q

## Default validation follows the macOS CI lane.
test: test-ci

## Validate chezmoi apply --dry-run to catch template errors before commit.
test-chezmoi-apply:
	@command -v chezmoi >/dev/null 2>&1 || { echo "Missing chezmoi for apply validation" >&2; exit 1; }
	@$(TEST_ENV) ./scripts/chezmoi/test-apply-dry-run.sh ci "$(CURDIR)"
	@$(TEST_ENV) ./scripts/chezmoi/test-apply-dry-run.sh personal "$(CURDIR)"
	@$(TEST_ENV) ./scripts/chezmoi/test-apply-dry-run.sh work "$(CURDIR)"

## Validate convention pointers and convention-doc reachability.
test-agents-doc-pointers:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_convention_pointers.py

## Validate the Finder Copy Paths Quick Action.
test-finder-copy-path:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_finder.py

## Regression tests for the focused Brewfile renderer.
test-render-brewfile:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_brewfile.py

## Validate the Pure hostname prefix: machine_type -> color and hook behavior.
test-zsh-prompt-host:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/programs/prompt-host.bats

## Validate docs lifecycle frontmatter, routing, and historical doc edits.
test-docs-lifecycle:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python/docs -t tests/python -p 'test_*.py'
	@$(MAKE) --no-print-directory check-docs-lifecycle

.PHONY: check-docs-lifecycle
check-docs-lifecycle:
	@base="$(DOCS_LIFECYCLE_BASE)"; \
	if [ "$$base" = "none" ]; then \
		$(TEST_ENV) python3 -B docs/validate-doc-lifecycle.py; \
	else \
		if ! git rev-parse --verify "$$base^{commit}" >/dev/null 2>&1; then \
			echo "Missing docs lifecycle base '$$base'. Fetch it or set DOCS_LIFECYCLE_BASE=<ref>; use DOCS_LIFECYCLE_BASE=none only for current-tree checks." >&2; \
			exit 1; \
		fi; \
		$(TEST_ENV) python3 -B docs/validate-doc-lifecycle.py --base "$$base"; \
	fi

## Regression tests for Gemini meeting sync wrapper config.
test-gemini-meeting-sync:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/programs/gemini-meeting-sync.bats

## E2E tests for ghc/ohc URL handling.
test-ghc:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/programs/github-checkout.bats

## Unit tests for the Raycast Orca worktree extension core.
test-raycast-orca-worktree:
	@$(TEST_ENV) bash scripts/tests/node ./home/dot_local/share/raycast-extensions/orca-worktree/tests/*.test.mjs

## Contract tests for the Raycast extension build hook (digest-gated rebuilds).
test-raycast-extensions-script:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/packages/raycast-extensions.bats

## Regression tests for mise runtime install script ordering.
test-mise-install-script:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/packages/mise-install.bats

## Regression tests for gh extensions install script.
test-gh-extensions-script:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/packages/gh-extensions.bats

## Regression tests for Xcode install script ordering.
test-xcode-install-script:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/packages/xcode-install.bats

## Regression tests for secret-backed private files.
test-secret-backed-files:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/config/secrets.bats

## Validate Kanata keyboard remap config with kanata's parser.
test-kanata-config:
	@BATS_TAGS=host $(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/config/kanata.bats

## Validate the Goku EDN compiles to the expected karabiner.json rules.
test-karabiner-goku:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/config/karabiner.bats BATS_TAGS=host

## Regression tests for generated chezmoi config defaults.
test-chezmoi-config:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_chezmoi.py -k initialization

## Regression tests for ignored machine-local chezmoi state.
test-chezmoi-local-ignores:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_chezmoi.py -k unmanaged

## Regression tests for steady-state chezmoi script status.
test-chezmoi-script-status:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/hooks/chezmoi-status.bats

## Regression tests for the cached chezmoi drift shell banner.
test-chezmoi-drift-banner:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/hooks/drift-banner.bats

## Regression tests for Codex config merging.
test-codex-config:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_codex.py

## Regression test for the Cursor CLI shell launcher.
test-cursor-cli-alias:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/programs/cursor-launcher.bats

## Regression tests for the ~/.cursor/cli-config.json modify-script merge.
test-cursor-config:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_cursor.py

## Regression tests for agentsview config merging (codex_sessions_dirs).
test-agentsview-config:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_agentsview.py

## Regression tests for the wiki-agent-sessions clone-shape helper (full vs sparse).
test-reconcile-wiki-clone:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/agents/wiki-clone.bats

.PHONY: install-session-sync-app
install-session-sync-app:
	@bash ./scripts/agent-sessions/install-sync-app

## Regression tests for Claude Code settings merging.
test-claude-settings:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_claude.py

## Regression tests for the Claude Code status line script.
test-claude-statusline:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_statuslines.py -k ClaudeStatuslineTests

## Regression tests for Pi settings, plugin marketplace, and isolated launcher.
test-pi-settings:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_pi.py
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/programs/pi-isolated-run.bats

## Regression tests for the Pi status line script.
test-pi-statusline:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_statuslines.py -k PiStatuslineTests

## Regression tests for Orca settings merging.
test-orca-settings:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_orca.py

## Regression tests for crit's agent_cmd modify script and the acpx shortcut render.
test-crit-config:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_crit.py

## Regression tests for the vendored-skill patch layer (local deltas stay applied).
test-vendor-skill-patches:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_vendor_patches.py

## Behavioural evals for the crit failure modes (F1-F4), driven through acpx.
## Costs tokens and needs network, so it is on-demand: run it after re-vendoring
## or changing the crit skills, not on every PR. Narrow a run with e.g.
## CRIT_EVAL_ARGS='--case f4-cli-shape --agents agpt,afable'.
test-crit-evals:
	@./scripts/crit-evals $(CRIT_EVAL_ARGS)

## Regression tests for acpx pinned-model drift reporting.
test-acpx-model-drift:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/agents/model-drift.bats

## Regression tests for the acpx poll-stream blocking log-growth helper.
test-acpx-poll-stream:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/programs/poll-stream.bats

## Regression tests for agent skill package rendering.
test-agent-skill-packages:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_packages.py

## Unit tests for the ios-audit skill source.
test-ios-audit:
	@$(TEST_ENV) python3 -B scripts/tests/python discover \
		-s ./home/dot_agents/packages/ios/skills/local/ios-audit/tests \
		-p 'test_*.py'

## Installed Claude and Codex validation for the generated plugin marketplace.
test-agent-skill-packages-native:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/agents/native-plugins.bats BATS_TAGS=host

## Regression tests for the skill management console.
test-skill-console:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p 'test_console_*.py'

## Shared plist merge contracts, all app scenarios, and modifier discovery.
test-config-merge:
	@DOTFILES_SKIP_LAUNCHCTL_SYNC=1 uv run --quiet --python '>=3.14' python -B tests/config_merge/run.py

## Regression tests for selected-key Tuna plist merging.
test-tuna-plist:
	@DOTFILES_SKIP_LAUNCHCTL_SYNC=1 uv run --quiet --python '>=3.14' python -B tests/config_merge/run.py --app tuna

## Regression tests for selected-key cmux plist merging.
test-cmux-plist:
	@DOTFILES_SKIP_LAUNCHCTL_SYNC=1 $(TEST_ENV) python3 -B tests/config_merge/run.py --app cmux

## Regression tests for selected-key OrbStack plist merging.
test-orbstack-plist:
	@DOTFILES_SKIP_LAUNCHCTL_SYNC=1 $(TEST_ENV) python3 -B tests/config_merge/run.py --app orbstack

## Regression tests for selected-key Thaw plist merging.
test-thaw-plist:
	@DOTFILES_SKIP_LAUNCHCTL_SYNC=1 $(TEST_ENV) python3 -B tests/config_merge/run.py --app thaw

## Regression tests for selected-key app plist merging.
test-selected-app-plists:
	@DOTFILES_SKIP_LAUNCHCTL_SYNC=1 $(TEST_ENV) python3 -B tests/config_merge/run.py --app bettertouchtool raycast tailscale setapp betterdisplay

## Regression tests for machine-type gated app config targets.
test-package-gated-configs:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_config_gates.py

## Regression tests for the machines.toml layered resolver (features.tmpl).
test-machines-features:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_machines.py

test-host-mounts:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_host_mounts.py

## Regression tests for the elevation.sh template (method + jamf_policy_id).
test-elevation-render:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_elevation.py

## Regression tests for Zed settings JSON.
test-zed-settings:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_zed.py

## Regression tests for selected-key Moom plist merging.
test-moom-plist:
	@DOTFILES_SKIP_LAUNCHCTL_SYNC=1 $(TEST_ENV) python3 -B tests/config_merge/run.py --app moom

## Regression tests for selected-key nvALT plist merging.
test-nvalt-plist:
	@DOTFILES_SKIP_LAUNCHCTL_SYNC=1 $(TEST_ENV) python3 -B tests/config_merge/run.py --app nvalt

## Regression tests for nvALT color-list generation.
test-nvalt-colors:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_nvalt_colors.py

## Regression tests for selected-key VoiceInk plist merging.
test-voiceink-plist:
	@DOTFILES_SKIP_LAUNCHCTL_SYNC=1 $(TEST_ENV) python3 -B tests/config_merge/run.py --app voiceink

## Regression tests for the defaults-based Tartelet settings script.
test-tartelet-settings:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/hooks/tartelet-settings.bats

## Regression tests for the tart softnet wrapper installer: render + machine-type gating.
test-tartelet-softnet-wrapper:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/hooks/tartelet-softnet.bats

## Regression tests for chezmoi apply hooks: running-app guard + cfprefsd nudge + optional relaunch.
test-plist-hooks:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/hooks/plist-hooks.bats

## Regression tests for shared sudo keepalive behavior.
test-sudo-keepalive:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/hooks/sudo-keepalive.bats

## Regression tests for macOS defaults script side-effect guards.
test-macos-defaults-script:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/hooks/macos-defaults.bats

## Regression tests for Homebrew inventory drift reporting.
test-brew-inventory:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/packages/brew-inventory.bats

## Regression tests for the agent-assisted brew:install wrapper.
test-brew-install-wrapper:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/programs/brew-install.bats

## Regression tests for brew bundle script concurrency flags.
test-brew-bundle-script:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/packages/brew-bundle.bats

## Regression tests for the downstream-fork install swap (reconciler + hook + Brewfile subtraction).
test-fork-reconcile:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/packages/fork-reconcile.bats

## Regression tests for retired-package cleanup (cleaner + hook + Brewfile guard).
test-retired-packages:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/packages/retired-packages.bats

## Regression tests for the fork-lifecycle packages.toml editor.
test-fork-lifecycle-entry:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_fork_entry.py

## Regression tests for repo-index canonical clone discovery.
test-repo-index:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/programs/repo-index.bats

## End-to-end fresh-shell validator selftest (verify + bench + negative-path checks).
test-zsh-fresh-shells:
	@zsh ./scripts/audit/zsh-fresh-shells.zsh selftest --dotfiles-root "$(CURDIR)"

## Authoritative fresh-shell correctness checks.
verify-zsh-fresh-shells:
	@zsh ./scripts/audit/zsh-fresh-shells.zsh verify --dotfiles-root "$(CURDIR)"

## Authoritative startup benchmark via pinned external zsh-bench.
bench-zsh-startup:
	@zsh ./scripts/audit/zsh-fresh-shells.zsh bench --dotfiles-root "$(CURDIR)"

## Audit tracked Orca settings against the installed app's current defaults
## (refreshes scripts/audit/orca-defaults.snapshot.json; needs Orca installed).
.PHONY: audit-orca-settings
audit-orca-settings:
	@bash ./scripts/audit/orca-settings.sh

## Regression tests for the Tart install helper (does not boot a VM).
test-tart-install-helper:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/vm/install-helper.bats

## Regression tests for zsh xtrace to Perfetto conversion.
test-trace-perfetto:
	@$(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p test_perfetto.py

## Regression tests for VM install-log failure scanning.
test-vm-install-log-scan:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/vm/install-log.bats

## Regression tests for VM macOS postflight assertions.
test-vm-postflight-macos:
	@$(MAKE) --no-print-directory test-shell BATS_PATH=tests/bats/vm/postflight.bats

## Tart smoke lane, dry-run only. Pulls/boots a VM but skips actual installs.
test-install-tart-dry-run:
	@./scripts/vm/test-install-tart.sh --lane smoke --dry-run --image "$(TART_SMOKE_IMAGE)" --cpu "$(TART_CPU)" --memory "$(TART_MEMORY)" $(TART_FLAGS)

## Tart smoke lane. ci machine type, casks/MAS skipped, zsh postflight enabled.
test-install-tart-smoke:
	@./scripts/vm/test-install-tart.sh --lane smoke --image "$(TART_SMOKE_IMAGE)" --cpu "$(TART_CPU)" --memory "$(TART_MEMORY)" $(TART_FLAGS)

## Tart full lane. personal machine type, Xcode image, casks included, MAS opt-in, zsh postflight enabled.
test-install-tart-full:
	@./scripts/vm/test-install-tart.sh --lane full --image "$(TART_FULL_IMAGE)" --cpu "$(TART_CPU)" --memory "$(TART_MEMORY)" $(TART_FLAGS)

## Warm Tart VM for fast iteration. First call: `make test-install-tart-warm-bootstrap` (slow, ~3 min).
## Subsequent: `make test-install-tart-warm` (fast — chezmoi apply against the persistent VM).
## Use `make test-install-tart-warm-refresh` after major repo changes (chezmoi script reordering, package bumps).
test-install-tart-warm:
	@./scripts/vm/warm-tart apply

test-install-tart-warm-bootstrap:
	@./scripts/vm/warm-tart create
	@./scripts/vm/warm-tart bootstrap

test-install-tart-warm-refresh:
	@./scripts/vm/warm-tart refresh

test-install-tart-warm-destroy:
	@./scripts/vm/warm-tart destroy

## Install the pinned shell-test runner and assertion libraries.
test-tools:
	@mise run test-tools

## Discover shell cases; use BATS_PATH or BATS_ARGS='--filter <pattern>' to focus.
test-shell:
	@$(TEST_ENV) "$(TEST_BASH)" scripts/tests/shell "$(BATS_PATH)" $(BATS_ARGS)

.PHONY: test-ci test-ci-suites test-static test-python test-node

## Run the same static and behavior checks as the macOS CI lane.
test-ci:
	@DOTFILES_SKIP_LAUNCHCTL_SYNC=1 GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null $(TEST_ENV) $(MAKE) --no-print-directory test-ci-suites

test-ci-suites: test-static test-shell test-python test-node test-chezmoi-apply

test-static: check-docs-lifecycle
	@zsh -n scripts/trace/run-zsh
	@python3 -c 'import ast, pathlib; [ast.parse(pathlib.Path(p).read_text(), filename=p) for p in ("scripts/trace/xtrace-to-perfetto", "scripts/trace/merge-perfetto", "scripts/trace/open-perfetto")]'

## Native Python discovery for the consolidated structured-data suite.
test-python: test-ios-audit
	@DOTFILES_SKIP_LAUNCHCTL_SYNC=1 $(TEST_ENV) python3 -B scripts/tests/python discover -s tests/config_merge -p 'test_*.py'
	@DOTFILES_SKIP_LAUNCHCTL_SYNC=1 $(TEST_ENV) python3 -B scripts/tests/python discover -s tests/python -p 'test_*.py'

## Native Node discovery stays with the owning extension.
test-node: test-raycast-orca-worktree
