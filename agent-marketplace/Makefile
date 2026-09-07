.DEFAULT_GOAL := build
RUN ?= uv run --offline --frozen
PYTHON ?= python3
SCRIPT ?= scripts/marketplace.py

.PHONY: tools build check export clean test fetch update
tools:
	mise install
	mise exec -- uv sync --locked

build check export clean:
	$(RUN) $(PYTHON) -B "$(SCRIPT)" $@
ifneq ($(wildcard tests/test_*.py),)
check: test
endif

fetch update:
	$(if $(strip $(PACKAGE)),$(error PACKAGE is no longer supported; $@ uses the root manifest and shared cache))
	$(RUN) $(PYTHON) -B "$(SCRIPT)" $@

test:
	$(RUN) $(PYTHON) -B -m unittest discover -s tests -p 'test_*.py'
