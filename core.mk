# ==============================================================================
# core.mk — Centralized Make Library Core for Node.js / TypeScript
# ==============================================================================

# Strict Bash shell environment
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Dynamically determine makelib root directory (handles submodule and standalone)
MAKELIB_DIR := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))
ifeq ($(MAKELIB_DIR),)
  MAKELIB_DIR := .
endif
MAKELIB_ROOT := $(MAKELIB_DIR)

# Include modular components
-include $(MAKELIB_ROOT)/colors.mk

# Configurable directory paths (overridable downstream via ?=)
SRC_DIR       ?= src
TEST_DIR      ?= test
DIST_DIR      ?= dist
COVERAGE_DIR  ?= coverage
SCRIPTS_DIR   ?= $(firstword $(wildcard $(MAKELIB_ROOT)/scripts scripts))

# Configurable quality gate thresholds
MIN_COVERAGE  ?= 80

# Add isolated makelib submodule and local node_modules to PATH and NODE_PATH
export PATH := $(CURDIR)/$(MAKELIB_ROOT)/node_modules/.bin:$(CURDIR)/node_modules/.bin:$(PATH)
export NODE_PATH := $(CURDIR)/$(MAKELIB_ROOT)/node_modules:$(CURDIR)/node_modules:$${NODE_PATH:-}

# Configurable toolchain commands (resolving from isolated submodule bin first, with fallback to system)
NODE            ?= node
NPM             ?= npm
NPX             ?= npx
TSC             ?= $(firstword $(wildcard $(CURDIR)/$(MAKELIB_ROOT)/node_modules/.bin/tsc) tsc)
ESLINT          ?= $(firstword $(wildcard $(CURDIR)/$(MAKELIB_ROOT)/node_modules/.bin/eslint) eslint)
PRETTIER        ?= $(firstword $(wildcard $(CURDIR)/$(MAKELIB_ROOT)/node_modules/.bin/prettier) prettier)
VITEST          ?= $(firstword $(wildcard $(CURDIR)/$(MAKELIB_ROOT)/node_modules/.bin/vitest) vitest)
TSUP            ?= $(firstword $(wildcard $(CURDIR)/$(MAKELIB_ROOT)/node_modules/.bin/tsup) tsup)
LEFTHOOK        ?= $(firstword $(wildcard $(CURDIR)/$(MAKELIB_ROOT)/node_modules/.bin/lefthook) lefthook)
DETECT_SECRETS  ?= detect-secrets
LICENSE_CHECKER ?= $(firstword $(wildcard $(CURDIR)/$(MAKELIB_ROOT)/node_modules/.bin/license-checker-rseidelsohn) license-checker-rseidelsohn)

# Include quality gates, release, and hook modules
-include $(MAKELIB_ROOT)/quality.mk
-include $(MAKELIB_ROOT)/release.mk
-include $(MAKELIB_ROOT)/hooks.mk

.DEFAULT_GOAL := help

.PHONY: help clean build makelib-install init deps-update update-deps setup-ci

makelib-install: ## Install makelib toolchain dependencies isolated inside submodule
	@echo -e "$(INFO_PREFIX) Installing isolated makelib toolchain in $(MAKELIB_ROOT)..."
	@npm --prefix "$(MAKELIB_ROOT)" ci || npm --prefix "$(MAKELIB_ROOT)" install
	@echo -e "$(SUCCESS_PREFIX) Toolchain ready in $(MAKELIB_ROOT)/node_modules."

init: makelib-install install-hooks setup-ci ## Initialize makelib toolchain, git hooks, and CI workflows

setup-ci: ## Scaffold GitHub Actions CI/CD workflows pre-configured with recursive submodules
	@bash $(SCRIPTS_DIR)/setup-ci.sh

deps-update: ## Update all dependencies and Node.js version to latest
	@node $(SCRIPTS_DIR)/update-deps.js

update-deps: deps-update ## Alias for deps-update

help: ## Display this colorized, self-documenting help menu
	@echo -e "$(COLOR_BOLD)$(COLOR_CYAN)======================================================================$(COLOR_RESET)"
	@echo -e "$(COLOR_BOLD)$(COLOR_CYAN)           makelib-node — Standard Toolchain & Quality Gates          $(COLOR_RESET)"
	@echo -e "$(COLOR_BOLD)$(COLOR_CYAN)======================================================================$(COLOR_RESET)"
	@echo -e ""
	@echo -e "$(COLOR_BOLD)Usage:$(COLOR_RESET) make $(COLOR_CYAN)<target>$(COLOR_RESET) [VAR=override...]"
	@echo -e ""
	@echo -e "$(COLOR_BOLD)Available Targets:$(COLOR_RESET)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort -u
	@echo -e ""
	@echo -e "$(COLOR_BOLD)Overridable Variables:$(COLOR_RESET)"
	@echo -e "  $(COLOR_YELLOW)SRC_DIR$(COLOR_RESET)        Source directory (default: $(SRC_DIR))"
	@echo -e "  $(COLOR_YELLOW)TEST_DIR$(COLOR_RESET)       Test directory (default: $(TEST_DIR))"
	@echo -e "  $(COLOR_YELLOW)MIN_COVERAGE$(COLOR_RESET)   Minimum test line coverage (default: $(MIN_COVERAGE)%)"
	@echo -e ""

clean: ## Clean build artifacts, caches, and test coverage
	@echo -e "$(INFO_PREFIX) Cleaning build and cache artifacts..."
	@rm -rf $(DIST_DIR) $(COVERAGE_DIR) .turbo node_modules/.cache *.tsbuildinfo
	@echo -e "$(SUCCESS_PREFIX) Workspace cleaned."

BUILD_CMD ?= $(TSUP) $(SRC_DIR)/index.ts --format cjs,esm --dts --clean --out-dir $(DIST_DIR)

ifndef NO_DEFAULT_BUILD
build: clean ## Compile production bundles into dist/
	@echo -e "$(INFO_PREFIX) Building production bundle..."
	@$(BUILD_CMD)
	@echo -e "$(SUCCESS_PREFIX) Build completed in $(DIST_DIR)/."
endif
