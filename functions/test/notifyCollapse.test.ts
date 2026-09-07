import {describe, expect, it} from 'vitest';
import {
  DEFAULT_COLLAPSE,
  decideNotification,
  readThreadState,
  type CollapseConfig,
  type ThreadNotifState,
} from '../src/domain/notifyCollapse';

const T0 = 1_700_000_000_000;
const cfg: CollapseConfig = DEFAULT_COLLAPSE;

/** A group that began at T0 with one reply already announced. */
function fresh(over: Partial<ThreadNotifState> = {}): ThreadNotifState {
  return {
    count: 1,
    groupStartedAtMs: T0,
    lastReplyAtMs: T0,
    lastSentAtMs: T0,
    sendsInGroup: 1,
    seenAtMs: null,
    ...over,
  };
}

describe('decideNotification', () => {
  it('sends immediately for the first reply on an unknown thread', () => {
    const d = decideNotification(null, T0, cfg);
    expect(d.send).toBe(true);
    expect(d.announceCount).toBe(1);
    expect(d.startedGroup).toBe(true);
    expect(d.next.sendsInGroup).toBe(1);
  });

  it('counts a reply inside the throttle without sending', () => {
    const d = decideNotification(fresh(), T0 + 10_000, cfg);
    expect(d.send).toBe(false);
    expect(d.announceCount).toBe(2);
    expect(d.next.count).toBe(2);
    expect(d.next.sendsInGroup).toBe(1);
  });

  it('holds the throttle window open from the last SEND, not the last reply', () => {
    // A steady drip: a reply every 40s. If an unsent reply moved the window,
    // nothing after the first would ever be announced.
    let state = fresh();
    let sent = 0;
    for (let i = 1; i <= 4; i++) {
      const d = decideNotification(state, T0 + i * 40_000, cfg);
      if (d.send) sent++;
      state = d.next;
    }
    // 40s, 80s (both inside 90s of T0), then 120s and 160s clear it.
    expect(sent).toBeGreaterThan(0);
    expect(state.lastSentAtMs).toBeGreaterThan(T0);
  });

  it('sends once the throttle lapses, announcing everything accumulated', () => {
    const state = fresh({count: 12, lastReplyAtMs: T0 + 80_000});
    const d = decideNotification(state, T0 + cfg.throttleMs, cfg);
    expect(d.send).toBe(true);
    expect(d.announceCount).toBe(13);
    expect(d.next.sendsInGroup).toBe(2);
  });

  it('caps the buzzes one group can spend', () => {
    let state = fresh({sendsInGroup: cfg.maxSendsPerGroup});
    const d = decideNotification(state, T0 + 10 * cfg.throttleMs, cfg);
    expect(d.send).toBe(false);
    // Still counted, so the next group's reset is not confused by a gap.
    expect(d.next.count).toBe(2);
    state = d.next;
    expect(state.sendsInGroup).toBe(cfg.maxSendsPerGroup);
  });

  it('starts a new group once the recipient has opened the thread', () => {
    const state = fresh({count: 9, seenAtMs: T0 + 1_000});
    const d = decideNotification(state, T0 + 2_000, cfg);
    expect(d.startedGroup).toBe(true);
    expect(d.send).toBe(true);
    // The nine they already read do not follow them into the new group.
    expect(d.announceCount).toBe(1);
    expect(d.next.seenAtMs).toBeNull();
  });

  it('ignores a seen mark from before the current group', () => {
    const state = fresh({groupStartedAtMs: T0 + 5_000, seenAtMs: T0});
    const d = decideNotification(state, T0 + 6_000, cfg);
    expect(d.startedGroup).toBe(false);
    expect(d.announceCount).toBe(2);
  });

  it('starts a new group after a long silence', () => {
    const state = fresh({count: 5, lastReplyAtMs: T0});
    const d = decideNotification(state, T0 + cfg.groupIdleMs, cfg);
    expect(d.startedGroup).toBe(true);
    expect(d.announceCount).toBe(1);
    expect(d.next.sendsInGroup).toBe(1);
  });

  it('turns twenty replies in two minutes into a handful of sends', () => {
    // The headline case. Twenty people answer one post over 120s.
    let state: ThreadNotifState | null = null;
    let sends = 0;
    let lastAnnounced = 0;
    for (let i = 0; i < 20; i++) {
      const d = decideNotification(state, T0 + i * 6_000, cfg);
      if (d.send) {
        sends++;
        lastAnnounced = d.announceCount;
      }
      state = d.next;
    }
    expect(sends).toBeLessThanOrEqual(cfg.maxSendsPerGroup);
    expect(sends).toBeGreaterThan(1);
    // Every reply is counted even when it is not announced, and the last
    // notification the reader sees tells them the true total.
    expect(state?.count).toBe(20);
    expect(lastAnnounced).toBeGreaterThan(10);
  });

  it('never announces a count below one', () => {
    const d = decideNotification(null, T0, cfg);
    expect(d.announceCount).toBeGreaterThanOrEqual(1);
  });
});

