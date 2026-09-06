/**
 * When a reply on a busy thread is worth another buzz.
 *
 * Twenty people answering one post must not be twenty notifications. Two
 * mechanisms together make that true, and only one of them lives here:
 *
 * * **On the phone**, every send for a thread carries the same notification
 *   tag, so a later one REPLACES the shade line rather than adding to it.
 *   That guarantees one visible row no matter what this function decides.
 * * **Here**, a throttle decides how often to send at all. The tag alone is
 *   not enough, because replacing a notification still re-alerts: the phone
 *   would show one line and buzz twenty times.
 *
 * Pure on purpose — no Firestore, no clock, no config module — because the
 * interesting cases are all about time and ordering and are miserable to
 * provoke against an emulator. The handler's whole job is to read the state,
 * call this, and write back `next`.
 *
 * ## It must run inside a transaction
 *
 * Two replies 800ms apart spawn two concurrent function instances. Read the
 * state outside a transaction and both see the same `lastSentAtMs`, both find
 * the throttle lapsed, and both send — reproducing the exact burst the
 * throttle exists to prevent, and losing one of the two increments besides.
 * `reportReply.ts` carries the same warning about its report counter.
 */

/** What we remember about one recipient's unread activity on one thread. */
export interface ThreadNotifState {
  /** Replies since this group began. Includes ones never announced. */
  readonly count: number;
  readonly groupStartedAtMs: number;
  /** Most recent reply, whether or not it was announced. Drives idle reset. */
  readonly lastReplyAtMs: number;
  /** Most recent send. Drives the throttle. 0 when nothing has been sent. */
  readonly lastSentAtMs: number;
  /** The number this group has announced so far, for the cap. */
  readonly sendsInGroup: number;
  /** When the recipient last opened the thread, or null. */
  readonly seenAtMs: number | null;
}

export interface CollapseConfig {
  /** Quiet period after a send before another may go out. */
  readonly throttleMs: number;
  /** Hard ceiling on buzzes for one group, however long it runs. */
  readonly maxSendsPerGroup: number;
  /** Silence after which the next reply starts a fresh group. */
  readonly groupIdleMs: number;
}

export const DEFAULT_COLLAPSE: CollapseConfig = {
  // Short on purpose. A long throttle looks tidier and is worse: a burst of
  // twenty replies inside one window would send once, saying "1 new reply",
  // and the reader would never learn the other nineteen arrived. At 90s a
  // burst costs two or three buzzes and ends on an accurate number.
  throttleMs: 90_000,
  maxSendsPerGroup: 4,
  groupIdleMs: 6 * 60 * 60 * 1000,
};

export interface CollapseDecision {
  readonly send: boolean;
  /** The number to render, when sending. Always ≥ 1. */
  readonly announceCount: number;
  /** True when this reply began a new group rather than joining one. */
  readonly startedGroup: boolean;
  /** The state to persist. */
  readonly next: ThreadNotifState;
}

/**
 * Whether [state] is stale enough that the next reply starts over.
 *
 * Two independent reasons, and both matter. The recipient having opened the
 * thread is the honest one — they have seen everything, so the next reply is
 * genuinely the first of something new. The idle timeout is the fallback for
 * somebody who never opened it: without it a thread that wakes up a week
 * later would still be counting against a cap spent seven days ago.
 */
function shouldReset(
  state: ThreadNotifState,
  nowMs: number,
  cfg: CollapseConfig,
): boolean {
  if (state.seenAtMs !== null && state.seenAtMs >= state.groupStartedAtMs) {
    return true;
  }
  return nowMs - state.lastReplyAtMs >= cfg.groupIdleMs;
}

/**
 * Whether this reply earns a notification, and what the state becomes.
 *
 * A null [state] is a thread this recipient has never been notified about.
 */
export function decideNotification(
  state: ThreadNotifState | null,
  nowMs: number,
  cfg: CollapseConfig = DEFAULT_COLLAPSE,
): CollapseDecision {
  if (state === null || shouldReset(state, nowMs, cfg)) {
    // The first reply of a group always sends, immediately. Somebody just
    // answered this person; making them wait out a throttle for the one
    // notification that carries real news is the wrong trade in every case.
    return {
      send: true,
      announceCount: 1,
      startedGroup: true,
      next: {
        count: 1,
        groupStartedAtMs: nowMs,
        lastReplyAtMs: nowMs,
        lastSentAtMs: nowMs,
        sendsInGroup: 1,
        seenAtMs: null,
      },
    };
  }

  const count = state.count + 1;
  const throttleLapsed = nowMs - state.lastSentAtMs >= cfg.throttleMs;
  const underCap = state.sendsInGroup < cfg.maxSendsPerGroup;
  const send = throttleLapsed && underCap;

  return {
    send,
    announceCount: count,
    startedGroup: false,
    next: {
      count,
      groupStartedAtMs: state.groupStartedAtMs,
      lastReplyAtMs: nowMs,
      // Unsent replies must not move the throttle window, or a steady drip
      // of replies would hold it open forever and nothing after the first
      // would ever be announced.
      lastSentAtMs: send ? nowMs : state.lastSentAtMs,
      sendsInGroup: send ? state.sendsInGroup + 1 : state.sendsInGroup,
      seenAtMs: state.seenAtMs,
    },
  };
}
