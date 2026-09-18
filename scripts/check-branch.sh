#!/usr/bin/env bash
# ==============================================================================
# scripts/check-branch.sh — Shift-Left Branch Policy Validator
# ==============================================================================
set -euo pipefail

COLOR_CYAN="\033[36m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_BOLD="\033[1m"
COLOR_RESET="\033[0m"

# Enforced branch naming regex
BRANCH_REGEX="^(feat|feature|fix|patch|major|breaking|docs|chore|refactor|ci)/[a-z0-9._-]+$"

# Support passing branch as argument (for testing/CI) or query git
CURRENT_BRANCH="${1:-}"

if [ -z "$CURRENT_BRANCH" ]; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  fi
fi

# Bypass in detached HEAD state (e.g. CI runner checking out a commit/tag, or git rebase)
if [ "$CURRENT_BRANCH" = "HEAD" ] || [ -z "$CURRENT_BRANCH" ]; then
  echo -e "${COLOR_YELLOW}[WARN] Detached HEAD or non-git environment detected. Skipping branch check.${COLOR_RESET}"
  exit 0
fi

# Block direct commits to protected primary branches
if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
  echo -e "${COLOR_RED}${COLOR_BOLD}[ERROR] Shift-Left Policy Violation:${COLOR_RESET}"
  echo -e "${COLOR_RED}Direct commits to '${CURRENT_BRANCH}' are strictly prohibited!${COLOR_RESET}"
  echo -e "All changes must occur on a classified branch matching:"
  echo -e "  ${COLOR_CYAN}${BRANCH_REGEX}${COLOR_RESET}"
  echo -e ""
  echo -e "To switch to a compliant branch:"
  echo -e "  git checkout -b feat/<description>   # Minor release"
  echo -e "  git checkout -b fix/<description>    # Patch release"
  echo -e "  git checkout -b major/<description>  # Major release"
  exit 1
fi

# Validate branch name against regex
if [[ ! "$CURRENT_BRANCH" =~ $BRANCH_REGEX ]]; then
  echo -e "${COLOR_RED}${COLOR_BOLD}[ERROR] Invalid Branch Name:${COLOR_RESET} '${CURRENT_BRANCH}'"
  echo -e "${COLOR_RED}Branch does not conform to the required shift-left naming standard.${COLOR_RESET}"
  echo -e ""
  echo -e "Expected regex format:"
  echo -e "  ${COLOR_CYAN}${BRANCH_REGEX}${COLOR_RESET}"
  echo -e ""
  echo -e "Allowed branch prefixes:"
  echo -e "  ${COLOR_CYAN}feat/<name>${COLOR_RESET}, ${COLOR_CYAN}feature/<name>${COLOR_RESET}  -> MINOR bump (new features)"
  echo -e "  ${COLOR_CYAN}fix/<name>${COLOR_RESET}, ${COLOR_CYAN}patch/<name>${COLOR_RESET}      -> PATCH bump (bug fixes)"
  echo -e "  ${COLOR_CYAN}major/<name>${COLOR_RESET}, ${COLOR_CYAN}breaking/<name>${COLOR_RESET} -> MAJOR bump (breaking changes)"
  echo -e "  ${COLOR_CYAN}docs/<name>${COLOR_RESET}                     -> PATCH bump (documentation)"
  echo -e "  ${COLOR_CYAN}chore/<name>${COLOR_RESET}, ${COLOR_CYAN}refactor/<name>${COLOR_RESET}  -> PATCH bump (maintenance)"
  echo -e "  ${COLOR_CYAN}ci/<name>${COLOR_RESET}                        -> PATCH bump (CI workflows)"
  exit 1
fi

echo -e "${COLOR_GREEN}[SUCCESS] Branch name '${CURRENT_BRANCH}' satisfies shift-left policy.${COLOR_RESET}"
exit 0
