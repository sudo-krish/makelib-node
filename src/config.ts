/**
 * makelib-node — Toolchain & Pipeline Configuration
 */

import { BRANCH_REGEX } from './semver.js';

export interface MakelibConfig {
  srcDir: string;
  testDir: string;
  minCoverage: number;
  branchRegex: RegExp;
  enforceMainBlock: boolean;
}

export const DEFAULT_CONFIG: MakelibConfig = {
  srcDir: 'src',
  testDir: 'test',
  minCoverage: 80,
  branchRegex: BRANCH_REGEX,
  enforceMainBlock: true,
};

/**
 * Validates a MakelibConfig instance.
 */
export function validateConfig(config: MakelibConfig): {
  isValid: boolean;
  errors: string[];
} {
  const errors: string[] = [];

  if (!config.srcDir || config.srcDir.trim() === '') {
    errors.push('srcDir must not be empty');
  }

  if (!config.testDir || config.testDir.trim() === '') {
    errors.push('testDir must not be empty');
  }

  if (
    typeof config.minCoverage !== 'number' ||
    config.minCoverage < 0 ||
    config.minCoverage > 100
  ) {
    errors.push('minCoverage must be a number between 0 and 100');
  }

  return {
    isValid: errors.length === 0,
    errors,
  };
}

/**
 * Merges user overrides with default configuration.
 */
export function resolveConfig(overrides?: Partial<MakelibConfig>): MakelibConfig {
  const merged: MakelibConfig = {
    ...DEFAULT_CONFIG,
    ...overrides,
  };

  const validation = validateConfig(merged);
  if (!validation.isValid) {
    throw new Error(`Invalid configuration: ${validation.errors.join(', ')}`);
  }

  return merged;
}
