import '../../../domain/logic/journey_factory.dart';
import '../../dto/journey_codec.dart';
import '../journey_api.dart';
import 'fake_server.dart';

/// Placeholder journey backend. The server-side pieces of journey creation
/// live in [InitialJourney], shared with the real backend.
class FakeJourneyApi implements JourneyApi {
  FakeJourneyApi(this._server);

  final FakeServer _server;

  @override
  Future<Map<String, dynamic>> createJourney({
    required Map<String, dynamic> profile,
    required Map<String, dynamic> plan,
  }) => _server.respond(() {
    final journey = InitialJourney.build(
      profile: JourneyCodec.decodeProfile(profile),
      plan: JourneyCodec.decodePlan(plan),
      now: DateTime.now(),
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
