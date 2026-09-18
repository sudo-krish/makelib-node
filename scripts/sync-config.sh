#!/usr/bin/env bash
# ==============================================================================
# scripts/sync-config.sh — Synchronize Golden Toolchain Configs Downstream
# ==============================================================================
set -euo pipefail

MODE="${1:---sync}"
TEMPLATES_DIR="${TEMPLATES_DIR:-templates}"
MAKELIB_DIR="${MAKELIB_DIR:-.makelib}"
MAKELIB_REPO="${MAKELIB_REPO:-sudo-krish/makelib-node}"
MAKELIB_REF="${MAKELIB_REF:-main}"
RAW_BASE_URL="https://raw.githubusercontent.com/${MAKELIB_REPO}/${MAKELIB_REF}/templates"

COLOR_CYAN="\033[36m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_RESET="\033[0m"

log_info() { echo -e "${COLOR_CYAN}[INFO]${COLOR_RESET} $*"; }
log_success() { echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"; }
log_warn() { echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*"; }
log_error() { echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*"; }

CONFIG_FILES=(
  ".gitignore"
  "tsconfig.json"
  "eslint.config.mjs"
  ".prettierrc"
  ".prettierignore"
  "vitest.config.ts"
  "lefthook.yml"
  ".secrets.baseline"
)

copy_or_download() {
  local filename="$1"
  local target="./$filename"

  if [ -f "$target" ]; then
    if grep -qE "(NO-OVERRIDE|DO NOT OVERWRITE)" "$target" 2>/dev/null; then
      log_warn "Skipping $filename (contains NO-OVERRIDE marker)"
      return 0
    fi
  fi

  if [ -d "$TEMPLATES_DIR" ] && [ -f "$TEMPLATES_DIR/$filename" ]; then
    cp "$TEMPLATES_DIR/$filename" "$target"
    log_info "Synced $filename from local templates"
  else
    log_info "Fetching $filename from remote ${MAKELIB_REF}..."
    curl -fsSL "${RAW_BASE_URL}/${filename}" -o "$target" 2>/dev/null || {
      log_warn "Could not fetch ${filename} from remote (skipping)"
      return 0
    }
  fi
}

init_downstream() {
  log_info "Initializing downstream project layout..."
  mkdir -p src test scripts "${MAKELIB_DIR}"

  if [ ! -f "package.json" ]; then
    if [ -f "$TEMPLATES_DIR/package.json" ]; then
      cp "$TEMPLATES_DIR/package.json" "package.json"
    else
      curl -fsSL "${RAW_BASE_URL}/package.json" -o "package.json" 2>/dev/null || true
    fi
    log_info "Created initial package.json from template"
  fi

  for file in "${CONFIG_FILES[@]}"; do
    if [ ! -f "$file" ]; then
      copy_or_download "$file"
    else
      log_info "$file already exists; preserving."
    fi
  done

  log_success "Project initialized with makelib-node golden toolchain."
}

sync_configs() {
  log_info "Synchronizing golden toolchain configurations..."
  for file in "${CONFIG_FILES[@]}"; do
    copy_or_download "$file"
  done
  log_success "All configurations synchronized."
}

case "$MODE" in
  --init)
    init_downstream
    ;;
  --update|--sync|"")
    sync_configs
    ;;
  *)
    log_error "Unknown flag: $MODE. Use --init or --update."
    exit 1
    ;;
esac
