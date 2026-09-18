/**
 * makelib-node — Centralized Make Library & Toolchain for Node.js / TypeScript
 */

export {
  BRANCH_REGEX,
  type SemVerLevel,
  type BranchEvaluation,
  isProtectedBranch,
  validateBranchName,
  getPrefixClassification,
  calculateNextVersion,
} from './semver.js';

export { type MakelibConfig, DEFAULT_CONFIG, validateConfig, resolveConfig } from './config.js';

/**
 * Library metadata
 */
export const VERSION = '1.0.0';
export const LIBRARY_NAME = 'makelib-node';
