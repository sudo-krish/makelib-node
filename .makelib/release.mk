# ==============================================================================
# .makelib/release.mk — SemVer Release Automation
# ==============================================================================

.PHONY: bump-patch bump-minor bump-major release-classify release-bump release

bump-patch: ## Increment patch version (x.y.Z) without git tag
	@echo -e "$(INFO_PREFIX) Bumping patch version..."
	@$(NPM) version patch --no-git-tag-version
	@echo -e "$(SUCCESS_PREFIX) Version bumped to: $$($(NODE) -p "require('./package.json').version")"

bump-minor: ## Increment minor version (x.Y.0) without git tag
	@echo -e "$(INFO_PREFIX) Bumping minor version..."
	@$(NPM) version minor --no-git-tag-version
	@echo -e "$(SUCCESS_PREFIX) Version bumped to: $$($(NODE) -p "require('./package.json').version")"

bump-major: ## Increment major version (X.0.0) without git tag
	@echo -e "$(INFO_PREFIX) Bumping major version..."
	@$(NPM) version major --no-git-tag-version
	@echo -e "$(SUCCESS_PREFIX) Version bumped to: $$($(NODE) -p "require('./package.json').version")"

release-classify: ## Classify SemVer release level from current branch
	@bash $(SCRIPTS_DIR)/semver-release.sh --classify

release-bump: ## Increment SemVer based on current branch classification
	@BUMP_LEVEL=$$(bash $(SCRIPTS_DIR)/semver-release.sh --level); \
	case "$$BUMP_LEVEL" in \
		major) $(MAKE) bump-major ;; \
		minor) $(MAKE) bump-minor ;; \
		patch) $(MAKE) bump-patch ;; \
		*) echo -e "$(ERROR_PREFIX) Unknown bump level: $$BUMP_LEVEL"; exit 1 ;; \
	esac

release: check-all ## Run check-all, classify & bump version, commit and create git tag
	@echo -e "$(INFO_PREFIX) Initiating automated release pipeline..."
	@$(MAKE) release-bump
	@NEW_VERSION=$$($(NODE) -p "require('./package.json').version"); \
	echo -e "$(INFO_PREFIX) Creating release commit and git tag for v$${NEW_VERSION}..."; \
	git add package.json package-lock.json 2>/dev/null || git add package.json; \
	git commit -m "chore(release): v$${NEW_VERSION}" --no-verify; \
	git tag -a "v$${NEW_VERSION}" -m "Release v$${NEW_VERSION}"; \
	echo -e "$(SUCCESS_PREFIX) Release v$${NEW_VERSION} successfully tagged."
