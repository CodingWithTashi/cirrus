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

  /// docs/12 §4.1, revised §5c — the SOS allowance, spent from its OWN
  /// counter.
  ///
  /// Separate for two reasons that pull in opposite directions and are both
  /// non-negotiable: nobody may be refused a call for help because they used
  /// their ordinary posts earlier, and an SOS pins to the top of the feed for
  /// an hour, so an unbounded one would be a pinning megaphone for whoever
  /// wanted it.
  ///
  /// **Three, not five** (founder decision Sep 3 2026). Five was chosen as
  /// "generous enough that no real crisis meets it", and three still is —
  /// paired with [sosPinWindow], which is the rule that actually stops the
  /// megaphone: a second SOS while yours is still pinned is not a second call
  /// for help.
  static const int sosPosts = 3;

  /// How long a live SOS pins to the top of the feed — and therefore how long
  /// before the same person may post another.
  ///
  /// One window, used three ways: `CommunityState.visible` pins by it, the
  /// composer refuses by it, and `createPost`'s `SOS_COOLDOWN_MS` enforces
  /// it. Matching the pin exactly is what lets the refusal say something true
  /// ("yours is still up there") rather than name an arbitrary number.
  static const Duration sosPinWindow = Duration(hours: 1);

  /// How many days of Stats history a free account sees.
  ///
  /// Client-only, unlike everything else here: the days are already in the
  /// user's own `journeys/{uid}` document, so this is presentation, not
  /// enforcement, and a server check would cost a read per render and buy
  /// nothing.
  ///
  /// **Seven** (founder decision Sep 3 2026, reversing the 30 that
  /// docs/12 §4.1 chose that morning). The argument for 30 was real — the
  /// taper program runs 30 days, so a 7-day window cannot show a taper
  /// working — and it is knowingly traded away: a free tier that answers the
  /// product's central question in full leaves nothing to sell, and Stats is
  /// where that question is asked. The Month pill and the forecast heatmap
  /// stay Premium alongside it.
  static const int freeHistoryDays = 7;

  /// How many health-timeline milestones a free account sees.
  ///
  /// A FLOOR, never a ceiling: `health_screen.dart` takes
  /// `max(freeHealthNodes, hereIndex + 1)`, so a node the reader has already
  /// reached is never locked however far along they are. The gate only ever
  /// hides the future — which is better than docs/01 §10's "basic milestones"
  /// and must not be regressed (docs/12 §2.4).
  ///
  /// Four is the first 24 hours (20 min, 8h, 12h, 24h) — the stretch a day-1
  /// quitter is actually living through, and the one they can reach today.
  /// Everything past it is the long arc, and the long arc is what Premium is
  /// for.
  static const int freeHealthNodes = 4;

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
