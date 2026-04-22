.PHONY: hammerspoon hammerspoon-check hammerspoon-reload
.PHONY: test-ghc test-macos-settings test-repo-index test-grmrepo-refresh test-worktrees test-zsh-fresh-shells verify-zsh-fresh-shells bench-zsh-startup

HAMMERSPOON_SRC := .hammerspoon/init.fnl
HAMMERSPOON_OUT := .hammerspoon/init.generated.lua

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
