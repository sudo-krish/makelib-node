# ==============================================================================
# Downstream Makefile for makelib-node
# ==============================================================================
# Copy this file as `Makefile` into your repository root and run:
#   make init        # Automatically adds submodule, installs toolchain & hooks
#   make check-all   # Runs full 8-stage quality gate pipeline
#   make help        # Displays self-documenting help menu
# ==============================================================================

# Makelib repository and directory settings
MAKELIB_REPO ?= https://github.com/sudo-krish/makelib-node.git
MAKELIB_DIR  ?= .makelib

# Downstream Overrides (uncomment and customize as needed)
# SRC_DIR      ?= src
# TEST_DIR     ?= test
# MIN_COVERAGE ?= 80
# NO_DEFAULT_BUILD := 1   # Uncomment if downstream defines its own custom build target

.PHONY: init init-makelib update update-makelib deps-update setup-ci

init: init-makelib
update: update-makelib

setup-ci: ## Scaffold GitHub Actions CI/CD workflows pre-configured with recursive submodules
	@if [ -f "$(MAKELIB_DIR)/scripts/setup-ci.sh" ]; then \
		bash "$(MAKELIB_DIR)/scripts/setup-ci.sh"; \
	elif [ -f "scripts/setup-ci.sh" ]; then \
		bash "scripts/setup-ci.sh"; \
	fi

deps-update: ## Update all dependencies and Node.js version to latest
	@if [ -f "$(MAKELIB_DIR)/scripts/update-deps.js" ]; then \
		node "$(MAKELIB_DIR)/scripts/update-deps.js"; \
	elif [ -f "scripts/update-deps.js" ]; then \
		node "scripts/update-deps.js"; \
	fi

init-makelib: ## Initialize makelib as a submodule, install toolchain, and set up git hooks
	@if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then \
		echo "Initializing Git repository..."; \
		git init; \
	fi
	@if [ ! -e "$(MAKELIB_DIR)/.git" ]; then \
		if git config --file .gitmodules --get "submodule.$(MAKELIB_DIR).url" >/dev/null 2>&1; then \
			echo "Initializing existing submodule in $(MAKELIB_DIR)..."; \
			git -c protocol.file.allow=always submodule update --init --recursive $(MAKELIB_DIR) || \
			git -c protocol.file.allow=always submodule add --force $(MAKELIB_REPO) $(MAKELIB_DIR); \
		else \
			echo "Adding makelib-node submodule into $(MAKELIB_DIR)..."; \
			git -c protocol.file.allow=always submodule add --force $(MAKELIB_REPO) $(MAKELIB_DIR); \
		fi; \
	else \
		echo "Submodule $(MAKELIB_DIR) already present. Updating..."; \
		git -c protocol.file.allow=always submodule update --init --recursive $(MAKELIB_DIR); \
	fi
	@echo "Installing isolated makelib toolchain in $(MAKELIB_DIR)..."
	@npm --prefix "$(MAKELIB_DIR)" install
	@if [ -f "$(MAKELIB_DIR)/scripts/install-hooks.sh" ]; then \
		bash "$(MAKELIB_DIR)/scripts/install-hooks.sh"; \
	fi
	@if [ -f "$(MAKELIB_DIR)/scripts/setup-ci.sh" ]; then \
		bash "$(MAKELIB_DIR)/scripts/setup-ci.sh"; \
	fi
	@echo "makelib-node initialized successfully! Run 'make check-all' or 'make help'."

update-makelib: ## Update makelib submodule to latest remote revision
	@echo "Updating makelib-node submodule in $(MAKELIB_DIR)..."
	@git -c protocol.file.allow=always submodule update --remote --merge $(MAKELIB_DIR)
	@npm --prefix "$(MAKELIB_DIR)" install
	@echo "makelib-node updated successfully."

# Include makelib core library
-include $(MAKELIB_DIR)/core.mk

# If makelib is not yet initialized and user runs another target, guide them
ifeq ($(wildcard $(MAKELIB_DIR)/core.mk),)
.DEFAULT_GOAL := help-uninitialized

# If makelib is not yet initialized and user runs another target, auto-initialize
ifeq ($(wildcard $(MAKELIB_DIR)/core.mk),)
.DEFAULT_GOAL := help-uninitialized

help-uninitialized:
	@echo "makelib-node is not initialized in '$(MAKELIB_DIR)'."
	@echo "Run 'make init' to automatically add the submodule and configure the toolchain."

%:
	@echo "makelib-node is not initialized in '$(MAKELIB_DIR)'. Auto-initializing..."
	@$(MAKE) init
	@$(MAKE) $@
endif
