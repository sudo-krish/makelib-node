/**
 * makelib-node — SemVer Branch Classification Engine
 *
 * Implements strict shift-left branch naming policy and branch-driven
 * SemVer release classification.
 */

export const BRANCH_REGEX =
  /^(feat|feature|fix|patch|major|breaking|docs|chore|refactor|ci)\/[a-z0-9._-]+$/;

export type SemVerLevel = 'major' | 'minor' | 'patch';

export interface BranchEvaluation {
  isValid: boolean;
  branch: string;
  prefix?: string;
  level?: SemVerLevel;
  reason?: string;
  error?: string;
}

/**
 * Checks if a branch is a protected primary branch where direct commits are forbidden.
 */
export function isProtectedBranch(branch: string): boolean {
  const normalized = branch.trim();
  return normalized === 'main' || normalized === 'master';
}

/**
 * Validates a branch name against the shift-left naming standard.
 */
export function validateBranchName(branch: string): BranchEvaluation {
  const normalized = branch.trim();

  if (!normalized) {
    return {
      isValid: false,
      branch: normalized,
      error: 'Branch name cannot be empty.',
    };
  }

  if (isProtectedBranch(normalized)) {
    return {
      isValid: false,
      branch: normalized,
      error: `Direct commits to protected branch '${normalized}' are prohibited.`,
    };
  }

  if (!BRANCH_REGEX.test(normalized)) {
    return {
      isValid: false,
      branch: normalized,
      error: `Branch '${normalized}' does not match standard regex ${BRANCH_REGEX.source}`,
    };
  }

  const prefix = normalized.split('/')[0]!;
  const classification = getPrefixClassification(prefix);

  return {
    isValid: true,
    branch: normalized,
    prefix,
    level: classification.level,
    reason: classification.reason,
  };
}

/**
 * Maps a branch prefix to SemVer bump level.
 */
export function getPrefixClassification(prefix: string): {
  level: SemVerLevel;
  reason: string;
} {
  switch (prefix) {
    case 'major':
    case 'breaking':
      return {
        level: 'major',
        reason: 'Breaking API changes or incompatible alterations',
      };
    case 'feat':
    case 'feature':
      return {
        level: 'minor',
        reason: 'New backward-compatible functionality',
      };
    case 'fix':
    case 'patch':
      return {
        level: 'patch',
        reason: 'Bug fix or vulnerability patch',
      };
    case 'docs':
      return {
        level: 'patch',
        reason: 'Documentation updates',
      };
    case 'chore':
    case 'refactor':
    case 'ci':
      return {
        level: 'patch',
        reason: 'Internal refactoring, maintenance, or CI workflow changes',
      };
    default:
      throw new Error(`Unrecognized branch prefix: '${prefix}'`);
  }
}

/**
 * Calculates the next version string following SemVer specification.
 */
export function calculateNextVersion(currentVersion: string, level: SemVerLevel): string {
  const parts = currentVersion.split('.').map(Number);
  if (parts.length !== 3 || parts.some(n => isNaN(n) || n < 0)) {
    throw new Error(`Invalid SemVer version string: '${currentVersion}'`);
  }

  const [major = 0, minor = 0, patch = 0] = parts;

  switch (level) {
    case 'major':
      return `${major + 1}.0.0`;
    case 'minor':
      return `${major}.${minor + 1}.0`;
    case 'patch':
      return `${major}.${minor}.${patch + 1}`;
  }
}
