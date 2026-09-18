# ==============================================================================
# downstream_template.mk — Downstream Makefile for makelib-node
# ==============================================================================
# Copy this file to your repository root as `Makefile`.
# It provides zero-copy inclusion of makelib-node toolchain and quality gates.
# ==============================================================================

# Makelib repository settings (override if using a fork or internal mirror)
MAKELIB_REPO ?= sudo-krish/makelib-node
MAKELIB_REF  ?= main
MAKELIB_URL  ?= https://raw.githubusercontent.com/$(MAKELIB_REPO)/$(MAKELIB_REF)
MAKELIB_DIR  ?= .makelib

# ------------------------------------------------------------------------------
# Downstream Overrides (uncomment and adjust as needed)
# ------------------------------------------------------------------------------
# SRC_DIR      ?= src
# TEST_DIR     ?= test
# MIN_COVERAGE ?= 80

# ------------------------------------------------------------------------------
# Bootstrap Targets (available even before makelib is fetched)
# ------------------------------------------------------------------------------
.PHONY: init-makelib update-makelib sync-config

init-makelib: ## Initialize makelib in downstream repository
	@mkdir -p $(MAKELIB_DIR) scripts
	@echo "Fetching makelib-node from $(MAKELIB_REPO)@$(MAKELIB_REF)..."
	@for f in core.mk colors.mk quality.mk release.mk hooks.mk; do \
		curl -fsSL "$(MAKELIB_URL)/.makelib/$$f" -o "$(MAKELIB_DIR)/$$f"; \
	done
	@for s in sync-config.sh check-branch.sh semver-release.sh install-hooks.sh; do \
		curl -fsSL "$(MAKELIB_URL)/scripts/$$s" -o "scripts/$$s" && chmod +x "scripts/$$s"; \
	done
	@bash scripts/sync-config.sh --init
	@echo "makelib-node initialized successfully. Run 'make help' or 'make install-hooks'."

update-makelib: ## Update makelib core files to latest ref
	@mkdir -p $(MAKELIB_DIR) scripts
	@echo "Updating makelib-node from $(MAKELIB_REPO)@$(MAKELIB_REF)..."
	@for f in core.mk colors.mk quality.mk release.mk hooks.mk; do \
		curl -fsSL "$(MAKELIB_URL)/.makelib/$$f" -o "$(MAKELIB_DIR)/$$f"; \
	done
	@for s in sync-config.sh check-branch.sh semver-release.sh install-hooks.sh; do \
		curl -fsSL "$(MAKELIB_URL)/scripts/$$s" -o "scripts/$$s" && chmod +x "scripts/$$s"; \
	done
	@if [ -f scripts/sync-config.sh ]; then bash scripts/sync-config.sh --update; fi
	@echo "makelib-node updated successfully."

sync-config: ## Sync golden configurations from makelib
	@if [ -f scripts/sync-config.sh ]; then \
		bash scripts/sync-config.sh; \
	else \
		echo "makelib scripts not found. Run 'make init-makelib' first."; exit 1; \
	fi

# ------------------------------------------------------------------------------
# Zero-Copy Makelib Core Inclusion
# ------------------------------------------------------------------------------
-include $(MAKELIB_DIR)/core.mk
