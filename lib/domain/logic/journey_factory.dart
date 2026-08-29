import '../models/journey_state.dart';
import '../models/models.dart';
import 'taper_engine.dart';

/// Server-side journey creation, shared by every backend implementation so the
/// fake and the real backend mint identical day-1 journeys.
///
/// A day-1 journey contains exactly what the user gave us and nothing else.
/// It used to also invent a savings goal ("Tokyo flight, $1300") and a buddy
/// ("Sam, 19-day streak") for every account — data the user never entered,
/// rendered everywhere as if they had. The Money screen showed progress toward
/// someone else's holiday, and once the coach's user card learned to read
/// goals it began quoting that holiday back to them.
///
/// "No invented numbers" is the brand rule; a fabricated goal is the same
/// failure as a fabricated stat, just wearing the user's handwriting.
abstract final class InitialJourney {
  static JourneyState build({
    required UserProfile profile,
    required QuitPlan plan,
    required DateTime now,
  }) {
    final today = JourneyState.dateKey(now);
    final day = plan.dayNumber(today).clamp(1, 9999);
    return JourneyState(
      profile: profile,
      plan: plan,
      days: {
        today: DayLog(
          date: today,
          puffs: 0,
          limit: day <= plan.totalDays ? TaperEngine.limitFor(plan, day) : 0,
        ),
      },
      cravingsSurvivedTotal: 0,
      repairTokens: 0,
      longestStreak: 0,
      goals: const [],
      earnedBadges: const {},
      day1TasksDone: const {},
    );
  }
}
