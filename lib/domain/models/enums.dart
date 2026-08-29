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

enum SubscriptionTier { free, trial, premium }

enum PanicOutcome { survived, slipped }

/// Quick-reply chips under Ember's composer (docs/04 §3).
enum CoachChip { craving, roughDay, slipped, progress }
