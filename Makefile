.PHONY: test test-chezmoi-apply hammerspoon hammerspoon-check hammerspoon-reload
.PHONY: test-gemini-meeting-sync test-ghc test-gh-extensions-script test-mise-install-script test-xcode-install-script test-secret-backed-files test-kanata-config test-karabiner-goku test-chezmoi-config test-chezmoi-local-ignores test-chezmoi-script-status test-chezmoi-drift-banner test-codex-config test-agentsview-config test-claude-settings test-pi-settings test-claude-statusline test-orca-settings test-crit-config test-agent-skill-packages test-agent-skill-packages-native test-cmux-plist test-ice-plist test-orbstack-plist test-selected-app-plists test-package-gated-configs test-machines-features test-elevation-render test-moom-plist test-nvalt-colors test-nvalt-plist test-voiceink-plist test-tartelet-settings test-tartelet-softnet-wrapper test-plist-hooks test-sudo-keepalive test-macos-defaults-script test-brew-inventory test-brew-install-wrapper test-brew-bundle-script test-fork-reconcile test-render-brewfile test-docs-lifecycle test-repo-index test-raycast-orca-worktree
.PHONY: test-zed-settings test-zsh-prompt-host test-zsh-fresh-shells verify-zsh-fresh-shells bench-zsh-startup
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

## Default validation: chezmoi template syntax and apply dry-run.
test: test-chezmoi-apply

## Validate chezmoi apply --dry-run to catch template errors before commit.
test-chezmoi-apply:
	@command -v chezmoi >/dev/null 2>&1 || { echo "Skipping chezmoi validation (chezmoi not installed)"; exit 0; }
	@./scripts/chezmoi/test-apply-dry-run.sh ci "$(CURDIR)"
	@./scripts/chezmoi/test-apply-dry-run.sh personal "$(CURDIR)"

## Regression tests for the focused Brewfile renderer.
test-render-brewfile:
	@zsh ./tests/render-brewfile.zsh

## Validate the Pure hostname prefix: machine_type -> color and hook behavior.
test-zsh-prompt-host:
	@command -v chezmoi >/dev/null 2>&1 || { echo "Skipping zsh-prompt-host test (chezmoi not installed)"; exit 0; }
	@zsh ./tests/zsh-prompt-host.zsh

## Validate docs lifecycle frontmatter, routing, and historical doc edits.
test-docs-lifecycle:
	@command -v uv >/dev/null 2>&1 || { echo "Missing 'uv' for docs lifecycle validation. Install uv or run chezmoi bootstrap first."; exit 1; }
	@zsh ./tests/docs-lifecycle.zsh
	@base="$(DOCS_LIFECYCLE_BASE)"; \
	if [ "$$base" = "none" ]; then \
		./docs/validate-doc-lifecycle.py; \
	else \
		if ! git rev-parse --verify "$$base^{commit}" >/dev/null 2>&1; then \
			echo "Missing docs lifecycle base '$$base'. Fetch it or set DOCS_LIFECYCLE_BASE=<ref>; use DOCS_LIFECYCLE_BASE=none only for current-tree checks." >&2; \
			exit 1; \
		fi; \
		./docs/validate-doc-lifecycle.py --base "$$base"; \
	fi

## Regression tests for Gemini meeting sync wrapper config.
test-gemini-meeting-sync:
	@zsh ./tests/gemini-meeting-sync.zsh

## E2E tests for ghc/ohc URL handling.
test-ghc:
	@zsh ./tests/ghc-url.zsh

## Unit tests for the Raycast Orca worktree extension core.
test-raycast-orca-worktree:
	@npm test --prefix ./home/dot_local/share/raycast-extensions/orca-worktree

## Regression tests for mise runtime install script ordering.
test-mise-install-script:
	@zsh ./tests/mise-install-script.zsh

## Regression tests for gh extensions install script.
test-gh-extensions-script:
	@zsh ./tests/gh-extensions-script.zsh

## Regression tests for Xcode install script ordering.
test-xcode-install-script:
	@zsh ./tests/xcode-install-script.zsh

## Regression tests for secret-backed private files.
test-secret-backed-files:
	@zsh ./tests/secret-backed-files.zsh

## Validate Kanata keyboard remap config with kanata's parser.
test-kanata-config:
	@zsh ./tests/kanata-config.zsh

## Validate the Goku EDN compiles to the expected karabiner.json rules.
test-karabiner-goku:
	@zsh ./tests/karabiner-goku.zsh

## Regression tests for generated chezmoi config defaults.
test-chezmoi-config:
	@zsh ./tests/chezmoi-config.zsh

## Regression tests for ignored machine-local chezmoi state.
test-chezmoi-local-ignores:
	@zsh ./tests/chezmoi-local-ignores.zsh

## Regression tests for steady-state chezmoi script status.
test-chezmoi-script-status:
	@zsh ./tests/chezmoi-script-status.zsh

## Regression tests for the cached chezmoi drift shell banner.
test-chezmoi-drift-banner:
	@zsh ./tests/chezmoi-drift-banner.zsh

## Regression tests for Codex config merging.
test-codex-config:
	@zsh ./tests/codex-config-modify.zsh

## Regression tests for agentsview config merging (codex_sessions_dirs).
test-agentsview-config:
	@zsh ./tests/agentsview-config-modify.zsh

