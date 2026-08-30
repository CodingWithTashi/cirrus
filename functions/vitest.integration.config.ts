import {defineConfig} from 'vitest/config';

/**
 * Handler + data-layer integration suite. Runs against the Firestore and Auth
 * emulators, which `npm run test:integration` starts via
 * `firebase emulators:exec` — that also exports FIRESTORE_EMULATOR_HOST and
 * FIREBASE_AUTH_EMULATOR_HOST, which is what points firebase-admin at them.
 *
 * Handlers are invoked through the v2 `.run()` hook rather than over HTTP, so
 * these test handler LOGIC (quota, caps, erasure) and skip the transport —
 * App Check and auth-token parsing are Google's code, not ours.
 *
 * Serial: every case shares one emulator project and clears data between
 * tests, so parallel files would race.
 */
export default defineConfig({
  test: {
    include: ['test/integration/**/*.test.ts'],
    testTimeout: 20000,
    hookTimeout: 30000,
    fileParallelism: false,
    sequence: {concurrent: false},
  },
});
