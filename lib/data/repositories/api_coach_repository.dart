import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../api/coach_api.dart';
import '../dto/coach_codec.dart';

/// [CoachRepository] over the wire-level [CoachApi].
class ApiCoachRepository implements CoachRepository {
  const ApiCoachRepository(this._api);

  final CoachApi _api;

  /// The demo backend's replies are scripted, so there is nothing to stream:
  /// one chunk, then done. Deliberately NOT drip-fed word by word — a fake
  /// typing effect over an instantly-known string is theatre, and this app's
  /// rule is that nothing pretends to be more alive than it is.
  @override
  Stream<CoachEvent> streamReply({
    String? text,
    CoachChip? chip,
    required bool capped,
    int? panicIntensity,
  }) async* {
    final reply = CoachReplyCodec.decode(
      await _api.requestReply({
        'text': ?text,
        'chip': ?chip?.name,
        'capped': capped,
      }),
    );
    final words = reply.text;
    if (words != null && words.isNotEmpty) yield CoachChunk(words);
    yield CoachDone(reply);
  }

  /// The fake backend keeps the thread in memory for the session only, so
  /// there is no transcript to restore. Empty is the honest answer.
  @override
  Future<List<CoachMessage>> history() async => const [];

  /// The fake backend has no coach memory: `aiCoachChat` is what writes it,
  /// and the demo replies are scripted. An empty list is the honest answer —
  /// seeding fixtures here would show the user "memories" of things they
  /// never said.
  @override
  Future<List<CoachMemory>> memories() async => const [];

  @override
  // There is no vector store behind the demo backend, and seeding a fixture
  // one would show the user "memories" of things they never said.
  Future<void> seedMemories() async {}

  @override
  Future<void> forgetMemory(String id) async {}
}
