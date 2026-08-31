import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  Stream<CoachEvent> streamReply({
    String? text,
    CoachChip? chip,
    required bool capped,
    int? panicIntensity,
  }) async* {
    // `capped` is the client's own mirror of the allowance, used to grey the
    // composer. It is deliberately NOT used to skip the call: the server owns
    // the quota, answers `capReached` without spending a model call, and is
    // the only side that can be trusted about it.
    final events = _functions.stream('aiCoachChat', {
      'text': ?text,
      'chip': ?chip?.name,
      'panicIntensity': ?panicIntensity,
    });

    var sawResult = false;
    await for (final event in events) {
      final chunk = event.chunk;
      if (chunk != null) {
        yield CoachChunk(chunk);
        continue;
      }
      final result = event.result;
      if (result != null) {
        sawResult = true;
        yield CoachDone(CoachReplyCodec.decode(result));
      }
    }
    // A stream that ends without an envelope delivered no reply, however much
    // prose it emitted. Failing loudly keeps the store on its one fallback
    // path instead of leaving a half-written bubble on screen forever.
    if (!sawResult) throw const NoConnectionException();
  }

  /// Read straight from Firestore rather than through a callable.
  ///
  /// `users/{uid}/{document=**}` is already owner-readable by rule, and the
  /// transcript is server-written so it cannot be forged from here. That makes
  /// a 17th function pure overhead — plus this way the thread comes back from
  /// the offline cache when the network is gone, which a callable can never do.
  @override
  Future<List<CoachMessage>> history() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const [];
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('coachMessages')
        .orderBy('ts', descending: true)
        .limit(_historyLimit)
        .get();
    return [
      for (final doc in snap.docs.reversed) ?_decodeHistory(doc.id, doc.data()),
    ];
  }

  /// Enough to feel continuous without paying to rebuild a year of chat on
  /// every tab open. The thread scrolls to the end anyway.
  static const _historyLimit = 40;

  /// One stored turn → a thread message.
  ///
  /// Ids come from the document so a restored thread and a live one cannot
  /// collide. An empty body decodes to null rather than an empty bubble —
  /// the same rule `CoachReplyCodec` already applies to `text`.
  static CoachMessage? _decodeHistory(String id, Map<String, dynamic> json) {
    final text = json['text'] as String? ?? '';
    if (text.isEmpty) return null;
    return json['role'] == 'user'
        ? CoachMessage.user(id: 'h_$id', text: text)
        : CoachMessage.ember(
            id: 'h_$id',
            // History carries Ember's own words, so the template is only the
            // never-rendered fallback slot `text` overrides.
            template: CoachTemplate.generic1,
            text: text,
          );
  }

  @override
  Future<void> seedMemories() =>
      _functions.call('seedCoachMemories', const {});

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
