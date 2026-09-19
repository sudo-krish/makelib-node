#!/usr/bin/env bash
# ==============================================================================
# scripts/semver-release.sh — SemVer Release Classification & Version Engine
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
EXPLICIT_LEVEL=""
APPLY_VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --classify)
      MODE="classify"
      shift
      ;;
    --level)
      if [[ $# -gt 1 && ! "$2" =~ ^-- ]]; then
        EXPLICIT_LEVEL="$2"
        shift 2
      else
        MODE="level"
        shift
      fi
      ;;
    --branch)
      BRANCH_ARG="$2"
      shift 2
      ;;
    --next-version)
      MODE="next-version"
      shift
      ;;
    --current-version)
      MODE="current-version"
      shift
      ;;
    --bump)
      MODE="bump"
      shift
      ;;
    --apply)
      MODE="apply"
      APPLY_VERSION="$2"
      shift 2
      ;;
    *)
      BRANCH_ARG="$1"
      shift
      ;;
  esac
done

# ------------------------------------------------------------------------------
# Branch Detection & Prefix Classification
# ------------------------------------------------------------------------------
detect_branch_and_level() {
  if [ -n "$EXPLICIT_LEVEL" ]; then
    SEMVER_LEVEL="$EXPLICIT_LEVEL"
    CURRENT_BRANCH="manual override"
    PREFIX="manual"
    SEMVER_REASON="Explicitly specified bump level"
    return 0
  fi

  if [ -n "$BRANCH_ARG" ]; then
    CURRENT_BRANCH="$BRANCH_ARG"
  else
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  fi

  if [ -z "$CURRENT_BRANCH" ]; then
    CURRENT_BRANCH="main"
  fi

  if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
    COMMIT_MSG=$(git log -1 --pretty=%B 2>/dev/null || echo "")
    if [[ "$COMMIT_MSG" =~ (major|breaking|feat|feature|fix|patch|docs|chore|refactor|ci)/ ]]; then
      PREFIX="${BASH_REMATCH[1]}"
      CURRENT_BRANCH="merged PR (${PREFIX}/*)"
    else
      PREFIX="patch"
    fi
  else
    PREFIX="${CURRENT_BRANCH%%/*}"
  fi

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
      SEMVER_LEVEL="patch"
      SEMVER_REASON="Default fallback patch bump"
      ;;
  esac
}

# ------------------------------------------------------------------------------
# Highest Existing Version Detection (Git Tags + package.json)
# ------------------------------------------------------------------------------
get_highest_version() {
  local maj=0 min=0 pat=0
  local found=false

  # 1. Scan git tags matching vX.Y.Z
  local tags
  tags=$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null || true)
  for t in $tags; do
    local v="${t#v}"
    v="${v%%-*}"
    v="${v%%+*}"
    if [[ "$v" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
      local t_maj="${BASH_REMATCH[1]}"
      local t_min="${BASH_REMATCH[2]}"
      local t_pat="${BASH_REMATCH[3]}"
      if (( t_maj > maj )) || \
         (( t_maj == maj && t_min > min )) || \
         (( t_maj == maj && t_min == min && t_pat > pat )); then
        maj=$t_maj; min=$t_min; pat=$t_pat
        found=true
      fi
    fi
  done

  # 2. Compare against package.json version if present
  if [ -f "package.json" ]; then
    local pkg_v=""
    if command -v node >/dev/null 2>&1; then
      pkg_v=$(node -p "require('./package.json').version" 2>/dev/null || echo "")
    else
      pkg_v=$(grep -oE '"version"\s*:\s*"[^"]+"' package.json | head -n 1 | cut -d'"' -f4 || echo "")
    fi

    if [[ "$pkg_v" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
      local p_maj="${BASH_REMATCH[1]}"
      local p_min="${BASH_REMATCH[2]}"
      local p_pat="${BASH_REMATCH[3]}"
      if (( p_maj > maj )) || \
         (( p_maj == maj && p_min > min )) || \
         (( p_maj == maj && p_min == min && p_pat > pat )); then
        maj=$p_maj; min=$p_min; pat=$p_pat
        found=true
      fi
    fi
  fi

  if [ "$found" = true ]; then
    echo "$maj.$min.$pat"
  else
    echo "0.0.0"
  fi
}

# ------------------------------------------------------------------------------
# Calculate Next Guaranteed Unique SemVer Version
# ------------------------------------------------------------------------------
calculate_next_version() {
  local base_ver="$1"
  local level="$2"

  if [[ ! "$base_ver" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    base_ver="0.0.0"
  fi

  local maj="${BASH_REMATCH[1]}"
  local min="${BASH_REMATCH[2]}"
  local pat="${BASH_REMATCH[3]}"

  # If repo has no releases yet (0.0.0), default initial release to 0.1.0 or 1.0.0
  if [ "$maj" -eq 0 ] && [ "$min" -eq 0 ] && [ "$pat" -eq 0 ]; then
    case "$level" in
      major) echo "1.0.0" ;;
      minor) echo "0.1.0" ;;
      patch|*) echo "0.0.1" ;;
    esac
    return 0
  fi

  case "$level" in
    major)
      maj=$((maj + 1))
      min=0
      pat=0
      ;;
    minor)
      min=$((min + 1))
      pat=0
      ;;
    patch|*)
      pat=$((pat + 1))
      ;;
  esac

  local candidate="$maj.$min.$pat"

  # Collision prevention: ensure tag does not already exist in git
  while git rev-parse -q --verify "refs/tags/v$candidate" >/dev/null 2>&1; do
    pat=$((pat + 1))
    candidate="$maj.$min.$pat"
  done

  echo "$candidate"
}

