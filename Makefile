.PHONY: hammerspoon hammerspoon-check hammerspoon-reload
.PHONY: test-ghc test-macos-settings test-repo-index test-grmrepo-refresh test-worktrees
.PHONY: test-zsh-fresh-shells verify-zsh-fresh-shells bench-zsh-startup
.PHONY: test-tart-install-helper test-trace-perfetto test-vm-install-log-scan test-vm-postflight-macos test-install-tart-dry-run test-install-tart-smoke test-install-tart-full

HAMMERSPOON_SRC := .hammerspoon/init.fnl
HAMMERSPOON_OUT := .hammerspoon/init.generated.lua
TART_IMAGE ?= ghcr.io/cirruslabs/macos-tahoe-base:latest
TART_CPU ?= 2
TART_MEMORY ?= 4096
TART_FLAGS ?=

## Compile Hammerspoon config (Fennel -> Lua).
hammerspoon: $(HAMMERSPOON_OUT)

$(HAMMERSPOON_OUT): $(HAMMERSPOON_SRC)
	@command -v fennel >/dev/null 2>&1 || { echo "Missing 'fennel' (brew install fennel)"; exit 1; }
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

## E2E tests for ghc URL handling.
test-ghc:
	@zsh ./tests/ghc-url.zsh

## Regression tests for managed macOS defaults coverage.
test-macos-settings:
	@zsh ./tests/macos-settings-coverage.zsh

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
	@./scripts/vm/test-install-tart.sh --lane smoke --dry-run --image "$(TART_IMAGE)" --cpu "$(TART_CPU)" --memory "$(TART_MEMORY)" $(TART_FLAGS)

## Tart smoke lane. Core profile, casks/MAS skipped, zsh postflight enabled.
test-install-tart-smoke:
	@./scripts/vm/test-install-tart.sh --lane smoke --image "$(TART_IMAGE)" --cpu "$(TART_CPU)" --memory "$(TART_MEMORY)" $(TART_FLAGS)

## Tart full lane. Full profile, casks/MAS included, zsh postflight enabled.
test-install-tart-full:
	@./scripts/vm/test-install-tart.sh --lane full --image "$(TART_IMAGE)" --cpu "$(TART_CPU)" --memory "$(TART_MEMORY)" $(TART_FLAGS)
