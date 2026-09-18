import { describe, it, expect } from 'vitest';
import {
  DEFAULT_CONFIG,
  resolveConfig,
  validateConfig,
  type MakelibConfig,
} from '../src/config.js';

describe('Toolchain Configuration', () => {
  it('provides sensible default configuration', () => {
    expect(DEFAULT_CONFIG.srcDir).toBe('src');
    expect(DEFAULT_CONFIG.testDir).toBe('test');
    expect(DEFAULT_CONFIG.minCoverage).toBe(80);
    expect(DEFAULT_CONFIG.enforceMainBlock).toBe(true);
  });

  it('resolves configuration with partial overrides', () => {
    const config = resolveConfig({ minCoverage: 95, srcDir: 'lib' });
    expect(config.minCoverage).toBe(95);
    expect(config.srcDir).toBe('lib');
    expect(config.testDir).toBe('test');
  });

  it('validates a valid configuration', () => {
    const res = validateConfig(DEFAULT_CONFIG);
    expect(res.isValid).toBe(true);
    expect(res.errors).toHaveLength(0);
  });

  it('detects invalid configuration values', () => {
    const invalidConfig: MakelibConfig = {
      srcDir: '',
      testDir: '  ',
      minCoverage: 150,
      branchRegex: /test/,
      enforceMainBlock: true,
    };
    const res = validateConfig(invalidConfig);
    expect(res.isValid).toBe(false);
    expect(res.errors).toContain('srcDir must not be empty');
    expect(res.errors).toContain('testDir must not be empty');
    expect(res.errors).toContain('minCoverage must be a number between 0 and 100');
  });

  it('throws when resolving an invalid configuration', () => {
    expect(() => resolveConfig({ minCoverage: -5 })).toThrow('Invalid configuration');
  });
});
