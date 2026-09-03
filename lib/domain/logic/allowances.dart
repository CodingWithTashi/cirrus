/// The daily allowances, mirroring `ALLOWANCE_DEFAULTS` in
/// `functions/src/config.ts` value-for-value (docs/04 §7, docs/12 §4.1).
///
/// **These are the client's copy, and the client's copy is never authority.**
/// The server enforces every one of them and reports what it enforced —
/// `aiCoachChat` sends `messagesLeft` and the cap it applied, `createPost`
/// answers with the code its own counter produced. This file exists so the
/// app can say something true *before* the wire has spoken: grey a composer,
/// render a count, pick the right copy on a stored message that predates the
/// field. Where the two disagree, the server wins — always.
///
/// The parity is pinned on both sides with the same literals
/// (`test/domain/allowances_test.dart`, `functions/test/allowance.test.ts`).
/// Two implementations of one number drift, and this repo has the scars:
/// `streakEngine.ts` once omitted the repair-token clause `streak_engine.dart`
/// applied, so the coach quoted numbers the Home screen contradicted.
///
/// Server-side these are deploy-time params, so the founder can tune any of
/// them without a release. A client built before a change simply shows a
/// slightly stale hint until the next reply corrects it — which is exactly
/// why the client's copy may never be the thing that refuses anybody.
abstract final class LpAllowances {
  /// docs/04 §7 — the free coach allowance, per local day.
  static const int freeCoachMessages = 5;

  /// docs/04 §7 — the subscriber's fair-use ceiling. Marketing may say
  /// "unlimited"; the server enforces this (docs/08 §7 #6).
  static const int premiumCoachMessages = 100;

  /// docs/12 §4.1 — a free account's ordinary posts per local day.
  ///
  /// Posting used to be refused outright for free accounts, which left the
  /// feature we call our moat read-only for exactly the people a subscriber
  /// pays to read — while *replying* stayed free, so the line was arbitrary
  /// as well as costly.
  static const int freePosts = 1;

  /// docs/03 §9 — a subscriber's ordinary posts per local day.
  static const int premiumPosts = 3;

  /// docs/12 §4.1 — the SOS allowance, spent from its OWN counter.
  ///
  /// Separate for two reasons that pull in opposite directions and are both
  /// non-negotiable: nobody may be refused a call for help because they used
  /// their ordinary posts earlier, and an SOS pins to the top of the feed for
  /// an hour, so an unbounded one would be a pinning megaphone for whoever
  /// wanted it. Generous enough that no real crisis meets it.
  static const int sosPosts = 5;

  /// docs/12 §4.1 — how many days of Stats history a free account sees.
  ///
  /// Client-only, unlike everything else here: the days are already in the
  /// user's own `journeys/{uid}` document, so this is presentation, not
  /// enforcement, and a server check would cost a read per render and buy
  /// nothing. It was 7 — shorter than the 30-day taper program itself, so a
  /// free account could not see whether its own plan was working.
  static const int freeHistoryDays = 30;

  /// The allowance a post of this kind spends.
  ///
  /// An SOS ignores [premium] entirely: it is refused for no tier, and spends
  /// [sosPosts] from its own counter.
  static int postsForKind({required bool premium, required bool sos}) => sos
      ? sosPosts
      : premium
      ? premiumPosts
      : freePosts;
}
