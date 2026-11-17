import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../api/fake/fake_server.dart';
import '../api/firebase/functions_client.dart';
import '../dto/journey_codec.dart';
import 'firebase_common.dart';

/// [ServerStateRepository] over the server-owned `users/{uid}` document.
///
/// Reads only — `firestore.rules` denies every client write to this tree, and
/// that denial is the entire reason entitlement can live here safely. The two
/// things the crons produce (`planAdvice`, `insights/*`) were being written
/// nightly with nothing on the client reading them; this class is the reader.
///
/// [refreshEntitlement] is the one method here that is not a document read,
/// and it is still not a write: it asks a callable to refresh the mirror from
/// the store. The client never writes this tree, which is the whole point.
class FirebaseServerStateRepository implements ServerStateRepository {
  FirebaseServerStateRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    LpFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _db = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? LpFunctions();

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final LpFunctions _functions;

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _auth.currentUser?.uid;
    return uid == null ? null : _db.collection('users').doc(uid);
  }

  @override
  Future<PlanAdvice?> planAdvice() async {
    final doc = _userDoc;
    if (doc == null) return null;
    return guardAuth(() async {
      final raw = (await doc.get()).data()?['planAdvice'];
      if (raw == null) return null;
      // `computedAt` is a Firestore Timestamp, which jsonEncode cannot see;
      // the four fields the codec reads are all JSON primitives, so the
      // normalizing round-trip runs on a copy without it.
      final json = Map<String, dynamic>.from(raw as Map);
      json.remove('computedAt');
      return JourneyCodec.decodeAdvice(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
    });
  }

  @override
  Future<WeeklyInsight?> latestInsight() async {
    final doc = _userDoc;
    if (doc == null) return null;
    return guardAuth(() async {
      // Ordered by document id, which IS the local-Sunday `yyyy-MM-dd` key —
      // lexicographic order on that format is chronological order, so this
      // needs no index and no `createdAt` read.
      final snap = await doc
          .collection('insights')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final data = snap.docs.single.data();
      // A half-written report renders as no report. Five strings or nothing:
      // a card reading "null" is worse than the local fallback.
      String? field(String key) {
        final value = data[key];
        return value is String && value.isNotEmpty ? value : null;
      }

      final headline = field('headline');
      final pattern = field('pattern');
      final win = field('win');
      final watchout = field('watchout');
      final move = field('move');
      if (headline == null ||
          pattern == null ||
          win == null ||
          watchout == null ||
          move == null) {
        return null;
      }
      return WeeklyInsight(
        weekId: snap.docs.single.id,
        headline: headline,
        pattern: pattern,
        win: win,
        watchout: watchout,
        move: move,
      );
    });
  }

  @override
  Future<bool> refreshEntitlement() async {
    if (_auth.currentUser == null) return false;
    try {
      final answer = await _functions.call('refreshEntitlement');
      final tier = answer['tier'];
      return tier == 'premium' || tier == 'trial';
    } on Object {
      // Deliberately swallows everything. This call is an optimisation on a
      // write the webhook performs anyway; a purchase that succeeded must
      // never look like it failed because a follow-up round-trip did.
      return false;
    }
  }

  /// The other non-read here, and like [refreshEntitlement] a callable rather
  /// than a write: `eraseHistory` deletes server-owned documents the rules
  /// would never let this client touch. Unlike it, a failure here throws —
  /// see the contract.
  ///
  /// The timeout is the function's own (`timeoutSeconds: 300`): at the
  /// plugin's 60 seconds a long history would be reported as a failure while
  /// the server went on erasing it.
  @override
  Future<void> eraseHistory() async {
    await _functions.call('eraseHistory', const {}, _eraseTimeout);
    await _forgetCachedHistory();
  }

  static const _eraseTimeout = Duration(minutes: 5);

  /// Reads back, from the server, everything the erase deleted that this
  /// client reads straight from Firestore — the transcript, the weekly
  /// reports and the user document's advice.
  ///
  /// The Admin SDK's deletes never reach the device's offline cache, and an
  /// offline `get()` answers from it: an app opened with no signal after a
  /// fresh start would bring the erased thread back. A server read is what
  /// tells the cache those documents are gone. Best effort — the erase itself
  /// has already succeeded, and any later online read does the same.
  Future<void> _forgetCachedHistory() async {
    final doc = _userDoc;
    if (doc == null) return;
    const server = GetOptions(source: Source.server);
    try {
      // Bounded: the spinner is still up, and on a weak link a server read
      // can take a long time to fail after the erase itself has succeeded.
      await Future.wait([
        doc.get(server),
        doc.collection('coachMessages').get(server),
        doc.collection('insights').get(server),
      ]).timeout(const Duration(seconds: 10));
    } on Object {
      // Nothing to tell anyone: see above.
    }
  }
}

/// The fake-backend stand-in.
///
/// Both crons are Cloud Functions with no fake counterpart, so there is
/// genuinely nothing to answer with. Returning null keeps the demo on its
/// designed content — the Insight screen's authored cards, the raw taper
/// curve — instead of showing invented server output.
///
/// [eraseHistory] has nothing to erase either (the fake coach keeps no
/// transcript and no memories), but it still goes through [server] when one
/// is given, so an offline erase fails exactly as production's does and the
/// new-plan screen's error path is reachable from a widget test.
class NoopServerStateRepository implements ServerStateRepository {
  const NoopServerStateRepository({this.server});

  final FakeServer? server;

  @override
  Future<PlanAdvice?> planAdvice() async => null;

  @override
  Future<WeeklyInsight?> latestInsight() async => null;

  /// The fake backend has no mirror to refresh — its entitlement row IS the
  /// answer the gates read, and it is already current the moment a purchase
  /// resolves. False means "nothing was refreshed", never "not premium".
  @override
  Future<bool> refreshEntitlement() async => false;

  @override
  Future<void> eraseHistory() async {
    await server?.respond(() {});
  }
}
