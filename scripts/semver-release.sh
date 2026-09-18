#!/usr/bin/env bash
# ==============================================================================
# scripts/semver-release.sh — SemVer Release Classification Engine
# ==============================================================================
set -euo pipefail

COLOR_CYAN="\033[36m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_BOLD="\033[1m"
COLOR_RESET="\033[0m"

MODE="classify"
BRANCH_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --classify)
      MODE="classify"
      shift
      ;;
    --level)
      MODE="level"
      shift
      ;;
    --branch)
      BRANCH_ARG="$2"
      shift 2
      ;;
    *)
      BRANCH_ARG="$1"
      shift
      ;;
  esac
done

# Detect current branch if not explicitly provided
if [ -n "$BRANCH_ARG" ]; then
  CURRENT_BRANCH="$BRANCH_ARG"
else
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
fi

if [ -z "$CURRENT_BRANCH" ]; then
  echo -e "${COLOR_RED}[ERROR] Could not determine branch name.${COLOR_RESET}" >&2
  exit 1
fi

# Extract prefix before first slash
PREFIX="${CURRENT_BRANCH%%/*}"

SEMVER_LEVEL=""
SEMVER_REASON=""

case "$PREFIX" in
  major|breaking)
    SEMVER_LEVEL="major"
    SEMVER_REASON="Breaking change / incompatible API modifications"
    ;;
  feat|feature)
    SEMVER_LEVEL="minor"
    SEMVER_REASON="New backward-compatible feature"
    ;;
  fix|patch)
    SEMVER_LEVEL="patch"
    SEMVER_REASON="Bug fix or security patch"
    ;;
  docs)
    SEMVER_LEVEL="patch"
    SEMVER_REASON="Documentation updates"
    ;;
  chore|refactor|ci)
    SEMVER_LEVEL="patch"
    SEMVER_REASON="Maintenance, refactoring, or CI updates"
    ;;
  *)
    if [ "$MODE" = "level" ]; then
      echo "unknown"
    else
      echo -e "${COLOR_RED}[ERROR] Branch '${CURRENT_BRANCH}' cannot be mapped to SemVer release level.${COLOR_RESET}" >&2
      echo -e "Branch prefix '${PREFIX}' is unclassified." >&2
    fi
    exit 1
    ;;
esac

if [ "$MODE" = "level" ]; then
  echo "$SEMVER_LEVEL"
else
  echo -e "${COLOR_BOLD}${COLOR_CYAN}======================================================================${COLOR_RESET}"
  echo -e "${COLOR_BOLD}${COLOR_CYAN}                     SemVer Release Classification                    ${COLOR_RESET}"
  echo -e "${COLOR_BOLD}${COLOR_CYAN}======================================================================${COLOR_RESET}"
  echo -e "  ${COLOR_BOLD}Branch:${COLOR_RESET}        ${CURRENT_BRANCH}"
  echo -e "  ${COLOR_BOLD}Prefix:${COLOR_RESET}        ${PREFIX}"
  echo -e "  ${COLOR_BOLD}SemVer Level:${COLOR_RESET}  ${COLOR_GREEN}${COLOR_BOLD}${SEMVER_LEVEL^^}${COLOR_RESET}"
  echo -e "  ${COLOR_BOLD}Rationale:${COLOR_RESET}     ${SEMVER_REASON}"
  echo -e "${COLOR_BOLD}${COLOR_CYAN}======================================================================${COLOR_RESET}"
fi
