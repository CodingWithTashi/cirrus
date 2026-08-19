import '../models/journey_state.dart';
import '../models/models.dart';
import 'taper_engine.dart';

/// Server-side journey creation, shared by every backend implementation so
/// the fake and the real backend mint identical day-1 journeys: the day-1
/// log at the curve limit, the onboarding savings goal, and buddy
/// matchmaking.
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
      goals: [
        if (plan.weeklySpend > 0)
          const SavingsGoal(
            id: 'onboarding-goal',
            emoji: '✈️',
            name: 'Tokyo flight',
            price: 1300,
            fromOnboarding: true,
          ),
      ],
      earnedBadges: const {},
      buddy: const Buddy(
        alias: '@trashpanda',
        avatarEmoji: '🦝',
        name: 'Sam',
        streakDays: 19,
      ),
      day1TasksDone: const {},
    );
  }
}
