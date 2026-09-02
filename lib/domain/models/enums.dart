/// Core vocabulary of the quit journey. Pure Dart — no Flutter imports.
library;

enum QuitMethod { taper, coldTurkey }

enum Gender { woman, man, nonBinary }

enum QuitAttempts { never, once, twoToFive, moreThanFive }

enum VapeFrequency { daily, often, always }

enum FirstPuffWindow { withinFive, fiveToThirty, thirtyToSixty, hourPlus }

extension FirstPuffWindowHour on FirstPuffWindow {
  /// A rough local hour for the first puff of the day, used ONLY as the
  /// danger-hour fallback before three days of real data exist (docs/03 §8).
  ///
  /// The onboarding question measures time-since-waking, not a clock time, so
  /// this assumes a 07:00 wake. That assumption is wrong for plenty of people
  /// — which is exactly why it is a stopgap that real hour buckets replace as
  /// soon as they exist, rather than something the plan keeps leaning on.
  int get approximateHour => switch (this) {
    FirstPuffWindow.withinFive => 7,
    FirstPuffWindow.fiveToThirty => 7,
    FirstPuffWindow.thirtyToSixty => 8,
    FirstPuffWindow.hourPlus => 9,
  };
}

enum NicStrength {
  mg20(0.28),
  mg35(0.49),
  mg50(0.70),
  notSure(0.70);

  const NicStrength(this.mgPerPuff);

  /// Estimated absorbed mg per puff (docs/03 §2). "Not sure" defaults to 50mg.
  final double mgPerPuff;
}

enum WhyChip { health, money, freedom, family, fitness, appearance }

enum WorryChip { cravings, stress, social, failing, weight, breaks }

/// Live badge on the onboarding puffs screen (docs/02 B2).
enum DependenceLevel {
  light,
  moderate,
  heavy,
  severe;

  static DependenceLevel forPuffs(int puffsPerDay) {
    if (puffsPerDay <= 50) return light;
    if (puffsPerDay <= 150) return moderate;
    if (puffsPerDay <= 300) return heavy;
    return severe;
  }
}

/// Streak flame evolution (docs/03 §5 — must match Ember's states).
enum FlameState {
  spark(1),
  flicker(3),
  flame(7),
  blaze(14),
  inferno(30);

  const FlameState(this.minDays);

  final int minDays;

  static FlameState forStreak(int days) {
    if (days >= 30) return inferno;
    if (days >= 14) return blaze;
    if (days >= 7) return flame;
    if (days >= 3) return flicker;
    return spark;
  }

  String get emoji => switch (this) {
    spark => '✨',
    flicker => '🕯️',
    flame => '🔥',
    blaze => '🔥',
    inferno => '👑',
  };
}

enum SlipTrigger { party, stress, boredom, drinking, friends, justHappened }

enum Mood { rough, meh, okay, good, great }

enum PostTag { win, sos, day1, milestone, vent }

/// Where a post is in moderation (docs/03 §9). Encoded by `.name`, and the
/// same three words `posts/{id}.status` carries server-side.
///
/// Every post is born `pending` and only the server flips it. Other people's
/// posts reach a reader only when `live` (the rules see to that); the AUTHOR
/// sees their own post in every state, so a held post is a post that says it
/// is held rather than one that vanishes on the next launch (QA M5).
enum PostStatus {
  live,

  /// The backend has it and has not classified it yet — seconds, normally.
  /// Rendered "Posting…", never "In review": every post passes through here
  /// and the old single line made all of them look held (docs/09 issue 6).
  pending,

  /// The classifier asked for a human. Wire value on the author's mirror
  /// only; the post itself stays `pending` for the rules.
  held,
  blocked,

  /// LOCAL ONLY: the network never carried it. No backend writes this — the
  /// codec's fallback keeps an unknown wire value from becoming it — and the
  /// row it renders carries the retry.
  failed,

  /// LOCAL ONLY: the server refused it as the day's fourth post. Final, and
  /// not a rules verdict — it reads "not today", never "didn't clear the
  /// rules". Reachable only when the composer's own cap check undercounts
  /// (own posts paged out of the feed, or a second device).
  capped,
}

enum SubscriptionTier { free, trial, premium }

/// Quick-reply chips under Ember's composer (docs/04 §3).
enum CoachChip { craving, roughDay, slipped, progress }
