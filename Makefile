.PHONY: hammerspoon hammerspoon-check hammerspoon-reload
.PHONY: test-gemini-meeting-sync test-ghc test-mise-install-script test-xcode-install-script test-secret-backed-files test-kanata-config test-cmux-plist test-ice-plist test-orbstack-plist test-selected-app-plists test-package-gated-configs test-moom-plist test-nvalt-colors test-nvalt-plist test-voiceink-plist test-plist-hooks test-sudo-keepalive test-brew-bundle-script test-render-brewfile test-render-chrome-policy test-repo-index test-grmrepo-refresh test-worktrees
.PHONY: test-zed-settings test-zsh-fresh-shells verify-zsh-fresh-shells bench-zsh-startup
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

## Regression tests for the focused Brewfile renderer.
test-render-brewfile:
	@zsh ./tests/render-brewfile.zsh

## Regression tests for the focused Chrome managed-policy renderer.
test-render-chrome-policy:
	@zsh ./tests/render-chrome-policy.zsh

## Regression tests for Gemini meeting sync wrapper config.
test-gemini-meeting-sync:
	@zsh ./tests/gemini-meeting-sync.zsh

## E2E tests for ghc URL handling.
test-ghc:
	@zsh ./tests/ghc-url.zsh

## Regression tests for mise runtime install script ordering.
test-mise-install-script:
	@zsh ./tests/mise-install-script.zsh

## Regression tests for full-profile Xcode install script ordering.
test-xcode-install-script:
	@zsh ./tests/xcode-install-script.zsh

## Regression tests for secret-backed private files.
test-secret-backed-files:
	@zsh ./tests/secret-backed-files.zsh

## Validate Kanata keyboard remap config with kanata's parser.
test-kanata-config:
	@zsh ./tests/kanata-config.zsh

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

## Regression tests for package-profile gated app config targets.
test-package-gated-configs:
	@zsh ./tests/package-gated-configs.zsh

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

## Regression tests for chezmoi apply hooks: running-app guard + cfprefsd nudge + optional relaunch.
test-plist-hooks:
	@zsh ./tests/plist-hooks.zsh

## Regression tests for shared sudo keepalive behavior.
test-sudo-keepalive:
	@zsh ./tests/sudo-keepalive.zsh

## Regression tests for brew bundle script concurrency flags.
test-brew-bundle-script:
	@zsh ./tests/brew-bundle-script.zsh

## Regression tests for repo-index canonical clone discovery.
test-repo-index:
	@zsh ./tests/repo-index.zsh

## Regression tests for GRM config generation from local canonical clones.
test-grmrepo-refresh:
	@zsh ./tests/grmrepo-refresh.zsh

## E2E tests for worktree helpers (w + hooks).
test-worktrees:
	@zsh ./tests/e2e-worktrees.zsh

## End-to-end fresh-shell validator selftest (verify + bench + negative-path checks).
test-zsh-fresh-shells:
	@zsh ./scripts/audit/zsh-fresh-shells.zsh selftest

## Authoritative fresh-shell correctness checks.
verify-zsh-fresh-shells:
	@zsh ./scripts/audit/zsh-fresh-shells.zsh verify

## Authoritative startup benchmark via pinned external zsh-bench.
bench-zsh-startup:
	@zsh ./scripts/audit/zsh-fresh-shells.zsh bench

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

## Tart smoke lane. Core profile, casks/MAS skipped, zsh postflight enabled.
test-install-tart-smoke:
	@./scripts/vm/test-install-tart.sh --lane smoke --image "$(TART_SMOKE_IMAGE)" --cpu "$(TART_CPU)" --memory "$(TART_MEMORY)" $(TART_FLAGS)

## Tart full lane. Full profile, Xcode image, casks included, MAS opt-in, zsh postflight enabled.
test-install-tart-full:
	@./scripts/vm/test-install-tart.sh --lane full --image "$(TART_FULL_IMAGE)" --cpu "$(TART_CPU)" --memory "$(TART_MEMORY)" $(TART_FLAGS)

## Warm Tart VM for fast iteration. First call: `make test-install-tart-warm-bootstrap` (slow, ~3 min).
## Subsequent: `make test-install-tart-warm` (fast — chezmoi apply against the persistent VM).
## Use `make test-install-tart-warm-refresh` after major repo changes (chezmoi script reordering, profile bumps).
test-install-tart-warm:
	@./scripts/vm/warm-tart apply

test-install-tart-warm-bootstrap:
	@./scripts/vm/warm-tart create
	@./scripts/vm/warm-tart bootstrap

test-install-tart-warm-refresh:
	@./scripts/vm/warm-tart refresh

test-install-tart-warm-destroy:
	@./scripts/vm/warm-tart destroy
