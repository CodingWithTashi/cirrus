import 'dart:math' as math;

import '../date_key.dart';
import '../models/journey_state.dart';
import '../models/models.dart';
import 'taper_engine.dart';

/// Starting a new plan on the same account: what changes, and what must not.
///
/// A plan used to be the only one an account could ever have. When it ended —
/// or stopped fitting — the app had nothing to offer but "N days past Freedom
/// Day" over a line of zero, and "Adjust my plan", which past the end re-drew
/// the curve from the original baseline over the old runway and handed a
/// person now on 80 a day a limit of 28. Seven people signed out in the 90
/// days to Nov 11 2026 and five of them made a new account to get a fresh
/// plan, one of them walking out of a subscription they had paid for.
///
/// The rule here is the brand's: **nothing ever resets.** A new plan changes
/// only what happens next. Every day already lived keeps its count and the
/// limit it was held to, so the streak, the badges, the cravings beaten and
/// the money saved read exactly as they did the moment before — which is
/// also why the baseline and the weekly spend never move: they are what the
/// past is priced against. Only the line asked for from today is new, and it
/// starts from where the person says they are now ([QuitPlan.taperFrom]).
///
/// Pure, like every engine: the store commits what this returns.
abstract final class PlanRestart {
  /// How many of the days before today have to carry puffs for an average
  /// to be offered at all. Fewer, and the screen asks instead of guessing.
  static const int minLoggedDays = 3;

  /// The window the suggestion looks back over.
  static const int windowDays = 7;

  /// Puffs a day lately: the mean of the days with puffs logged among the
  /// seven before [now], or null when fewer than [minLoggedDays] have any.
  ///
  /// Today is left out — it is not over. Zero-puff days are left out too: a
  /// clean day is not a "level" to taper from, and one in the window would
  /// drag the suggestion toward a number the person is not vaping on the
  /// days they vape. It is a starting point the person can change, never a
  /// figure shown as fact.
  static int? suggestedLevel(JourneyState s, DateTime now) {
    final today = LpDate.dayStart(now);
    final logged = <int>[
      for (var back = 1; back <= windowDays; back++)
        if (s.days[LpDate.addDays(today, -back)] case final log?
            when log.puffs > 0)
          log.puffs,
    ];
    if (logged.length < minLoggedDays) return null;
    return (logged.reduce((a, b) => a + b) / logged.length).round();
  }

  /// [s] with a new plan beginning today.
  ///
  /// [level] is where the curve starts: puffs a day right now. It is kept
  /// for cold turkey as well — the line is zero either way — so a later
  /// switch back to a taper has somewhere honest to start from.
  static JourneyState apply(
    JourneyState s, {
    required DateTime now,
    required QuitMethod method,
    required int paceDays,
    required int level,
  }) {
    final today = LpDate.dayStart(now);
    final plan = s.plan.copyWith(
      method: method,
      paceDays: paceDays,
      startDate: today,
      stretchDays: 0,
      taperFrom: math.max(1, level),
      planNumber: s.plan.planNumber + 1,
    );
    final dayOneLine = TaperEngine.limitFor(plan, 1);
    final log = s.days[today] ?? DayLog(date: today, puffs: 0, limit: 0);
    return s.copyWith(
      plan: plan,
      days: {
        ...s.days,
        // Today is the one day whose line changes, because it is the one day
        // not lived yet. But the plan is usually started in the middle of
        // it: if more is already logged than the new line allows, the line
        // holds where the person is, so the first thing a fresh start does
        // is not to call itself a slip.
        today: log.copyWith(limit: math.max(dayOneLine, log.puffs)),
      },
      // Both were about the plan being replaced.
      pendingSlipCleanDays: () => null,
      planAdvice: () => null,
    );
  }
}
