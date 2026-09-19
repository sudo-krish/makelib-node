# ==============================================================================
# .makelib/core.mk — Centralized Make Library Core for Node.js / TypeScript
# ==============================================================================

# Strict Bash shell environment
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Dynamically determine makelib directory
MAKELIB_DIR := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))

# Include modular components
-include $(MAKELIB_DIR)/colors.mk

# Configurable directory paths (overridable downstream via ?=)
SRC_DIR       ?= src
TEST_DIR      ?= test
DIST_DIR      ?= dist
COVERAGE_DIR  ?= coverage
TEMPLATES_DIR ?= templates
SCRIPTS_DIR   ?= scripts

# Configurable quality gate thresholds
MIN_COVERAGE  ?= 80

# Add isolated makelib and local node_modules to PATH and NODE_PATH
export PATH := $(CURDIR)/$(MAKELIB_DIR)/node_modules/.bin:$(CURDIR)/node_modules/.bin:$(PATH)
export NODE_PATH := $(CURDIR)/$(MAKELIB_DIR)/node_modules:$(CURDIR)/node_modules:$${NODE_PATH:-}

# Configurable toolchain commands
NODE            ?= node
NPM             ?= npm
NPX             ?= npx
TSC             ?= tsc
ESLINT          ?= eslint
PRETTIER        ?= prettier
VITEST          ?= vitest
TSUP            ?= tsup
LEFTHOOK        ?= lefthook
DETECT_SECRETS  ?= detect-secrets
LICENSE_CHECKER ?= license-checker-rseidelsohn

# Include quality gates, release, and hook modules
-include $(MAKELIB_DIR)/quality.mk
-include $(MAKELIB_DIR)/release.mk
-include $(MAKELIB_DIR)/hooks.mk

.DEFAULT_GOAL := help

.PHONY: help clean build

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

build: clean ## Compile production bundles into dist/
	@echo -e "$(INFO_PREFIX) Building production bundle with tsup..."
	@$(TSUP) $(SRC_DIR)/index.ts --format cjs,esm --dts --clean --out-dir $(DIST_DIR)
	@echo -e "$(SUCCESS_PREFIX) Build completed in $(DIST_DIR)/."
