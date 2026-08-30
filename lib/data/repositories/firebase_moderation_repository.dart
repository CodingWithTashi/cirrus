import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../api/firebase/functions_client.dart';

/// [ModerationRepository] over `moderationQueue` / `resolveModeration`.
///
/// `firestore.rules` denies every client read of `moderation/*`, so these two
/// callables are the only door — there is no direct-Firestore fallback to
/// write here, by design.
class FirebaseModerationRepository implements ModerationRepository {
  FirebaseModerationRepository({LpFunctions? functions, FirebaseAuth? auth})
    : _functions = functions ?? LpFunctions(),
      _auth = auth ?? FirebaseAuth.instance;

  final LpFunctions _functions;
  final FirebaseAuth _auth;

  /// Reads the `admin` claim off the signed ID token.
  ///
  /// The token is signed by Firebase, so this cannot be faked locally — but
  /// it is still only used to decide whether to SHOW the entry point. The
  /// callables check the same claim themselves; a client that lied here would
  /// reach a screen that fails its first request.
  @override
  Future<bool> isModerator() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      // Cached token: a claim granted mid-session appears after the next
      // refresh, which for a founder tool is the right trade against a forced
      // network round-trip on every Settings open.
      final token = await user.getIdTokenResult();
      return token.claims?['admin'] == true;
    } on FirebaseAuthException {
      return false;
    }
  }

  @override
  Future<List<ModerationItem>> queue({bool includeReviewed = false}) async {
    final json = await _functions.call('moderationQueue', {
      'includeReviewed': includeReviewed,
    });
    final items = json['items'];
    if (items is! List) return const [];
    return [
      for (final raw in items)
        if (raw is Map) _decode(Map<String, dynamic>.from(raw)),
    ];
  }

  @override
  Future<void> resolve(String flagId, {ModerationResolution? action}) async {
    await _functions.call('resolveModeration', {
      'flagId': flagId,
      'action': ?action?.name,
    });
  }

  static ModerationItem _decode(Map<String, dynamic> json) => ModerationItem(
    flagId: json['flagId'] as String? ?? json['postId'] as String? ?? '',
    postId: json['postId'] as String? ?? '',
    replyId: json['replyId'] as String?,
    action: json['action'] as String? ?? 'flag',
    reason: json['reason'] as String? ?? '',
    kind: json['kind'] as String? ?? 'post',
    text: json['text'] as String?,
    status: json['status'] as String?,
    alias: json['alias'] as String?,
  );
}

/// The fake-backend stand-in.
///
/// The demo backend has no moderation collection and no auth claims, so this
/// reports "not a moderator" and the entry point never appears. Seeding a
/// fake queue would put invented reports in front of the founder.
class NoopModerationRepository implements ModerationRepository {
  const NoopModerationRepository();

  @override
  Future<bool> isModerator() async => false;

  @override
  Future<List<ModerationItem>> queue({bool includeReviewed = false}) async =>
      const [];

  @override
  Future<void> resolve(String postId, {ModerationResolution? action}) async {}
}
