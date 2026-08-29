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

  @override
  Future<List<CoachMemory>> memories() async {
    final json = await _functions.call('coachMemories');
    final items = json['memories'];
    if (items is! List) return const [];
    return [
      for (final raw in items)
        if (raw is Map) _decodeMemory(Map<String, dynamic>.from(raw)),
    ];
  }

  @override
  Future<void> forgetMemory(String id) async {
    await _functions.call('forgetCoachMemory', {'memoryId': id});
  }

  static CoachMemory _decodeMemory(Map<String, dynamic> json) => CoachMemory(
    id: json['id'] as String? ?? '',
    text: json['text'] as String? ?? '',
    // An unknown kind is a labelling problem, not a reason to hide the
    // sentence — the user still has a right to see and delete it.
    kind: MemoryKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => MemoryKind.context,
    ),
  );
}
