import { describe, it, expect } from 'vitest';
import * as makelib from '../src/index.js';

describe('makelib entrypoint', () => {
  it('exports library metadata', () => {
    expect(makelib.VERSION).toBe('1.0.0');
    expect(makelib.LIBRARY_NAME).toBe('makelib-node');
  });

  it('exports core SemVer and config helpers', () => {
    expect(typeof makelib.validateBranchName).toBe('function');
    expect(typeof makelib.calculateNextVersion).toBe('function');
    expect(typeof makelib.resolveConfig).toBe('function');
    expect(typeof makelib.validateConfig).toBe('function');
  });
});
