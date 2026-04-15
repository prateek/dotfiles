# ABOUTME: Build, test, and release automation for __APP_NAME__.
# ABOUTME: Routes Tuist, simulator work, and trace collection through the worktree helper for deterministic repo-local state.

.PHONY: install setup-tools hooks-install bootstrap-local generate \
	build build-iphone build-ipad run run-iphone run-ipad \
	test-unit test-unit-iphone test-unit-ipad \
	test-snapshot test-snapshot-iphone test-snapshot-ipad \
	test-ui test-ui-iphone test-ui-ipad \
	test-visual test-visual-iphone test-visual-ipad \
	test-all test-matrix trace-matrix \
	screenshot screenshot-iphone screenshot-ipad \
	record-snapshots record-snapshots-iphone record-snapshots-ipad \
	doctor-state release-owner clean-build clean-simulators reset-simulators reap-orphan-simulators clean \
	beta release metadata check-xcode

.NOTPARALLEL: generate build build-iphone build-ipad run-iphone run-ipad \
	test-unit test-unit-iphone test-unit-ipad test-snapshot test-snapshot-iphone test-snapshot-ipad \
	test-ui test-ui-iphone test-ui-ipad test-visual test-visual-iphone test-visual-ipad \
	record-snapshots record-snapshots-iphone record-snapshots-ipad clean clean-build clean-simulators reset-simulators

WORKTREE = python3 scripts/__APP_SLUG___worktree.py
WORKTREE_EXEC = $(WORKTREE) exec --task
SIGN = CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

define WITH_TASK
	@$(WORKTREE_EXEC) $(1) -- /bin/zsh -lc 'set -euo pipefail; set -o pipefail; $(2)'
endef

define TUIST_BUILD
	tuist build "$$IOS_WORKTREE_SCHEME" --generate --device "$$IOS_WORKTREE_SIMULATOR_NAME" --os "$$IOS_WORKTREE_RUNTIME_VERSION" -- -derivedDataPath "$$IOS_WORKTREE_DERIVED_DATA_PATH" $(SIGN) 2>&1 | xcbeautify
endef

define TUIST_TEST
	tuist test "$$IOS_WORKTREE_SCHEME" --no-selective-testing --device "$$IOS_WORKTREE_SIMULATOR_NAME" --os "$$IOS_WORKTREE_RUNTIME_VERSION" --result-bundle-path "$$IOS_WORKTREE_RESULT_BUNDLE_TEMP_PATH" -- -derivedDataPath "$$IOS_WORKTREE_DERIVED_DATA_PATH" $(SIGN) 2>&1 | xcbeautify
endef

install:
	$(call WITH_TASK,generate,tuist install)

setup-tools:
	mise trust
	mise install

hooks-install:
	@git rev-parse --git-dir >/dev/null 2>&1 || { \
	  echo "error: not inside a git repo. Run 'git init' first."; \
	  exit 1; \
	}
	git config core.hooksPath .githooks
	@echo "hooksPath=.githooks"

bootstrap-local: setup-tools hooks-install check-xcode

generate:
	$(call WITH_TASK,generate,tuist install && tuist generate --no-open)

build: build-iphone build-ipad

build-iphone:
	$(call WITH_TASK,build-iphone,$(TUIST_BUILD))

build-ipad:
	$(call WITH_TASK,build-ipad,$(TUIST_BUILD))

run:
	@echo "Use make run-iphone or make run-ipad."
	@exit 1

run-iphone: build-iphone
	$(call WITH_TASK,run-iphone,APP_PATH="$$IOS_WORKTREE_DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/__APP_NAME__.app"; \
		test -d "$$APP_PATH"; \
		xcrun simctl install "$$IOS_WORKTREE_SIMULATOR_UDID" "$$APP_PATH"; \
		xcrun simctl terminate "$$IOS_WORKTREE_SIMULATOR_UDID" __BUNDLE_ID__ 2>/dev/null || true; \
		xcrun simctl launch "$$IOS_WORKTREE_SIMULATOR_UDID" __BUNDLE_ID__)

