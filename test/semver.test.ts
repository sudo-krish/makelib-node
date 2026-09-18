import { describe, it, expect } from 'vitest';
import {
  BRANCH_REGEX,
  validateBranchName,
  isProtectedBranch,
  getPrefixClassification,
  calculateNextVersion,
} from '../src/semver.js';

describe('Branch Naming & SemVer Engine', () => {
  describe('BRANCH_REGEX', () => {
    it('matches valid feature branches', () => {
      expect(BRANCH_REGEX.test('feat/add-login')).toBe(true);
      expect(BRANCH_REGEX.test('feature/user-profile.v2')).toBe(true);
      expect(BRANCH_REGEX.test('feat/ticket_123')).toBe(true);
    });

    it('matches valid fix and patch branches', () => {
      expect(BRANCH_REGEX.test('fix/null-pointer')).toBe(true);
      expect(BRANCH_REGEX.test('patch/security-cve')).toBe(true);
    });

    it('matches valid major and breaking branches', () => {
      expect(BRANCH_REGEX.test('major/v2-upgrade')).toBe(true);
      expect(BRANCH_REGEX.test('breaking/remove-deprecated-api')).toBe(true);
    });

    it('matches valid docs, chore, refactor, and ci branches', () => {
      expect(BRANCH_REGEX.test('docs/update-readme')).toBe(true);
      expect(BRANCH_REGEX.test('chore/bump-deps')).toBe(true);
      expect(BRANCH_REGEX.test('refactor/split-module')).toBe(true);
      expect(BRANCH_REGEX.test('ci/add-github-actions')).toBe(true);
    });

    it('rejects invalid branches', () => {
      expect(BRANCH_REGEX.test('random-branch')).toBe(false);
      expect(BRANCH_REGEX.test('feat/')).toBe(false);
      expect(BRANCH_REGEX.test('FEAT/uppercase')).toBe(false);
      expect(BRANCH_REGEX.test('feat/with spaces')).toBe(false);
      expect(BRANCH_REGEX.test('invalid/prefix')).toBe(false);
    });
  });

  describe('isProtectedBranch', () => {
    it('identifies main and master as protected', () => {
      expect(isProtectedBranch('main')).toBe(true);
      expect(isProtectedBranch('master')).toBe(true);
      expect(isProtectedBranch('  main  ')).toBe(true);
      expect(isProtectedBranch('feat/login')).toBe(false);
      expect(isProtectedBranch('develop')).toBe(false);
    });
  });

  describe('validateBranchName', () => {
    it('returns valid evaluation for compliant branches', () => {
      const res = validateBranchName('feat/add-telemetry');
      expect(res.isValid).toBe(true);
      expect(res.prefix).toBe('feat');
      expect(res.level).toBe('minor');
      expect(res.reason).toContain('backward-compatible');
    });

    it('returns error when branch is empty', () => {
      const res = validateBranchName('');
      expect(res.isValid).toBe(false);
      expect(res.error).toContain('cannot be empty');
    });

    it('blocks direct commits to protected main branch', () => {
      const res = validateBranchName('main');
      expect(res.isValid).toBe(false);
      expect(res.error).toContain('prohibited');
    });

    it('blocks direct commits to protected master branch', () => {
      const res = validateBranchName('master');
      expect(res.isValid).toBe(false);
      expect(res.error).toContain('prohibited');
    });

    it('returns error when branch fails regex', () => {
      const res = validateBranchName('my-experimental-branch');
      expect(res.isValid).toBe(false);
      expect(res.error).toContain('does not match standard regex');
    });
  });

  describe('getPrefixClassification', () => {
    it('classifies major and breaking as major', () => {
      expect(getPrefixClassification('major').level).toBe('major');
      expect(getPrefixClassification('breaking').level).toBe('major');
    });

    it('classifies feat and feature as minor', () => {
      expect(getPrefixClassification('feat').level).toBe('minor');
      expect(getPrefixClassification('feature').level).toBe('minor');
    });

    it('classifies fix, patch, docs, chore, refactor, ci as patch', () => {
      expect(getPrefixClassification('fix').level).toBe('patch');
      expect(getPrefixClassification('patch').level).toBe('patch');
      expect(getPrefixClassification('docs').level).toBe('patch');
      expect(getPrefixClassification('chore').level).toBe('patch');
      expect(getPrefixClassification('refactor').level).toBe('patch');
      expect(getPrefixClassification('ci').level).toBe('patch');
    });

    it('throws on unknown prefix', () => {
      expect(() => getPrefixClassification('unknown')).toThrow('Unrecognized branch prefix');
    });
  });

  describe('calculateNextVersion', () => {
    it('calculates major bump', () => {
      expect(calculateNextVersion('1.0.0', 'major')).toBe('2.0.0');
      expect(calculateNextVersion('1.4.9', 'major')).toBe('2.0.0');
    });

    it('calculates minor bump', () => {
      expect(calculateNextVersion('1.0.0', 'minor')).toBe('1.1.0');
      expect(calculateNextVersion('2.3.8', 'minor')).toBe('2.4.0');
    });

    it('calculates patch bump', () => {
      expect(calculateNextVersion('1.0.0', 'patch')).toBe('1.0.1');
      expect(calculateNextVersion('3.2.1', 'patch')).toBe('3.2.2');
    });

    it('throws on invalid SemVer string', () => {
      expect(() => calculateNextVersion('invalid', 'patch')).toThrow(
        'Invalid SemVer version string',
      );
      expect(() => calculateNextVersion('1.0', 'patch')).toThrow('Invalid SemVer version string');
      expect(() => calculateNextVersion('1.0.-1', 'patch')).toThrow(
        'Invalid SemVer version string',
      );
    });
  });
});
