import {afterEach, describe, expect, it, vi} from 'vitest';
import {
  ALLOWANCE_DEFAULTS,
  ENTITLEMENT_MODE,
  allowance,
  readAllowance,
} from '../src/config';
import {ungated} from '../src/lib/usage';

/**
 * The guard between a missing config value and a silent product outage.
 *
 * A deploy-time param resolves to **0** when nothing supplies a value — no
 * `.env` for the active project, a typo'd key, a process that never loaded
 * one. Zero is not a small allowance. A coach limit of 0 answers every user
 * `capReached` before the model is called; a post limit of 0 refuses every
 * post in the app. Both look like a deliberate policy in the logs, which is
 * exactly why the first one took a while to find.
 *
 * This project has already shipped that class of bug twice — `gemini-3.1-flash`
 * (a model id that did not exist, failing silently) and the coach `limit` of 0
 * in the integration suite. The rule that came out of it: a config value that
 * cannot be right must not be believed.
 */
describe('allowance', () => {
  const param = (value: number) => ({value: () => value});

  it('takes a usable configured value', () => {
    expect(allowance(param(5), 99)).toBe(5);
    expect(allowance(param(1), 99)).toBe(1);
    expect(allowance(param(100), 99)).toBe(100);
  });

  it('refuses to believe an unresolved param', () => {
    // The whole point. 0 is what a param resolves to when nothing set it.
    expect(allowance(param(0), 3)).toBe(3);
  });

  it('refuses a negative or non-finite value', () => {
    expect(allowance(param(-1), 3)).toBe(3);
    expect(allowance(param(Number.NaN), 3)).toBe(3);
    expect(allowance(param(Number.POSITIVE_INFINITY), 3)).toBe(3);
  });

  it('floors a fractional value rather than passing it to a counter', () => {
    // `used >= limit` with a fractional limit is a comparison nobody intended
    // to write; 2.5 means two.
    expect(allowance(param(2.5), 3)).toBe(2);
  });

  it('every default is itself usable', () => {
    // A fallback of 0 would defeat the guard entirely — it would degrade an
    // outage into the same outage.
    for (const [name, value] of Object.entries(ALLOWANCE_DEFAULTS)) {
      expect(value, name).toBeGreaterThan(0);
      expect(Number.isInteger(value), name).toBe(true);
    }
  });

  it('the documented allowances match docs/04 §7 and docs/12 §4.1', () => {
    // These are quoted in user-facing copy (`coachCapReached` renders the
    // limit the server sends) and mirrored by `CoachStore` on the client, so
    // a change here is a change in two other places.
    expect(ALLOWANCE_DEFAULTS).toEqual({
      freeCoachMessages: 5,
      premiumCoachMessages: 100,
      freePosts: 1,
      premiumPosts: 3,
      sosPosts: 5,
    });
  });

  it('a free account is never given more than a subscriber', () => {
    // The refusal code branches on `premiumLimit > limit`; if these ever
    // inverted, a free user would be offered a door to a smaller allowance.
    expect(ALLOWANCE_DEFAULTS.freePosts).toBeLessThan(
      ALLOWANCE_DEFAULTS.premiumPosts,
    );
    expect(ALLOWANCE_DEFAULTS.freeCoachMessages).toBeLessThan(
      ALLOWANCE_DEFAULTS.premiumCoachMessages,
    );
  });
});

describe('readAllowance', () => {
  it('has exactly one reader per documented allowance', () => {
    // The readers are what every call site goes through, so an allowance
    // added to ALLOWANCE_DEFAULTS without one would be read with a hand-paired
    // fallback again — the drift this whole structure exists to prevent.
    expect(Object.keys(readAllowance).sort()).toEqual(
      Object.keys(ALLOWANCE_DEFAULTS).sort(),
    );
  });

  it('falls back to its OWN default, never to a neighbouring one', () => {
    // Params resolve to 0 with no .env loaded — which is precisely the state
    // this test process is in, so every reader takes its fallback path here.
    // A mispaired reader would return some other allowance's number.
    for (const [name, expected] of Object.entries(ALLOWANCE_DEFAULTS)) {
      const read = readAllowance[name as keyof typeof readAllowance];
      expect(read(), name).toBe(expected);
    }
  });
});

/**
 * The same lesson, pointing the other way.
 *
 * `allowance()` exists because an unset param resolves to 0 and 0 fails
 * toward "refuse everybody". `ENTITLEMENT_MODE` has the opposite hazard: its
 * default used to be `ungated`, which fails toward *giving the product away*.
 * An unloaded `.env`, a new project, a deploy bound to the wrong config, and
 * every caller is silently premium — no error, no log, no refusal, and no
 * revenue. That was the live state of production from Aug 29 to Sep 3 2026.
 *
 * A default is a decision about what happens when nobody decided. This one
 * has to be the safe direction.
 */
describe('ENTITLEMENT_MODE', () => {
  const as = (value: string) => {
    vi.spyOn(ENTITLEMENT_MODE, 'value').mockReturnValue(value);
    return ungated();
  };

  afterEach(() => vi.restoreAllMocks());

  it('opens the gates only for the exact word', () => {
    expect(as('ungated')).toBe(true);
  });

  it('treats an unresolved param as gated, not as free-for-all', () => {
    // What a param actually resolves to when nothing supplies a value —
    // no `.env` for the active project, a deploy bound to the wrong config.
    // The comparison is against the exact string, so empty falls through to
    // the mirror rather than to "everybody is premium".
    expect(as('')).toBe(false);
  });

  it('treats anything it does not recognise as gated', () => {
    for (const value of ['mirror', 'MIRROR', 'Ungated', 'ungated ', 'true', 'off']) {
      expect(as(value), value).toBe(false);
    }
  });
});
