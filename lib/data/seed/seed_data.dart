import '../../domain/logic/taper_engine.dart';
import '../../domain/date_key.dart';
import '../../domain/models/journey_state.dart';
import '../../domain/models/models.dart';

/// Demo account used by "Sign in" (a returning user restoring their journey):
/// Maya / @quietfox, day 12 of a 30-day taper off 200 puffs/day — the same
/// journey every design frame depicts. All derived numbers (money, streak,
/// nicotine) come from the real engines, never hardcoded.
abstract final class SeedData {
  static JourneyState journey(DateTime now) {
    final today = JourneyState.dateKey(now);
    final start = LpDate.addDays(today, -11);

    final plan = QuitPlan(
      method: QuitMethod.taper,
      paceDays: 30,
      startDate: start,
      baselinePuffsPerDay: 200,
      weeklySpend: 45,
      strength: NicStrength.mg50,
    );

    // Actuals for completed days 1..11 — every day at-or-under its curve
    // limit so the seeded streak really is 12 (day 7 is the hard-but-held
    // Thursday: 133 against a line of 134).
    const actuals = [188, 179, 169, 160, 150, 141, 133, 126, 115, 104, 96];
    const cravingsPerDay = [1, 2, 2, 3, 2, 2, 3, 2, 2, 2, 1];
    const moods = [
      Mood.rough,
      null,
      Mood.meh,
      null,
      Mood.okay,
      null,
      Mood.rough,
      Mood.okay,
      null,
      Mood.good,
      Mood.good,
    ];

    final days = <DateTime, DayLog>{};
    for (var i = 0; i < actuals.length; i++) {
      final date = LpDate.addDays(start, i);
      final d = i + 1;
      days[date] = DayLog(
        date: date,
        puffs: actuals[i],
        limit: TaperEngine.limitFor(plan, d),
        hourBuckets: _spreadOverDay(actuals[i]),
        cravingsSurvived: cravingsPerDay[i],
        mood: moods[i],
        // Day 6 is the week view's hardest bar — its note becomes the
        // "difficult day — party night" caption (design frame 38).
        moodNote: d == 6
            ? 'party night'
            : d == 7
            ? 'work party tonight, nervous'
            : null,
      );
    }

    // Today (day 12): 52 puffs so far, tracking well under the line.
    final todayPuffs = 52;
    days[today] = DayLog(
      date: today,
      puffs: todayPuffs,
      limit: TaperEngine.limitFor(plan, 12),
      hourBuckets: _spreadOverDay(todayPuffs, morningOnly: true),
      cravingsSurvived: 1,
    );

    return JourneyState(
      profile: const UserProfile(
        alias: '@quietfox',
        avatarEmoji: '🦊',
        tier: SubscriptionTier.premium,
        email: 'maya@quitmail.com',
        gender: Gender.woman,
        birthYear: 2003,
        whys: {WhyChip.health, WhyChip.money, WhyChip.fitness},
        worries: {WorryChip.cravings, WorryChip.stress, WorryChip.failing},
        attempts: QuitAttempts.twoToFive,
        frequency: VapeFrequency.always,
        firstPuff: FirstPuffWindow.withinFive,
      ),
      plan: plan,
      days: days,
      cravingsSurvivedTotal: 23,
      repairTokens: 1,
      longestStreak: 12,
      goals: const [
        SavingsGoal(id: 'g1', emoji: '👟', name: 'New kicks', price: 120),
        SavingsGoal(
          id: 'g2',
          emoji: '✈️',
          name: 'Tokyo flight',
          price: 1300,
          fromOnboarding: true,
        ),
      ],
      earnedBadges: const {
        'firstLog',
        'firstCraving',
        'spark',
        'weekFlame',
        'cleanWeekend',
        'helpedSos',
        'tenCravings',
      },
      lastPuffAt: now.subtract(const Duration(minutes: 38)),
      day1TasksDone: const {0, 1, 2},
      moodCheckIns: 4,
    );
  }

  /// Distributes a day's puffs over realistic hour buckets with the
  /// evening-heavy pattern the danger-hour engine should discover (9–11 p.m.).
  static Map<int, int> _spreadOverDay(int total, {bool morningOnly = false}) {
    const weights = <int, int>{
      7: 2,
      8: 3,
      9: 2,
      10: 2,
      11: 2,
      12: 3,
      13: 2,
      14: 2,
      15: 3,
      16: 2,
      17: 2,
      18: 3,
      19: 3,
      20: 4,
      21: 6,
      22: 7,
      23: 3,
    };
    final hours = morningOnly
        ? {
            for (final e in weights.entries.where((e) => e.key <= 14))
              e.key: e.value,
          }
        : weights;
    final weightSum = hours.values.fold(0, (a, b) => a + b);
    final result = <int, int>{};
    var assigned = 0;
    for (final e in hours.entries) {
      final share = (total * e.value / weightSum).floor();
      if (share > 0) result[e.key] = share;
      assigned += share;
    }
    var remainder = total - assigned;
    for (final h in [22, 21, 20, 12]) {
      if (remainder <= 0) break;
      if (hours.containsKey(h)) {
        result[h] = (result[h] ?? 0) + 1;
        remainder--;
      }
    }
    if (remainder > 0) {
      result[hours.keys.first] = (result[hours.keys.first] ?? 0) + remainder;
    }
    return result;
  }
}