# ------------------------------------------------------------------------------
# Apply Version Update
# ------------------------------------------------------------------------------
apply_version_to_files() {
  local new_ver="$1"

  if [ -f "package.json" ]; then
    if command -v node >/dev/null 2>&1; then
      node -e '
        const fs = require("fs");
        try {
          const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
          pkg.version = process.argv[1];
          fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");
        } catch (e) {}
      ' "$new_ver"
    else
      sed -i -E "s/(\"version\"\s*:\s*\")[^\"]+(\")/\1$new_ver\2/" package.json
    fi

    # Update package-lock.json if npm is available
    if [ -f "package-lock.json" ] && command -v npm >/dev/null 2>&1; then
      npm version "$new_ver" --no-git-tag-version --allow-same-version >/dev/null 2>&1 || true
    fi
  fi
}

# ------------------------------------------------------------------------------
# Dispatch Execution Modes
# ------------------------------------------------------------------------------
case "$MODE" in
  classify)
    detect_branch_and_level
    echo -e "${COLOR_BOLD}${COLOR_CYAN}======================================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}                     SemVer Release Classification                    ${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}======================================================================${COLOR_RESET}"
    echo -e "  ${COLOR_BOLD}Branch:${COLOR_RESET}        ${CURRENT_BRANCH}"
    echo -e "  ${COLOR_BOLD}Prefix:${COLOR_RESET}        ${PREFIX}"
    echo -e "  ${COLOR_BOLD}SemVer Level:${COLOR_RESET}  ${COLOR_GREEN}${COLOR_BOLD}${SEMVER_LEVEL^^}${COLOR_RESET}"
    echo -e "  ${COLOR_BOLD}Rationale:${COLOR_RESET}     ${SEMVER_REASON}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}======================================================================${COLOR_RESET}"
    ;;

  level)
    detect_branch_and_level
    echo "$SEMVER_LEVEL"
    ;;

  current-version)
    get_highest_version
    ;;

  next-version)
    detect_branch_and_level
    CURRENT_V=$(get_highest_version)
    calculate_next_version "$CURRENT_V" "$SEMVER_LEVEL"
    ;;

  bump)
    detect_branch_and_level
    CURRENT_V=$(get_highest_version)
    NEXT_V=$(calculate_next_version "$CURRENT_V" "$SEMVER_LEVEL")
    apply_version_to_files "$NEXT_V"
    echo "$NEXT_V"
    ;;

  apply)
    if [ -z "$APPLY_VERSION" ]; then
      echo -e "${COLOR_RED}[ERROR] --apply requires a version argument.${COLOR_RESET}" >&2
      exit 1
    fi
    apply_version_to_files "$APPLY_VERSION"
    echo "$APPLY_VERSION"
    ;;
esac