run-ipad: build-ipad
	$(call WITH_TASK,run-ipad,APP_PATH="$$IOS_WORKTREE_DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/__APP_NAME__.app"; \
		test -d "$$APP_PATH"; \
		xcrun simctl install "$$IOS_WORKTREE_SIMULATOR_UDID" "$$APP_PATH"; \
		xcrun simctl terminate "$$IOS_WORKTREE_SIMULATOR_UDID" __BUNDLE_ID__ 2>/dev/null || true; \
		xcrun simctl launch "$$IOS_WORKTREE_SIMULATOR_UDID" __BUNDLE_ID__)

test-unit: test-unit-iphone test-unit-ipad

test-unit-iphone:
	$(call WITH_TASK,test-unit-iphone,$(TUIST_TEST))

test-unit-ipad:
	$(call WITH_TASK,test-unit-ipad,$(TUIST_TEST))

test-snapshot: test-snapshot-iphone test-snapshot-ipad

test-snapshot-iphone:
	$(call WITH_TASK,test-snapshot-iphone,$(TUIST_TEST))

test-snapshot-ipad:
	$(call WITH_TASK,test-snapshot-ipad,$(TUIST_TEST))

test-ui: test-ui-iphone test-ui-ipad

test-ui-iphone:
	$(call WITH_TASK,test-ui-iphone,$(TUIST_TEST))

test-ui-ipad:
	$(call WITH_TASK,test-ui-ipad,$(TUIST_TEST))

test-visual: test-visual-iphone test-visual-ipad

test-visual-iphone:
	$(call WITH_TASK,test-visual-iphone,$(TUIST_TEST))

test-visual-ipad:
	$(call WITH_TASK,test-visual-ipad,$(TUIST_TEST))

test-all: test-unit test-snapshot test-ui

test-matrix: build test-unit test-snapshot test-ui test-visual

trace-matrix:
	python3 scripts/trace_execution.py

screenshot:
	@echo "Use make screenshot-iphone or make screenshot-ipad."
	@exit 1

screenshot-iphone:
	$(call WITH_TASK,screenshot-iphone,mkdir -p "$$IOS_WORKTREE_SCREENSHOT_DIR"; FILENAME="$$IOS_WORKTREE_SCREENSHOT_DIR/$$(date +%Y%m%d-%H%M%S)-iphone.png"; xcrun simctl io "$$IOS_WORKTREE_SIMULATOR_UDID" screenshot "$$FILENAME"; echo "Screenshot saved: $$FILENAME")

screenshot-ipad:
	$(call WITH_TASK,screenshot-ipad,mkdir -p "$$IOS_WORKTREE_SCREENSHOT_DIR"; FILENAME="$$IOS_WORKTREE_SCREENSHOT_DIR/$$(date +%Y%m%d-%H%M%S)-ipad.png"; xcrun simctl io "$$IOS_WORKTREE_SIMULATOR_UDID" screenshot "$$FILENAME"; echo "Screenshot saved: $$FILENAME")

record-snapshots: record-snapshots-iphone record-snapshots-ipad

record-snapshots-iphone:
	$(call WITH_TASK,record-snapshots-iphone,$(TUIST_TEST))

record-snapshots-ipad:
	$(call WITH_TASK,record-snapshots-ipad,$(TUIST_TEST))

beta:
	export PATH="/opt/homebrew/opt/ruby/bin:$$PATH" && bundle exec fastlane beta

release:
	export PATH="/opt/homebrew/opt/ruby/bin:$$PATH" && bundle exec fastlane release

metadata:
	export PATH="/opt/homebrew/opt/ruby/bin:$$PATH" && bundle exec fastlane metadata

doctor-state:
	$(WORKTREE) doctor-state

release-owner:
	$(WORKTREE) release-owner

clean-build:
	$(WORKTREE) clean-build

clean-simulators:
	$(WORKTREE) clean-simulators

reset-simulators:
	$(WORKTREE) reset-simulators

reap-orphan-simulators:
	$(WORKTREE) reap-orphan-simulators

clean:
	$(WORKTREE) clean

check-xcode:
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
