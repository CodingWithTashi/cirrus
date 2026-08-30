import {defineConfig} from 'vitest/config';

/**
 * The fast suite: pure functions only, no emulator, no network. This is what
 * `verify` (and therefore the deploy predeploy hook) runs, so it has to stay
 * quick and dependency-free.
 *
 * Emulator-backed suites live in test/rules and test/integration and run via
 * `npm run test:rules` / `npm run test:integration`.
 */
export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    exclude: ['test/rules/**', 'test/integration/**', 'node_modules/**', 'lib/**'],
  },
});