## Regression tests for Claude Code settings merging.
test-claude-settings:
	@zsh ./tests/claude-settings-modify.zsh

## Regression tests for pi settings and Claude marketplace config.
test-pi-settings:
	@zsh ./tests/pi-settings-modify.zsh

## Regression tests for the Claude Code status line script.
test-claude-statusline:
	@zsh ./tests/claude-statusline.zsh

## Regression tests for Orca settings merging.
test-orca-settings:
	@zsh ./tests/orca-settings-modify.zsh

## Regression tests for the crit agent bridge: agent_cmd modify, acrit render, wrapper resolution.
test-crit-config:
	@zsh ./tests/crit-config-modify.zsh

## Regression tests for agent skill package rendering.
test-agent-skill-packages:
	@zsh ./tests/agent-skill-packages.zsh

## Native Claude Code validation for generated local plugin marketplace.
test-agent-skill-packages-native:
	@zsh ./tests/agent-skill-packages-native.zsh

## Regression tests for selected-key cmux plist merging.
test-cmux-plist:
	@zsh ./tests/cmux-plist-modify.zsh

## Regression tests for selected-key Ice plist merging.
test-ice-plist:
	@zsh ./tests/ice-plist-modify.zsh

## Regression tests for selected-key OrbStack plist merging.
test-orbstack-plist:
	@zsh ./tests/orbstack-plist-modify.zsh

## Regression tests for selected-key app plist merging.
test-selected-app-plists:
	@zsh ./tests/selected-app-plist-modify.zsh

## Regression tests for machine-type gated app config targets.
test-package-gated-configs:
	@zsh ./tests/package-gated-configs.zsh

## Regression tests for the machines.toml layered resolver (features.tmpl).
test-machines-features:
	@command -v chezmoi >/dev/null 2>&1 || { echo "Skipping machines-features test (chezmoi not installed)"; exit 0; }
	@zsh ./tests/machines-features.zsh

## Regression tests for the elevation.sh template (method + jamf_policy_id).
test-elevation-render:
	@command -v chezmoi >/dev/null 2>&1 || { echo "Skipping elevation-render test (chezmoi not installed)"; exit 0; }
	@zsh ./tests/elevation-render.zsh

## Regression tests for Zed settings JSON.
test-zed-settings:
	@zsh ./tests/zed-settings.zsh

## Regression tests for selected-key Moom plist merging.
test-moom-plist:
	@zsh ./tests/moom-plist-modify.zsh

## Regression tests for selected-key nvALT plist merging.
test-nvalt-plist:
	@zsh ./tests/nvalt-plist-modify.zsh

## Regression tests for nvALT color-list generation.
test-nvalt-colors:
	@zsh ./tests/nvalt-colors.zsh

## Regression tests for selected-key VoiceInk plist merging.
test-voiceink-plist:
	@zsh ./tests/voiceink-plist-modify.zsh

## Regression tests for the defaults-based Tartelet settings script.
test-tartelet-settings:
	@command -v chezmoi >/dev/null 2>&1 || { echo "Skipping tartelet-settings test (chezmoi not installed)"; exit 0; }
	@zsh ./tests/tartelet-settings.zsh

## Regression tests for the tart softnet wrapper installer: render + machine-type gating.
test-tartelet-softnet-wrapper:
	@command -v chezmoi >/dev/null 2>&1 || { echo "Skipping tartelet-softnet-wrapper test (chezmoi not installed)"; exit 0; }
	@zsh ./tests/tartelet-softnet-wrapper.zsh

## Regression tests for chezmoi apply hooks: running-app guard + cfprefsd nudge + optional relaunch.
test-plist-hooks:
	@zsh ./tests/plist-hooks.zsh

## Regression tests for shared sudo keepalive behavior.
test-sudo-keepalive:
	@zsh ./tests/sudo-keepalive.zsh

## Regression tests for macOS defaults script side-effect guards.
test-macos-defaults-script:
	@zsh ./tests/macos-defaults-script.zsh

## Regression tests for Homebrew inventory drift reporting.
test-brew-inventory:
	@zsh ./tests/brew-inventory.zsh

## Regression tests for the agent-assisted brew:install wrapper.
test-brew-install-wrapper:
	@zsh ./tests/brew-install-wrapper.zsh

## Regression tests for brew bundle script concurrency flags.
test-brew-bundle-script:
	@zsh ./tests/brew-bundle-script.zsh

## Regression tests for the downstream-fork install swap (reconciler + hook + Brewfile subtraction).
test-fork-reconcile:
	@zsh ./tests/fork-reconcile.zsh

## Regression tests for the fork-lifecycle packages.toml editor.
test-fork-lifecycle-entry:
	@zsh ./tests/fork-lifecycle-entry.zsh

## Regression tests for repo-index canonical clone discovery.
test-repo-index:
	@zsh ./tests/repo-index.zsh

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
	@zsh ./tests/tart-install-helper-contract.zsh

## Regression tests for zsh xtrace to Perfetto conversion.
test-trace-perfetto:
	@zsh ./tests/trace-perfetto.zsh

## Regression tests for VM install-log failure scanning.
test-vm-install-log-scan:
	@zsh ./tests/vm-install-log-scan.zsh

## Regression tests for VM macOS postflight assertions.
test-vm-postflight-macos:
	@zsh ./tests/vm-postflight-macos.zsh

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
