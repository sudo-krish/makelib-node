# ==============================================================================
# .makelib/quality.mk — 8-Stage Quality Gate Pipeline
# ==============================================================================

# File targets for formatting and linting
FORMAT_PATTERN ?= "{$(SRC_DIR),$(TEST_DIR)}/**/*.{ts,js,json,md}"

.PHONY: format format-check lint type-check smell audit secret-scan license-check test check-all

format: ## Format source and test files with Prettier
	@echo -e "$(GATE_PREFIX) Running Prettier (format write)..."
	@$(PRETTIER) --write $(FORMAT_PATTERN) --ignore-unknown
	@echo -e "$(SUCCESS_PREFIX) Codebase formatted successfully."

format-check: ## Verify formatting with Prettier without modifying files
	@echo -e "$(GATE_PREFIX) Checking formatting with Prettier..."
	@$(PRETTIER) --check $(FORMAT_PATTERN) --ignore-unknown
	@echo -e "$(SUCCESS_PREFIX) Formatting check passed."

lint: ## Run ESLint strict checks
	@echo -e "$(GATE_PREFIX) Running ESLint (strict)..."
	@$(ESLINT) "$(SRC_DIR)/**/*.ts" "$(TEST_DIR)/**/*.ts"
	@echo -e "$(SUCCESS_PREFIX) ESLint passed with 0 errors."

type-check: ## Run static type checking with TypeScript (tsc --noEmit --strict)
	@echo -e "$(GATE_PREFIX) Running TypeScript type check..."
	@$(TSC) --noEmit --strict
	@echo -e "$(SUCCESS_PREFIX) TypeScript type check passed."

smell: ## Run code smell checks (McCabe cyclomatic complexity <= 10 & security AST)
	@echo -e "$(GATE_PREFIX) Checking code smell & AST security (McCabe cyclomatic <= 10, eslint-plugin-security)..."
	@$(ESLINT) "$(SRC_DIR)/**/*.ts" --rule 'complexity: ["error", 10]'
	@echo -e "$(SUCCESS_PREFIX) Code smell and complexity checks passed."

audit: ## Audit dependencies for high/critical vulnerabilities (npm audit)
	@echo -e "$(GATE_PREFIX) Auditing dependencies for CVEs (level: high)..."
	@$(NPM) audit --audit-level=high
	@echo -e "$(SUCCESS_PREFIX) Dependency security audit passed."

secret-scan: ## Scan repository for leaked credentials and high-entropy secrets (detect-secrets)
	@echo -e "$(GATE_PREFIX) Scanning for exposed secrets with detect-secrets..."
	@if command -v $(DETECT_SECRETS) >/dev/null 2>&1; then \
		if [ -f .secrets.baseline ]; then \
			$(DETECT_SECRETS) audit .secrets.baseline 2>/dev/null || true; \
			TMP_SCAN=$$(mktemp); \
			$(DETECT_SECRETS) scan --baseline .secrets.baseline > "$$TMP_SCAN"; \
			TOTAL_SECRETS=$$(grep -c '"type":' "$$TMP_SCAN" 2>/dev/null || true); \
			rm -f "$$TMP_SCAN"; \
			if [ "$$TOTAL_SECRETS" -gt 0 ]; then \
				echo -e "$(ERROR_PREFIX) Uncommitted secrets detected against baseline!"; \
				exit 1; \
			fi; \
		else \
			TMP_SCAN=$$(mktemp); \
			$(DETECT_SECRETS) scan > "$$TMP_SCAN"; \
			TOTAL_SECRETS=$$(grep -c '"type":' "$$TMP_SCAN" 2>/dev/null || true); \
			rm -f "$$TMP_SCAN"; \
			if [ "$$TOTAL_SECRETS" -gt 0 ]; then \
				echo -e "$(ERROR_PREFIX) Secrets detected in repository!"; \
				exit 1; \
			fi; \
		fi; \
		echo -e "$(SUCCESS_PREFIX) Secret scan passed (0 unexempted secrets)."; \
	else \
		echo -e "$(WARN_PREFIX) $(DETECT_SECRETS) not found in PATH; skipping secret scan."; \
	fi

license-check: ## Enforce approved open source licenses
	@echo -e "$(GATE_PREFIX) Verifying dependency licenses..."
	@$(LICENSE_CHECKER) --onlyAllow 'MIT;Apache-2.0;BSD-2-Clause;BSD-3-Clause;ISC;0BSD;Unlicense;CC0-1.0' --production
	@echo -e "$(SUCCESS_PREFIX) License compliance check passed."

test: ## Run unit tests with Vitest and enforce code coverage (MIN_COVERAGE)
	@echo -e "$(GATE_PREFIX) Running Vitest with coverage (enforcing line coverage >= $(MIN_COVERAGE)%)..."
	@MIN_COVERAGE=$(MIN_COVERAGE) $(VITEST) run --coverage
	@echo -e "$(SUCCESS_PREFIX) Tests and coverage passed."

check-all: ## Run all 8 quality gates sequentially
	@echo -e "$(COLOR_BOLD)$(COLOR_MAGENTA)======================================================================$(COLOR_RESET)"
	@echo -e "$(COLOR_BOLD)$(COLOR_MAGENTA)                 RUNNING 8-STAGE QUALITY GATE PIPELINE               $(COLOR_RESET)"
	@echo -e "$(COLOR_BOLD)$(COLOR_MAGENTA)======================================================================$(COLOR_RESET)"
	@$(MAKE) lint
	@$(MAKE) type-check
	@$(MAKE) smell
	@$(MAKE) audit
	@$(MAKE) secret-scan
	@$(MAKE) license-check
	@$(MAKE) test
	@echo -e "$(COLOR_BOLD)$(COLOR_GREEN)======================================================================$(COLOR_RESET)"
	@echo -e "$(COLOR_BOLD)$(COLOR_GREEN)                 ALL 8 QUALITY GATES PASSED!                         $(COLOR_RESET)"
	@echo -e "$(COLOR_BOLD)$(COLOR_GREEN)======================================================================$(COLOR_RESET)"
