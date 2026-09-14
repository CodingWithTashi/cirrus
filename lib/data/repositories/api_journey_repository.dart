import '../../domain/models/journey_state.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../api/journey_api.dart';
import '../dto/journey_codec.dart';

/// [JourneyRepository] over the wire-level [JourneyApi].
class ApiJourneyRepository implements JourneyRepository {
  const ApiJourneyRepository(this._api);

  final JourneyApi _api;

  @override
  Future<JourneyState> create({
    required UserProfile profile,
    required QuitPlan plan,
  }) async => JourneyCodec.decode(
    await _api.createJourney(
      profile: JourneyCodec.encodeProfile(profile),
      plan: JourneyCodec.encodePlan(plan),
    ),
  );

  @override
  Future<void> save(JourneyState journey) =>
      _api.saveJourney(JourneyCodec.encode(journey));

  @override
  Future<JourneyState?> fetchLatest() async {
    final json = await _api.fetchJourney();
    return json == null ? null : JourneyCodec.decode(json);
  }

  @override
  Future<void> delete() => _api.deleteJourney();
}
