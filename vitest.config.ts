import { defineConfig } from 'vitest/config';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const coverageModule = require.resolve('@vitest/coverage-v8');

export default defineConfig({
  resolve: {
    alias: {
      '@vitest/coverage-v8': coverageModule,
    },
  },
  test: {
    globals: true,
    environment: 'node',
    include: ['test/**/*.test.ts'],
    coverage: {
      provider: 'custom',
      customProviderModule: coverageModule,
      reporter: ['text', 'json', 'html'],
      include: ['src/**/*.ts'],
      exclude: ['src/**/*.d.ts'],
      thresholds: {
        lines: process.env.MIN_COVERAGE ? Number(process.env.MIN_COVERAGE) : 80,
        functions: 80,
        branches: 80,
        statements: 80,
      },
    },
  },
});
