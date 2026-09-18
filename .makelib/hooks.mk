# ==============================================================================
# .makelib/hooks.mk — Git & Lefthook Hook Management
# ==============================================================================

.PHONY: install-hooks check-branch

install-hooks: ## Install Lefthook and native Git hooks for shift-left enforcement
	@echo -e "$(INFO_PREFIX) Installing Git and Lefthook hooks..."
	@bash $(SCRIPTS_DIR)/install-hooks.sh
	@echo -e "$(SUCCESS_PREFIX) Shift-left hooks installed successfully."

check-branch: ## Verify current branch adheres to shift-left naming policy
	@bash $(SCRIPTS_DIR)/check-branch.sh
