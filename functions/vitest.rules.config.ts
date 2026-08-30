import {defineConfig} from 'vitest/config';

/**
 * Security-rules suite. Requires the Firestore emulator, which
 * `npm run test:rules` starts via `firebase emulators:exec`.
 *
 * Single-threaded on purpose: every test shares one emulator project and
 * clears Firestore between cases, so parallel files would race each other.
 */
export default defineConfig({
  test: {
    include: ['test/rules/**/*.test.ts'],
    testTimeout: 20000,
    hookTimeout: 30000,
    fileParallelism: false,
  },
});
