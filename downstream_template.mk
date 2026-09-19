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
.PHONY: init init-makelib update update-makelib sync-config

init: init-makelib
update: update-makelib

init-makelib: ## Initialize makelib in downstream repository
	@echo "Fetching makelib-node from $(MAKELIB_REPO)@$(MAKELIB_REF)..."
	@TMP_DIR=$$(mktemp -d 2>/dev/null || mktemp -d -t 'makelib'); \
	if curl -fsSL "https://github.com/$(MAKELIB_REPO)/archive/$(MAKELIB_REF).tar.gz" | tar -xz -C "$$TMP_DIR" 2>/dev/null; then \
		EXTRACT_DIR=$$(find "$$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1); \
		mkdir -p $(MAKELIB_DIR) scripts templates; \
		cp -r "$$EXTRACT_DIR/.makelib/." $(MAKELIB_DIR)/; \
		cp -r "$$EXTRACT_DIR/scripts/." scripts/ && chmod +x scripts/*.sh; \
		if [ -d "$$EXTRACT_DIR/templates" ]; then cp -r "$$EXTRACT_DIR/templates/." templates/; fi; \
		rm -rf "$$TMP_DIR"; \
	else \
		rm -rf "$$TMP_DIR"; \
		echo "Tarball fetch failed, falling back to direct download..."; \
		mkdir -p $(MAKELIB_DIR) scripts; \
		for f in colors.mk quality.mk release.mk hooks.mk package.json core.mk; do \
			curl -fsSL "$(MAKELIB_URL)/.makelib/$$f" -o "$(MAKELIB_DIR)/$$f" || true; \
		done; \
		for s in sync-config.sh check-branch.sh semver-release.sh install-hooks.sh; do \
			curl -fsSL "$(MAKELIB_URL)/scripts/$$s" -o "scripts/$$s" && chmod +x "scripts/$$s" || true; \
		done; \
	fi
	@if [ -f scripts/sync-config.sh ]; then bash scripts/sync-config.sh --init; fi
	@echo "makelib-node initialized successfully. Run 'make help' or 'make install-hooks'."

update-makelib: ## Update makelib core files to latest ref
	@echo "Updating makelib-node from $(MAKELIB_REPO)@$(MAKELIB_REF)..."
	@TMP_DIR=$$(mktemp -d 2>/dev/null || mktemp -d -t 'makelib'); \
	if curl -fsSL "https://github.com/$(MAKELIB_REPO)/archive/$(MAKELIB_REF).tar.gz" | tar -xz -C "$$TMP_DIR" 2>/dev/null; then \
		EXTRACT_DIR=$$(find "$$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1); \
		mkdir -p $(MAKELIB_DIR) scripts templates; \
		cp -r "$$EXTRACT_DIR/.makelib/." $(MAKELIB_DIR)/; \
		cp -r "$$EXTRACT_DIR/scripts/." scripts/ && chmod +x scripts/*.sh; \
		if [ -d "$$EXTRACT_DIR/templates" ]; then cp -r "$$EXTRACT_DIR/templates/." templates/; fi; \
		rm -rf "$$TMP_DIR"; \
	else \
		rm -rf "$$TMP_DIR"; \
		echo "Tarball fetch failed, falling back to direct download..."; \
		mkdir -p $(MAKELIB_DIR) scripts; \
		for f in colors.mk quality.mk release.mk hooks.mk package.json core.mk; do \
			curl -fsSL "$(MAKELIB_URL)/.makelib/$$f" -o "$(MAKELIB_DIR)/$$f" || true; \
		done; \
		for s in sync-config.sh check-branch.sh semver-release.sh install-hooks.sh; do \
			curl -fsSL "$(MAKELIB_URL)/scripts/$$s" -o "scripts/$$s" && chmod +x "scripts/$$s" || true; \
		done; \
	fi
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
# Only include if makelib is fully initialized to prevent errors on partial state
ifneq ($(wildcard $(MAKELIB_DIR)/hooks.mk),)
-include $(MAKELIB_DIR)/core.mk
endif
