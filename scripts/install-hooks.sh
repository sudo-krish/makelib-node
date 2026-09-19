#!/usr/bin/env bash
# ==============================================================================
# scripts/install-hooks.sh — Shift-Left Git Hook Installer
# ==============================================================================
set -euo pipefail

COLOR_CYAN="\033[36m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_RESET="\033[0m"

log_info() { echo -e "${COLOR_CYAN}[INFO]${COLOR_RESET} $*"; }
log_success() { echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"; }
log_warn() { echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*"; }
log_error() { echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*"; }

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  log_warn "Not inside a Git work tree. Skipping Git hook installation."
  exit 0
fi

GIT_DIR=$(git rev-parse --git-dir)
HOOKS_DIR="${GIT_DIR}/hooks"
mkdir -p "$HOOKS_DIR"

# 1. Install Lefthook if available in makelib or local toolchain
if [ -f ".makelib/node_modules/.bin/lefthook" ] && [ -f "lefthook.yml" ]; then
  log_info "Configuring Lefthook git hooks from makelib toolchain..."
  ./.makelib/node_modules/.bin/lefthook install || log_warn "Lefthook install failed; falling back to native Git hooks."
elif command -v lefthook >/dev/null 2>&1 && [ -f "lefthook.yml" ]; then
  log_info "Configuring Lefthook git hooks..."
  lefthook install || log_warn "Lefthook install failed; falling back to native Git hooks."
fi

# 2. Install native shift-left Git hooks
log_info "Installing native shift-left Git hooks into ${HOOKS_DIR}..."

# Native pre-commit hook
cat << 'EOF' > "${HOOKS_DIR}/pre-commit"
#!/usr/bin/env bash
set -euo pipefail

# Execute branch policy check
if [ -f "scripts/check-branch.sh" ]; then
  bash scripts/check-branch.sh
fi

# Resolve makelib toolchain binaries
export PATH="./.makelib/node_modules/.bin:./node_modules/.bin:${PATH}"
export NODE_PATH="./.makelib/node_modules:./node_modules:${NODE_PATH:-}"

# Run fast type check if TypeScript and tsconfig present
if command -v tsc >/dev/null 2>&1 && [ -f "tsconfig.json" ]; then
  echo -e "\033[36m[HOOK]\033[0m Running pre-commit type check..."
  tsc --noEmit --strict
fi

# Run fast lint check if ESLint present
if command -v eslint >/dev/null 2>&1 && [ -d "src" ]; then
  echo -e "\033[36m[HOOK]\033[0m Running pre-commit lint..."
  eslint "src/**/*.ts" 2>/dev/null || true
fi
EOF
chmod +x "${HOOKS_DIR}/pre-commit"

# Native commit-msg hook
cat << 'EOF' > "${HOOKS_DIR}/commit-msg"
#!/usr/bin/env bash
set -euo pipefail

if [ -f "scripts/check-branch.sh" ]; then
  bash scripts/check-branch.sh
fi
EOF
chmod +x "${HOOKS_DIR}/commit-msg"

log_success "Native Git hooks installed: pre-commit, commit-msg."
log_success "Shift-left branch policy enforcement active."
