import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../api/firebase/functions_client.dart';
import '../dto/coach_codec.dart';

/// Ember, over `aiCoachChat`.
///
/// The whole coach lives server-side (docs/05 §1): the prompt must stay
/// secret, the per-tier caps must be unbypassable, and the memory card is
/// assembled from the journey the server reads itself rather than from
/// anything the client claims. This class is therefore deliberately thin —
/// one call, one decode. Any logic that appears here is logic in the wrong
/// place.
class FirebaseCoachRepository implements CoachRepository {
  FirebaseCoachRepository({LpFunctions? functions})
    : _functions = functions ?? LpFunctions();

  final LpFunctions _functions;

  @override
  Future<CoachReply> requestReply({
    String? text,
    CoachChip? chip,
    required bool capped,
  }) async {
    // `capped` is the client's own mirror of the allowance, used to grey the
    // composer. It is deliberately NOT used to skip the call: the server owns
    // the quota, answers `capReached` without spending a model call, and is
    // the only side that can be trusted about it.
    final json = await _functions.call('aiCoachChat', {
      'text': ?text,
      'chip': ?chip?.name,
    });
    return CoachReplyCodec.decode(json);
  }
}
