# Project Agent Guide

## Overview

This guide tells agents how to operate in this repository.

## Top-Level Structure

Top-level folders:

- `src/` — application code
- `tests/` — unit and integration tests
- `docs/` — long-form docs
- `scripts/` — operational scripts

## Migration Notice (2024 Q2)

We completed the 2024 Q2 migration off the legacy `lib/` folder. All `lib/*.py` files have been moved into `src/` and `lib/` has been deleted. Any residual references to `lib/` in docs or comments should be treated as historical and removed on sight.

## How We Work

- Tests live alongside code they exercise where practical.
- Prefer small, reviewable PRs.
- Always run `make lint` before pushing.

## Top-Level Structure

The repository is organized at the top level as:

- `src/` — application code
- `tests/` — unit and integration tests
- `docs/` — long-form docs
- `scripts/` — operational scripts

## Style

Code style is enforced by `ruff`. Don't fight the formatter.
