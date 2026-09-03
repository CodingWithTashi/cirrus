import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/logic/coach_history.dart';
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
    final payload = <String, Object?>{
      'text': ?text,
      'chip': ?chip?.name,
      'panicIntensity': ?panicIntensity,
    };
    final events = _functions.stream('aiCoachChat', payload);

    var sawResult = false;
    var sawChunk = false;
    await for (final event in events) {
      final chunk = event.chunk;
      if (chunk != null) {
        sawChunk = true;
        yield CoachChunk(chunk);
        continue;
      }
      final result = event.result;
      if (result != null) {
        sawResult = true;
        yield CoachDone(CoachReplyCodec.decode(result));
      }
    }
    if (sawResult) return;
    // A stream that ends without an envelope delivered no reply, however much
    // prose it emitted. Failing loudly keeps the store on its one fallback
    // path instead of leaving a half-written bubble on screen forever.
    if (sawChunk) throw const NoConnectionException();
    // Ended before a single word. On Android the plugin's stream handler
    // answers every failure this way — `onError` just closes the stream, the
    // reason never reaches Dart — so this branch cannot tell an App Check
    // refusal from a dead link, and it used to call both "you're offline".
    // Ask the same function again over the plain call: the server answers
    // the whole envelope when the client does not stream, and that path
    // keeps its error codes, so a refusal surfaces as the refusal it is.
    // Nothing was streamed, so nothing is answered twice; the server has not
    // spent a model call on a request it rejected at the door.
    final result = await _functions.call('aiCoachChat', payload);
    yield CoachDone(CoachReplyCodec.decode(result));
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
    // `orderBy('ts')` alone is not an order for a user/reply pair written in
    // one batch with one server timestamp — the tie came back reversed
    // after a cold restart (QA L1). `CoachHistory` breaks it: user first.
    return CoachHistory.ordered([
      for (final doc in snap.docs.reversed) ?_decodeHistory(doc.id, doc.data()),
    ]);
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
    // The server timestamp, as a local-flagged DateTime of the right instant.
    // Nullable: a turn written moments ago can come back with its
    // serverTimestamp still unresolved.
    final sentAt = (json['ts'] as Timestamp?)?.toDate();
    if (json['role'] == 'user') {
      // A chip tap is stored as its bracket token ("[progress]") — the server
      // synthesizes that when no text is sent. Restore it as a chip echo so
      // the view renders the localized label; a raw `CoachMessage.user` here
      // once printed "[progress]" verbatim into the thread.
      final chip = _chipFromToken(text);
      return chip != null
          ? CoachMessage.chip(id: 'h_$id', chipEcho: chip, sentAt: sentAt)
          : CoachMessage.user(id: 'h_$id', text: text, sentAt: sentAt);
    }
    return CoachMessage.ember(
      id: 'h_$id',
      // History carries Ember's own words, so the template is only the
      // never-rendered fallback slot `text` overrides.
      template: CoachTemplate.generic1,
      text: text,
      sentAt: sentAt,
    );
  }

  /// "[craving]" → `CoachChip.craving.index`, or null for ordinary text.
  /// Token names mirror `COACH_CHIPS` in `functions/src/domain/types.ts`.
  static int? _chipFromToken(String text) {
    if (!text.startsWith('[') || !text.endsWith(']')) return null;
    final inner = text.substring(1, text.length - 1);
    final i = CoachChip.values.indexWhere((c) => c.name == inner);
    return i == -1 ? null : i;
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
