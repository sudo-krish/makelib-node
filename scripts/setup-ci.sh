#!/usr/bin/env bash
# ==============================================================================
# scripts/setup-ci.sh — Downstream CI/CD Workflow Generator
# ==============================================================================
set -euo pipefail

COLOR_CYAN="\033[36m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RESET="\033[0m"

log_info() { echo -e "${COLOR_CYAN}[INFO]${COLOR_RESET} $*"; }
log_success() { echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"; }
log_warn() { echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*"; }

WORKFLOWS_DIR=".github/workflows"
mkdir -p "$WORKFLOWS_DIR"

# 1. Scaffold CI Workflow with Submodule Checkout
CI_FILE="${WORKFLOWS_DIR}/ci.yml"
if [ ! -f "$CI_FILE" ]; then
  log_info "Creating ${CI_FILE} with submodules: recursive support..."
  cat << 'EOF' > "$CI_FILE"
name: CI Quality Gate

on:
  push:
    branches-ignore:
      - main
      - master
  pull_request:
    branches:
      - main
      - master

jobs:
  quality:
    name: 8-Stage Quality Gate Pipeline
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository with submodules
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          submodules: recursive

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 22

      - name: Initialize makelib toolchain
        run: make init

      - name: Run all 8 quality gates
        run: make check-all
EOF
  log_success "Created ${CI_FILE}"
else
  log_info "${CI_FILE} already exists; preserving."
  # Check if existing workflow has submodules: recursive configured
  if ! grep -q "submodules:\s*recursive" "$CI_FILE"; then
    echo -e "${COLOR_YELLOW}======================================================================${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}[WARN] Existing CI workflow (${CI_FILE}) is missing 'submodules: recursive'!${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}       GitHub Actions will fail with 'No rule to make target' unless submodules are cloned.${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}       Please add these lines to your 'actions/checkout@v4' step in ${CI_FILE}:${COLOR_RESET}"
    echo -e "         with:"
    echo -e "           fetch-depth: 0"
    echo -e "           submodules: recursive"
    echo -e "         run: make init"
    echo -e "${COLOR_YELLOW}======================================================================${COLOR_RESET}"
  fi
fi

# 2. Scaffold Release Workflow with Submodule Checkout
RELEASE_FILE="${WORKFLOWS_DIR}/release.yml"
if [ ! -f "$RELEASE_FILE" ]; then
  log_info "Creating ${RELEASE_FILE}..."
  cat << 'EOF' > "$RELEASE_FILE"
name: Automated SemVer Release

on:
  pull_request:
    types: [closed]
    branches:
      - main
  workflow_dispatch:

jobs:
  release:
    name: Release & Tag
    if: github.event.pull_request.merged == true || github.event_name == 'workflow_dispatch'
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - name: Checkout repository with submodules
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          submodules: recursive

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 22

      - name: Initialize makelib
        run: make init

      - name: Configure Git
        run: |
          git config --global user.name "github-actions[bot]"
          git config --global user.email "github-actions[bot]@users.noreply.github.com"

      - name: Execute release pipeline
        run: make release

      - name: Push release tag
        run: git push --tags
EOF
  log_success "Created ${RELEASE_FILE}"
else
  log_info "${RELEASE_FILE} already exists; preserving."
  if ! grep -q "submodules:\s*recursive" "$RELEASE_FILE"; then
    echo -e "${COLOR_YELLOW}======================================================================${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}[WARN] Existing release workflow (${RELEASE_FILE}) is missing 'submodules: recursive'!${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}       Please add 'submodules: recursive' to your checkout step in ${RELEASE_FILE}.${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}======================================================================${COLOR_RESET}"
  fi
fi
