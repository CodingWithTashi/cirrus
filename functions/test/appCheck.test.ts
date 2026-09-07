import {readdirSync, readFileSync} from 'node:fs';
import {defineBoolean} from 'firebase-functions/params';
import {describe, expect, it} from 'vitest';
import {
  ENFORCE_APP_CHECK,
  enforceAppCheck,
  enforceAppCheckFrom,
} from '../src/config';

/**
 * App Check on every callable is ONE flag, and the direction it fails.
 *
 * Sixteen callables used to carry `enforceAppCheck: true` as a literal each,
 * which meant sixteen edits to turn it off in an emergency and no way to
 * notice a seventeenth that shipped without it. Now each passes
 * `enforceAppCheck` from `config.ts`, resolved from the `ENFORCE_APP_CHECK`
 * param — and the whole reason it is a STRING param read as `!== 'false'`
 * is the last test in the first block.
 */
const KEY = 'ENFORCE_APP_CHECK';

describe('ENFORCE_APP_CHECK', () => {
  it('is the variable the .env names, and the flag is derived from it', () => {
    expect(ENFORCE_APP_CHECK.name).toBe(KEY);
    expect(enforceAppCheck).toBe(enforceAppCheckFrom(process.env[KEY]));
  });

  it('is a resolved boolean, not a param Expression', () => {
    // The SDK resolves this option eagerly with `Expression.value()`, which
    // warns three lines per callable under the CLI's discovery run
    // (`FUNCTIONS_CONTROL_API=true`) — 48 lines of "this is usually a
    // mistake" in every deploy log. See the note on `enforceAppCheck`.
    expect(typeof enforceAppCheck).toBe('boolean');
  });

  it('enforces when nothing set it', () => {
    // What a param resolves to with no `.env` loaded — the state this very
    // process is in. An unloaded config must fail CLOSED: the alternative is
    // a public Gemini proxy with no error anywhere.
    expect(enforceAppCheckFrom(undefined)).toBe(true);
    expect(enforceAppCheckFrom('')).toBe(true);
  });

  it('disarms for the exact word only', () => {
    expect(enforceAppCheckFrom('false')).toBe(false);
  });

  it('treats anything else as enforced', () => {
    for (const value of ['true', 'FALSE', 'False', '0', 'off', 'no', ' false', 'false ']) {
      expect(enforceAppCheckFrom(value), JSON.stringify(value)).toBe(true);
    }
  });

  it('would have failed OPEN as a boolean param, which is why it is not one', () => {
    // `defineBoolean` ignores its own default when the variable is unset
    // (`params/types.ts`: `process.env[name] === 'true'`): an unloaded
    // `.env`, a new project, a forgotten file, and App Check is off. Pinned
    // so that an SDK release which changes this is noticed rather than
    // silently making the string form look over-engineered.
    const probe = defineBoolean('APP_CHECK_TRAP_PROBE', {default: true});
    delete process.env['APP_CHECK_TRAP_PROBE'];
    expect(probe.value()).toBe(false);
  });
});

describe('every callable passes the flag', () => {
  const dir = 'src/handlers';
  const sources = readdirSync(dir)
    .filter((f) => f.endsWith('.ts'))
    .map((f) => [f, readFileSync(`${dir}/${f}`, 'utf8')] as const);
  const callables = sources.filter(([, s]) => /\bonCall\(/.test(s));

  it('finds the callables', () => {
    expect(callables.length).toBeGreaterThan(0);
  });

  it('never passes a literal', () => {
    // A literal `true` is the sixteen-edits problem coming back one file at
    // a time; a literal `false` is a callable the flag can no longer close.
    for (const [f, s] of sources) {
      expect(s, f).not.toMatch(/enforceAppCheck:\s*(true|false)\b/);
    }
  });

  it('passes the shared expression to every onCall, imported from config', () => {
    for (const [f, s] of callables) {
      expect(s, f).toMatch(
        /import \{[^}]*\benforceAppCheck\b[^}]*\} from '\.\.\/config'/,
      );
      // Count the option, not the import: strip every import statement
      // first, or the import line's own `enforceAppCheck,` is counted too.
      const body = s.replace(/import \{[^}]*\}[^;]*;/g, '');
      const declared = (body.match(/\bonCall\(/g) ?? []).length;
      const passed = (body.match(/\benforceAppCheck\s*[,}]/g) ?? []).length;
      expect(passed, `${f}: ${declared} onCall, ${passed} enforceAppCheck`).toBe(
        declared,
      );
    }
  });
});
