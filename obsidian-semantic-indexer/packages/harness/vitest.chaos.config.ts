import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['src/chaos/**/*.test.ts'],
    globals: true,
    environment: 'node',
    testTimeout: 30000,
    pool: 'forks',
    poolOptions: {
      forks: {
        singleFork: true
      }
    }
  }
});