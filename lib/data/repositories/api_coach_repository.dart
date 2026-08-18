import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../api/coach_api.dart';
import '../dto/coach_codec.dart';

/// [CoachRepository] over the wire-level [CoachApi].
class ApiCoachRepository implements CoachRepository {
  const ApiCoachRepository(this._api);

  final CoachApi _api;

  @override
  Future<CoachReply> requestReply({
    String? text,
    CoachChip? chip,
    required bool capped,
  }) async => CoachReplyCodec.decode(
    await _api.requestReply({
      'text': ?text,
      'chip': ?chip?.name,
      'capped': capped,
    }),
  );
}
