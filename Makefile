.PHONY: test hammerspoon hammerspoon-check hammerspoon-reload
.PHONY: nix-check nix-build nix-switch nix-update nix-fmt
.PHONY: test-gemini-meeting-sync test-ghc test-kanata-config test-repo-index test-grmrepo-refresh test-worktrees
.PHONY: test-zsh-fresh-shells verify-zsh-fresh-shells bench-zsh-startup
.PHONY: test-tart-install-helper test-trace-perfetto test-vm-install-log-scan
.PHONY: test-install-tart-dry-run test-install-tart-smoke test-install-tart-full
.PHONY: test-install-tart-warm test-install-tart-warm-bootstrap test-install-tart-warm-refresh test-install-tart-warm-destroy
.PHONY: test-brew-inventory

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

HOST ?= prateek-mac

## Default validation: run nix flake check (the pre-commit equivalent).
test: nix-check

## Validate the flake without building (fast, evaluation-only).
nix-check:
	@command -v nix >/dev/null 2>&1 || { echo "Skipping nix validation (nix not installed)"; exit 0; }
	@nix --extra-experimental-features 'nix-command flakes' flake check --no-build

## Build the system closure (no apply).
nix-build:
	@command -v nix >/dev/null 2>&1 || { echo "nix not installed"; exit 1; }
	@nix --extra-experimental-features 'nix-command flakes' build .#darwinConfigurations.$(HOST).system

## Apply the system closure (requires nix-darwin already installed).
nix-switch:
	@command -v darwin-rebuild >/dev/null 2>&1 || { echo "darwin-rebuild not installed; run 'nix run nix-darwin -- switch --flake .#$(HOST)' first"; exit 1; }
	@darwin-rebuild switch --flake .#$(HOST)

## Update all flake inputs.
nix-update:
	@nix --extra-experimental-features 'nix-command flakes' flake update

## Format nix files.
nix-fmt:
	@nix --extra-experimental-features 'nix-command flakes' fmt

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

## Regression tests for Gemini meeting sync wrapper config.
test-gemini-meeting-sync:
	@zsh ./tests/gemini-meeting-sync.zsh

## E2E tests for ghc URL handling.
test-ghc:
	@zsh ./tests/ghc-url.zsh

## Validate Kanata keyboard remap config with kanata's parser.
test-kanata-config:
	@zsh ./tests/kanata-config.zsh

## Regression tests for repo-index canonical clone discovery.
test-repo-index:
	@zsh ./tests/repo-index.zsh

## Regression tests for GRM config generation from local canonical clones.
test-grmrepo-refresh:
	@zsh ./tests/grmrepo-refresh.zsh

## E2E tests for worktree helpers (w + hooks).
test-worktrees:
	@zsh ./tests/e2e-worktrees.zsh

## Regression tests for Homebrew inventory drift reporting.
test-brew-inventory:
	@zsh ./tests/brew-inventory.zsh

## End-to-end fresh-shell validator selftest (verify + bench + negative-path checks).
test-zsh-fresh-shells:
	@zsh ./scripts/audit/zsh-fresh-shells.zsh selftest --dotfiles-root "$(CURDIR)"

## Authoritative fresh-shell correctness checks.
verify-zsh-fresh-shells:
	@zsh ./scripts/audit/zsh-fresh-shells.zsh verify --dotfiles-root "$(CURDIR)"

## Authoritative startup benchmark via pinned external zsh-bench.
bench-zsh-startup:
	@zsh ./scripts/audit/zsh-fresh-shells.zsh bench --dotfiles-root "$(CURDIR)"

## Regression tests for the Tart install helper (does not boot a VM).
test-tart-install-helper:
	@zsh ./tests/tart-install-helper-contract.zsh

## Regression tests for zsh xtrace to Perfetto conversion.
test-trace-perfetto:
	@zsh ./tests/trace-perfetto.zsh

## Regression tests for VM install-log failure scanning.
test-vm-install-log-scan:
	@zsh ./tests/vm-install-log-scan.zsh

## Tart smoke lane, dry-run only. Pulls/boots a VM but skips actual installs.
## NOTE: scripts/vm/test-install-tart.sh still expects the chezmoi bootstrap;
## see TODO(nix) — port to nix-darwin install before relying on this.
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
## Use `make test-install-tart-warm-refresh` after major repo changes.
test-install-tart-warm:
	@./scripts/vm/warm-tart apply

test-install-tart-warm-bootstrap:
	@./scripts/vm/warm-tart create
	@./scripts/vm/warm-tart bootstrap

test-install-tart-warm-refresh:
	@./scripts/vm/warm-tart refresh

test-install-tart-warm-destroy:
	@./scripts/vm/warm-tart destroy
