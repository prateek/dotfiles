.PHONY: hammerspoon hammerspoon-check hammerspoon-reload
.PHONY: test-worktrees

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

## E2E tests for worktree helpers (w + hooks).
test-worktrees:
	@zsh ./tests/e2e-worktrees.zsh
