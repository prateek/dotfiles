SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.ONESHELL:
.DEFAULT_GOAL := help

# ----- Project settings (edit these for your app) -----
WORKSPACE     ?= MyApp.xcworkspace
SCHEME        ?= MyApp
CONFIGURATION ?= Debug
BUNDLE_ID     ?= com.example.MyApp
PROJECT_NAME  := $(notdir $(CURDIR))

# ----- Simulator lease (sentinel file; ios-sim-lease replaces this later) -----
LEASE_FILE  := .ios-sim-udid
IOS_SIM_UDID = $(shell test -f $(LEASE_FILE) && cat $(LEASE_FILE))
DERIVED_RUN := /tmp/$(PROJECT_NAME)-run

# ----- Shared xcodebuild flags -----
XCBUILD_FLAGS = -workspace $(WORKSPACE) \
                -scheme $(SCHEME) \
                -configuration $(CONFIGURATION) \
                -destination "id=$(IOS_SIM_UDID)"

.PHONY: help setup-tools bootstrap-local boot-lease release-lease generate format \
        lint build run test-unit test-ui test beta release metadata create-app-in-asc \
        hooks-install kill-dev-processes clean-dev-artifacts check-xcode require-lease

help: ## Show this help
	@awk -F':.*## ' '/^[a-zA-Z_-]+:.*## / {printf "%-22s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Guard that every target needing a simulator depends on.
require-lease:
	@test -n "$(IOS_SIM_UDID)" || { \
	  echo "error: no simulator leased. Run 'make boot-lease' first."; \
	  echo "See ~/.agents/skills/ios-sim-lease/SKILL.md for the current workflow."; \
	  exit 1; \
	}

# ----- Lease lifecycle -----
boot-lease: ## Acquire a leased simulator; writes UDID to .ios-sim-udid
	@test -f $(LEASE_FILE) || { \
	  echo "error: write a booted-simulator UDID to $(LEASE_FILE) first."; \
	  echo "See ~/.agents/skills/ios-sim-lease/SKILL.md for the interim manual flow."; \
	  exit 1; \
	}
	@echo "leased: $$(cat $(LEASE_FILE))"

release-lease: ## Release the current simulator lease
	@rm -f $(LEASE_FILE)
	@echo "released"

# ----- Fast local hygiene -----
setup-tools: ## Trust this repo's mise config and install pinned tools
	mise trust
	mise install

format: ## Format Swift sources
	swiftformat .

lint: ## Run fast static checks
	swiftformat --lint .
	swiftlint lint --quiet
	typos .

hooks-install: ## Install repo-owned git hooks
	@git rev-parse --git-dir >/dev/null 2>&1 || { \
	  echo "error: not inside a git repo. Run 'git init' first."; \
	  exit 1; \
	}
	git config core.hooksPath .githooks
	@echo "hooksPath=.githooks"

bootstrap-local: setup-tools hooks-install check-xcode ## Prepare local tooling, hooks, and Xcode selection

# ----- Project generation -----
generate: ## tuist generate --no-open
	TUIST_GENERATE_OPEN=0 tuist generate --no-open

# ----- Build / run / test -----
build: require-lease generate ## Build the default scheme
	xcodebuild $(XCBUILD_FLAGS) \
	  -derivedDataPath /tmp/$(PROJECT_NAME)-build \
	  build | xcbeautify

run: require-lease generate ## Build, install, and launch on the leased simulator
	xcodebuild $(XCBUILD_FLAGS) \
	  -derivedDataPath $(DERIVED_RUN) \
	  build | xcbeautify
	APP_PATH="$$(xcodebuild $(XCBUILD_FLAGS) -derivedDataPath $(DERIVED_RUN) \
	  -showBuildSettings -json 2>/dev/null \
	  | jq -r '.[0].buildSettings.BUILT_PRODUCTS_DIR')/$(SCHEME).app"
	xcrun simctl install "$(IOS_SIM_UDID)" "$$APP_PATH"
	xcrun simctl launch "$(IOS_SIM_UDID)" "$(BUNDLE_ID)"

test-unit: require-lease generate ## Run the unit test suite
	xcodebuild $(XCBUILD_FLAGS) \
	  -derivedDataPath /tmp/$(PROJECT_NAME)-unit \
	  -only-testing:$(SCHEME)Tests \
	  test | xcbeautify

test-ui: require-lease generate ## Run the UI test suite
	xcodebuild $(XCBUILD_FLAGS) \
	  -derivedDataPath /tmp/$(PROJECT_NAME)-ui \
	  -only-testing:$(SCHEME)UITests \
	  test | xcbeautify

test: test-unit test-ui ## Run unit + UI tests

# ----- Release lanes (Fastlane) -----
create-app-in-asc: ## Fails loudly; ASC app creation cannot be automated (2026)
	@fastlane create_app_in_asc

beta: ## Build and upload to TestFlight
	@fastlane beta

release: ## Build and submit to the App Store
	@fastlane release

metadata: ## Sync metadata and screenshots with App Store Connect
	@fastlane metadata

# ----- Hygiene -----
check-xcode: ## Verify active Xcode matches .xcode-version
	@EXPECTED=$$(cat .xcode-version 2>/dev/null || echo "none")
	@ACTUAL=$$(xcodebuild -version 2>/dev/null | head -1 | awk '{print $$2}')
	@if [ "$$EXPECTED" = "none" ]; then \
	  echo "no .xcode-version pinned; skipping check"; exit 0; \
	fi
	@if [ "$$EXPECTED" != "$$ACTUAL" ]; then \
	  echo "Xcode mismatch: expected $$EXPECTED, active $$ACTUAL"; \
	  echo "Run: xcodes select $$EXPECTED"; \
	  exit 1; \
	fi
	@echo "Xcode $$ACTUAL (matches .xcode-version)"

kill-dev-processes: ## Kill Xcode + Simulator; shutdown all simulators
	-pkill -x Xcode || true
	-pkill -x Simulator || true
	-xcrun simctl shutdown all || true

clean-dev-artifacts: ## Nuke per-lane derived-data directories
	rm -rf /tmp/$(PROJECT_NAME)-*
