import '../../../domain/logic/taper_engine.dart';
import '../../../domain/models/journey_state.dart';
import '../../../domain/models/models.dart';
import '../../dto/journey_codec.dart';
import '../journey_api.dart';
import 'fake_server.dart';

/// Placeholder journey backend. Owns the server-side pieces of journey
/// creation: the day-1 log at the curve limit, the onboarding savings goal,
/// and buddy matchmaking.
class FakeJourneyApi implements JourneyApi {
  FakeJourneyApi(this._server);

  final FakeServer _server;

  @override
  Future<Map<String, dynamic>> createJourney({
    required Map<String, dynamic> profile,
    required Map<String, dynamic> plan,
  }) => _server.respond(() {
    final decodedPlan = JourneyCodec.decodePlan(plan);
    final today = JourneyState.dateKey(DateTime.now());
    final day = decodedPlan.dayNumber(today).clamp(1, 9999);
    final journey = JourneyState(
      profile: JourneyCodec.decodeProfile(profile),
      plan: decodedPlan,
      days: {
        today: DayLog(
          date: today,
          puffs: 0,
          limit: day <= decodedPlan.totalDays
              ? TaperEngine.limitFor(decodedPlan, day)
              : 0,
        ),
      },
      cravingsSurvivedTotal: 0,
      repairTokens: 0,
      longestStreak: 0,
      goals: [
        if (decodedPlan.weeklySpend > 0)
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
    final json = JourneyCodec.encode(journey);
    _server.putJourney(json);
    return json;
  });

  @override
  Future<void> saveJourney(Map<String, dynamic> journey) =>
      _server.respond(() => _server.putJourney(journey));

  @override
  Future<void> deleteJourney() => _server.respond(_server.deleteJourney);
}
