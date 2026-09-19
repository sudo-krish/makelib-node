# makelib-node

[![License: MIT](https://img.shields.io/badge/License-apache-yellow.svg)](https://opensource.org/licenses/MIT)
[![TypeScript](https://img.shields.io/badge/TypeScript-Strict-blue.svg)](https://www.typescriptlang.org/)
[![Vitest](<https://img.shields.io/badge/Tested%20with-Vitest-green.svg>)](https://vitest.dev/)
[![ESLint](<https://img.shields.io/badge/ESLint-Strict%20%26%20Security-purple.svg>)](https://eslint.org/)
[![Lefthook](<https://img.shields.io/badge/Git%20Hooks-Lefthook-red.svg>)](https://github.com/evilmartians/lefthook)

> **Centralized, self-hosting Make library & golden toolchain configuration for Node.js / TypeScript projects.**
> Mirroring the architecture of `makelib-py`, `makelib-node` provides a zero-copy downstream inclusion model, an 8-stage quality gate pipeline, strict shift-left branch naming policy enforced at the commit level, and automated SemVer release classification.

---

## Table of Contents

- [1. Core Architecture & Philosophy](#1-core-architecture--philosophy)
- [2. Quickstart for Downstream Repositories](#2-quickstart-for-downstream-repositories)
- [3. The 8 Quality Gates](#3-the-8-quality-gates)
- [4. Shift-Left Branch Policy & SemVer Release Engine](#4-shift-left-branch-policy--semver-release-engine)
- [5. CI/CD & Automated Release Pipelines](#5-cicd--automated-release-pipelines)
- [6. Configuration Overrides](#6-configuration-overrides)
- [7. Operational Targets](#7-operational-targets)
- [8. Self-Hosting Verification](#8-self-hosting-verification)

---

## 1. Core Architecture & Philosophy

1. **Zero-Copy Downstream Model**: Downstream projects do **not** duplicate Makefiles. Instead, they include `.makelib/core.mk` using GNU Make's `-include`. A copy-paste [`downstream_template.mk`](./downstream_template.mk) provides bootstrap targets (`init-makelib`, `update-makelib`, `sync-config`).
2. **Golden Toolchain Distribution**: Distributes standardized configurations (`tsconfig.json`, `eslint.config.mjs`, `.prettierrc`, `vitest.config.ts`, `lefthook.yml`, `.secrets.baseline`) that downstream repositories synchronize via `make sync-config`.
3. **Overridable Defaults**: All Make variables in `core.mk` use conditional assignment (`?=`) so downstream repos can override source directories, test directories, coverage thresholds, or binary paths without modifying the core library.
4. **Shift-Left Enforcement**: Invalid branch names and direct commits to `main`/`master` fail immediately at commit time (via Lefthook and native Git hooks) before unclassified code can be committed or pushed.
5. **Branch-Driven SemVer**: Branch prefixes automatically drive version increments (`major`, `minor`, `patch`) upon release.

---

## 2. Quickstart for Downstream Repositories

### Step 1: Copy the downstream template

Copy [`downstream_template.mk`](./downstream_template.mk) to your repository root as `Makefile`:

```bash
curl -fsSL https://raw.githubusercontent.com/sudo-krish/makelib-node/main/downstream_template.mk -o Makefile
```

### Step 2: Initialize makelib

Run `make init` (or `make init-makelib`) to fetch the core Make library and golden configurations:

```bash
make init
```

This bootstraps:

- `.makelib/` (`core.mk`, `colors.mk`, `quality.mk`, `release.mk`, `hooks.mk`)
- `scripts/` (`sync-config.sh`, `check-branch.sh`, `semver-release.sh`, `install-hooks.sh`)
- Golden toolchain configs (`tsconfig.json`, `eslint.config.mjs`, `.prettierrc`, `vitest.config.ts`, `lefthook.yml`, `.secrets.baseline`)

### Step 3: Install dependencies and activate shift-left hooks

```bash
npm install
make install-hooks
```

---

## 3. The 8 Quality Gates

`makelib-node` provides 8 industrial-grade quality gates exposed via standard Make targets:

| Target                 | Quality Gate                 | Engine / Tool                  | Behavior & Standards                                                                              |
| :--------------------- | :--------------------------- | :----------------------------- | :------------------------------------------------------------------------------------------------ |
| `make format`        | Formatting & Style           | **Prettier**             | Formats`.ts`, `.js`, `.json`, `.md` in `$(SRC_DIR)` and `$(TEST_DIR)`.                |
| `make format-check`  | Format Verification          | **Prettier**             | Non-mutating verification; exits 1 if code requires formatting.                                   |
| `make lint`          | Bug & Style Rules            | **ESLint** (strict)      | TypeScript-ESLint strict rules; fails on unused vars, unhandled edge cases.                       |
| `make type-check`    | Static Type Safety           | **TypeScript (`tsc`)** | `tsc --noEmit --strict` enforcing zero type errors.                                             |
| `make smell`         | AST Security & Complexity    | **ESLint**               | Enforces McCabe cyclomatic complexity$\le 10$ and `eslint-plugin-security`.                   |
| `make audit`         | CVE Vulnerabilities          | **`npm audit`**        | Fails on high or critical CVEs:`npm audit --audit-level=high`.                                  |
| `make secret-scan`   | Leak & Secret Scanner        | **`detect-secrets`**   | Deep scans repo for leaked tokens, private keys, high entropy strings against baseline.           |
| `make license-check` | License Compliance           | **`license-checker`**  | Enforces approved open-source licenses (`MIT`, `Apache-2.0`, `BSD-2/3`, `ISC`, `0BSD`). |
| `make test`          | Testing & Code Coverage      | **Vitest**               | Runs unit tests, enforcing line coverage$\ge 80\%$ (`MIN_COVERAGE`).                          |
| `make check-all`     | **Master Gate Runner** | All 8 Gates                    | Runs`lint type-check smell audit secret-scan license-check test` sequentially.                  |

---

## 4. Shift-Left Branch Policy & SemVer Release Engine

### Branch Naming Standard

Direct commits to `main` and `master` are strictly rejected at commit time. All work must take place on a classified branch adhering to the standard regex:

```regex
^(feat|feature|fix|patch|major|breaking|docs|chore|refactor|ci)/[a-z0-9._-]+$
```

### Branch Prefix to SemVer Release Mapping

| Branch Prefix                                        | SemVer Level    | Example Version Shift               | Classification & Usage                                           |
| :--------------------------------------------------- | :-------------- | :---------------------------------- | :--------------------------------------------------------------- |
| `major/<name>`, `breaking/<name>`                | **MAJOR** | `1.0.0` $\rightarrow$ `2.0.0` | Breaking changes, incompatible API modifications                 |
| `feat/<name>`, `feature/<name>`                  | **MINOR** | `1.0.0` $\rightarrow$ `1.1.0` | New user-facing features, modules, backward-compatible additions |
| `fix/<name>`, `patch/<name>`                     | **PATCH** | `1.0.0` $\rightarrow$ `1.0.1` | Bug fixes, security patches                                      |
| `docs/<name>`                                      | **PATCH** | `1.0.0` $\rightarrow$ `1.0.1` | Documentation updates, guides, README changes                    |
| `chore/<name>`, `refactor/<name>`, `ci/<name>` | **PATCH** | `1.0.0` $\rightarrow$ `1.0.1` | Refactorings, dependency bumps, CI workflow tweaks               |

### Git Hook Enforcement

Run `make install-hooks` to configure both:

1. **Lefthook**: Modern fast hook manager running branch validation, format check, and linting.
2. **Native Git Hooks**: Fallback `.git/hooks/pre-commit` and `.git/hooks/commit-msg` ensuring shift-left enforcement even in headless or minimal environments.

---

## 5. CI/CD & Automated Release Pipelines

`makelib-node` ships with production GitHub Actions workflows for both internal self-hosting and downstream repositories (distributed via `templates/.github/workflows/`):

### Continuous Integration (`.github/workflows/ci.yml`)
- **Trigger**: Every push to feature branches and pull requests targeting `main`.
- **Shift-Left Branch Validation**: Verifies that the source branch matches `^(feat|feature|fix|patch|major|breaking|docs|chore|refactor|ci)/[a-z0-9._-]+$`.
- **Quality Gate Execution**: Sets up Node.js 22, Python 3.11, and `detect-secrets`, then executes `make check-all` (all 8 quality gates sequentially).
- **Compilation & Artifact Upload**: Executes `make build` and archives `dist/` bundles and `coverage/` reports.

### Continuous Delivery & Automated Release (`.github/workflows/release.yml`)
- **Trigger**: Automatically upon closing/merging a Pull Request into `main` (or via manual `workflow_dispatch`).
- **SemVer Level Resolution**: Uses `scripts/semver-release.sh` to extract the merged branch prefix (`major`/`breaking` $\rightarrow$ MAJOR, `feat`/`feature` $\rightarrow$ MINOR, `fix`/`patch`/`docs`/`chore`/`refactor`/`ci` $\rightarrow$ PATCH).
- **Automated Version Bump**: Bumps `package.json` and `package-lock.json` with `npm version <level> --no-git-tag-version`.
- **Tag & Release Publishing**: Creates an annotated Git tag `v<version>`, pushes to GitHub with `[skip ci]`, and creates a GitHub Release with compiled distribution assets and auto-generated release notes.
- **NPM Publishing**: Publishes to the NPM registry if `NPM_TOKEN` secret is configured in repository secrets.

---

## 6. Configuration Overrides

Every Make variable in `core.mk` uses `?=` and can be overridden in downstream Makefiles or via command line arguments:

```makefile
# Downstream Makefile example:
SRC_DIR      ?= lib
TEST_DIR     ?= tests
MIN_COVERAGE ?= 90
```

Or on invocation:

```bash
make test MIN_COVERAGE=90
```

### Available Toolchain Overrides

- `SRC_DIR`: Source directory (default: `src`)
- `TEST_DIR`: Test directory (default: `test`)
- `DIST_DIR`: Output build directory (default: `dist`)
- `MIN_COVERAGE`: Minimum line coverage percentage (default: `80`)
- `NODE`, `NPM`, `NPX`, `TSC`, `ESLINT`, `PRETTIER`, `VITEST`, `TSUP`, `LEFTHOOK`, `DETECT_SECRETS`, `LICENSE_CHECKER`

---

## 7. Operational Targets

- `make help`: Colorized, self-documenting list of targets parsed dynamically from `##` doc comments.
- `make clean`: Removes `dist/`, `coverage/`, `.turbo/`, `node_modules/.cache/`, and temporary build artifacts.
- `make build`: Cleans and compiles production bundles into `dist/` with types and CJS/ESM formats using `tsup`.
- `make bump-patch`: Increments patch version (`npm version patch --no-git-tag-version`).
- `make bump-minor`: Increments minor version (`npm version minor --no-git-tag-version`).
- `make bump-major`: Increments major version (`npm version major --no-git-tag-version`).
- `make release-classify`: Inspects current branch and outputs SemVer level.
- `make release-bump`: Bumps package version based on current branch classification.
- `make release`: Runs `check-all`, calculates version bump, creates release commit, and creates annotated Git tag.

---

## 8. Self-Hosting Verification

`makelib-node` is completely self-hosting. To verify the entire toolchain against itself:

```bash
# Display help menu
make help

# Run all 8 quality gates sequentially
make check-all

# Compile distribution bundle
make build
```

---

## License

Apache © [Krish](https://github.com/sudo-krish)
