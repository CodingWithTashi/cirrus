import {readFileSync} from 'node:fs';
import {describe, expect, it} from 'vitest';

/**
 * What one push costs in reads.
 *
 * `users/{uid}` used to be read THREE times to send one notification: the
 * preference gate, the locale for localized copy, and again beside the device
 * subcollection — one document whose contents cannot change in between. This
 * is the hottest path in the feature and the one that scales with traffic, so
 * the shape is pinned rather than trusted.
 *
 * Asserted against the source rather than by counting reads at runtime: the
 * Admin SDK offers no read counter, and wrapping it to build one would mostly
 * test the wrapper. What actually regresses is somebody adding a `.get()`
 * back, and that is visible here.
 */
describe('the send path', () => {
  const push = readFileSync('src/lib/push.ts', 'utf8');

  /** The body of a function, with comments stripped. */
  function bodyOf(signature: string): string {
    const start = push.indexOf(signature);
    expect(start, `${signature} is gone or was renamed`).toBeGreaterThan(-1);
    const end = push.indexOf('\n}', start);
    return push
      .slice(start, end)
      .replace(/\/\*\*[\s\S]*?\*\//g, '')
      .replace(/^\s*\/\/.*$/gm, '');
  }

  it('reads the user document exactly once, inside the gate', () => {
    const body = bodyOf('export async function sendToUser(');
    expect(body).not.toContain('userDoc(');
    expect(body).toContain('openGate(');
    // The gate's read is threaded onward rather than repeated.
    expect(body).toContain('collectTokens(uid, gate.legacy)');
  });

  it('resolves localized copy without a read of its own', () => {
    const body = bodyOf('export async function sendLocalized(');
    expect(body).not.toContain('.get()');
    expect(body).not.toContain('userDoc(');
    // The locale arrives through the payload factory instead.
    expect(body).toContain('(locale)');
  });

  it('keeps the device lookup to the subcollection alone', () => {
    const body = bodyOf('async function collectTokens(');
    expect(body).toContain('devicesCol(uid).get()');
    expect(body).not.toContain('userDoc(');
  });

  it('writes the inbox row before the token check', () => {
    // Somebody with no device registered still gets the in-app record; the
    // push is the courtesy, the inbox is the fact.
    const body = bodyOf('export async function sendToUser(');
    expect(body.indexOf('recordNotification(')).toBeLessThan(
      body.indexOf('collectTokens('),
    );
  });
});