describe('readThreadState', () => {
  it('reads a row written only by syncUserContext as never-notified', () => {
    // The exact document production held for the post whose reply notified
    // nobody: `syncUserContext` creates this row with `set({seenAtMs}` merge)`
    // the moment the author opens their own thread, which is before any reply
    // can arrive. Casting it to ThreadNotifState is what broke every reply
    // push at once — see the docstring on readThreadState.
    expect(readThreadState({seenAtMs: 1_788_753_744_284})).toBeNull();
  });

  it('reads a missing document as never-notified', () => {
    expect(readThreadState(undefined)).toBeNull();
    expect(readThreadState(null)).toBeNull();
  });

  it('refuses a half-written group rather than passing undefined on', () => {
    expect(readThreadState({count: 3, groupStartedAtMs: T0})).toBeNull();
  });

  it('refuses non-numeric and non-finite fields', () => {
    expect(readThreadState({...fresh(), count: NaN})).toBeNull();
    expect(readThreadState({...fresh(), lastSentAtMs: '0'})).toBeNull();
    expect(readThreadState({...fresh(), sendsInGroup: Infinity})).toBeNull();
  });

  it('round-trips a complete group, keeping seenAtMs', () => {
    const state = fresh({seenAtMs: T0 - 1});
    expect(readThreadState({...state, kind: 'communityReply'})).toEqual(state);
  });

  it('reads an absent seenAtMs as null rather than dropping the group', () => {
    const {seenAtMs: _drop, ...withoutSeen} = fresh();
    expect(readThreadState(withoutSeen)).toEqual({...withoutSeen, seenAtMs: null});
  });
});

describe('the notifyAuthor path a partial row used to break', () => {
  /** What notifyReply does: read the row, decide, write `next` back. */
  function step(row: unknown, nowMs: number) {
    return decideNotification(readThreadState(row), nowMs, cfg);
  }

  it('sends, and writes a state Firestore will accept', () => {
    const d = step({seenAtMs: T0}, T0 + 60_000);

    expect(d.send).toBe(true);
    expect(d.announceCount).toBe(1);
    // The half that threw. The Admin SDK refuses `undefined` outright, and
    // that throw is what stopped `notifiedAt` being written and the inbox row
    // being recorded — so the failure was total AND silent.
    for (const [key, value] of Object.entries(d.next)) {
      expect(value, `${key} must be writable`).not.toBeUndefined();
      if (typeof value === 'number') {
        expect(Number.isFinite(value), `${key} must be finite`).toBe(true);
      }
    }
  });

  it('still collapses a genuine burst once the group exists', () => {
    const first = step({seenAtMs: T0}, T0 + 60_000);
    const second = step({...first.next, seenAtMs: null}, T0 + 61_000);
    expect(second.send).toBe(false);
    expect(second.announceCount).toBe(2);
  });
});
