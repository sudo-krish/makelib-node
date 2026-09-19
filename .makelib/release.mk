# ==============================================================================
# .makelib/release.mk — SemVer Release Automation
# ==============================================================================

.PHONY: bump-patch bump-minor bump-major release-classify release-bump release

bump-patch: ## Increment patch version (x.y.Z) without git tag
	@echo -e "$(INFO_PREFIX) Bumping patch version..."
	@NEW_V=$$(bash $(SCRIPTS_DIR)/semver-release.sh --level patch --bump); \
	echo -e "$(SUCCESS_PREFIX) Version bumped to: v$$NEW_V"

bump-minor: ## Increment minor version (x.Y.0) without git tag
	@echo -e "$(INFO_PREFIX) Bumping minor version..."
	@NEW_V=$$(bash $(SCRIPTS_DIR)/semver-release.sh --level minor --bump); \
	echo -e "$(SUCCESS_PREFIX) Version bumped to: v$$NEW_V"

bump-major: ## Increment major version (X.0.0) without git tag
	@echo -e "$(INFO_PREFIX) Bumping major version..."
	@NEW_V=$$(bash $(SCRIPTS_DIR)/semver-release.sh --level major --bump); \
	echo -e "$(SUCCESS_PREFIX) Version bumped to: v$$NEW_V"

release-classify: ## Classify SemVer release level from current branch
	@bash $(SCRIPTS_DIR)/semver-release.sh --classify

release-bump: ## Increment SemVer based on current branch classification
	@NEW_V=$$(bash $(SCRIPTS_DIR)/semver-release.sh --bump); \
	echo -e "$(SUCCESS_PREFIX) Version bumped to: v$$NEW_V"

release: check-all ## Run check-all, classify & bump version, commit and create git tag
	@echo -e "$(INFO_PREFIX) Initiating automated release pipeline..."
	@NEW_VERSION=$$(bash $(SCRIPTS_DIR)/semver-release.sh --next-version); \
	echo -e "$(INFO_PREFIX) Next version determined: v$${NEW_VERSION}"; \
	bash $(SCRIPTS_DIR)/semver-release.sh --apply "$${NEW_VERSION}"; \
	git add package.json package-lock.json 2>/dev/null || true; \
	if ! git diff --cached --quiet; then \
		git commit -m "chore(release): v$${NEW_VERSION} [skip ci]" --no-verify; \
	fi; \
	git tag -a "v$${NEW_VERSION}" -m "Release v$${NEW_VERSION}"; \
	echo -e "$(SUCCESS_PREFIX) Release v$${NEW_VERSION} successfully tagged."
