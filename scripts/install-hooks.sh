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

# 0. Ensure lefthook.yml is present in workspace root
if [ ! -f "lefthook.yml" ]; then
  for candidate in ".makelib/lefthook.yml" "makelib/lefthook.yml"; do
    if [ -f "$candidate" ]; then
      log_info "Scaffolding lefthook.yml from $candidate..."
      cp "$candidate" "./lefthook.yml"
      break
    fi
  done
  if [ ! -f "lefthook.yml" ]; then
    log_info "Creating default lefthook.yml..."
    cat << 'EOF' > "lefthook.yml"
# ==============================================================================
# lefthook.yml — Shift-Left Git Hook Pipeline
# ==============================================================================

pre-commit:
  parallel: false
  commands:
    01-check-branch:
      run: make check-branch
    02-format:
      run: make format-check
    03-lint:
      run: make lint
    04-type-check:
      run: make type-check

commit-msg:
  commands:
    check-branch:
      run: make check-branch
EOF
  fi
else
  log_info "lefthook.yml already exists; preserving."
  MISSING_HOOKS=()
  if ! grep -q "make format-check\|make format" "lefthook.yml"; then
    MISSING_HOOKS+=("make format-check")
  fi
  if ! grep -q "make lint" "lefthook.yml"; then
    MISSING_HOOKS+=("make lint")
  fi
  if ! grep -q "make type-check" "lefthook.yml"; then
    MISSING_HOOKS+=("make type-check")
  fi
  if ! grep -q "make check-branch\|check-branch" "lefthook.yml"; then
    MISSING_HOOKS+=("make check-branch")
  fi

  if [ ${#MISSING_HOOKS[@]} -gt 0 ]; then
    echo -e "${COLOR_YELLOW}======================================================================${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}[WARN] Existing lefthook.yml is missing recommended quality hooks:${COLOR_RESET}"
    for hook in "${MISSING_HOOKS[@]}"; do
      echo -e "${COLOR_YELLOW}       - ${hook}${COLOR_RESET}"
    done
    echo -e "${COLOR_YELLOW}       Consider adding them to your pre-commit commands in lefthook.yml:${COLOR_RESET}"
    echo -e "         pre-commit:"
    echo -e "           commands:"
    echo -e "             01-check-branch: { run: make check-branch }"
    echo -e "             02-format:       { run: make format-check }"
    echo -e "             03-lint:         { run: make lint }"
    echo -e "             04-type-check:   { run: make type-check }"
    echo -e "${COLOR_YELLOW}======================================================================${COLOR_RESET}"
  fi
fi

# 1. Install Lefthook if available in makelib or local toolchain
LEFTHOOK_BIN=""
for candidate in "./.makelib/node_modules/.bin/lefthook" "./makelib/node_modules/.bin/lefthook" "./node_modules/.bin/lefthook"; do
  if [ -x "$candidate" ]; then
    LEFTHOOK_BIN="$candidate"
    break
  fi
done

if [ -n "$LEFTHOOK_BIN" ] && [ -f "lefthook.yml" ]; then
  log_info "Configuring Lefthook git hooks from makelib toolchain ($LEFTHOOK_BIN)..."
  "$LEFTHOOK_BIN" install || log_warn "Lefthook install failed; falling back to native Git hooks."
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
for branch_script in "scripts/check-branch.sh" ".makelib/scripts/check-branch.sh" "makelib/scripts/check-branch.sh"; do
  if [ -f "$branch_script" ]; then
    bash "$branch_script"
    break
  fi
done

# Resolve makelib toolchain binaries
export PATH="./.makelib/node_modules/.bin:./makelib/node_modules/.bin:./node_modules/.bin:${PATH}"
export NODE_PATH="./.makelib/node_modules:./makelib/node_modules:./node_modules:${NODE_PATH:-}"

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
