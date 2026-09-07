import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';

/// The inbox, straight off Firestore.
///
/// A direct read rather than a callable: `users/{uid}/{document=**}` already
/// grants the owner read access, so this needs no function, no App Check round
/// trip and no cold start — and it can be a live snapshot stream, which a
/// callable could not be. The write side is the opposite and goes through
/// `syncUserContext`, because these rows are the server's record of what it
/// told this account and a client that could write them could invent one.
class FirebaseNotificationsRepository implements NotificationsRepository {
  FirebaseNotificationsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// One screenful and then some. The inbox is a record of what happened
  /// recently, not an archive — the prune cron drops rows past 30 days, and
  /// nothing in the app looks further back than this.
  static const int _limit = 50;

  /// The inbox of whoever is signed in **right now**.
  ///
  /// It follows the session rather than resolving a uid once, and that is not
  /// a nicety. `notificationsStoreProvider` is not auto-disposed and nothing
  /// invalidates it, so the store is built the first time the bell renders and
  /// lives for the rest of the process — meaning a uid captured here would be
  /// captured for the life of the app. On a shared phone the next person to
  /// sign in would be reading the last person's inbox, which is the same
  /// account-shaped-state-on-a-device-scoped-thing bug as the milestone ledger
  /// and the widget mirror, in the one surface that shows what other people
  /// have said to them.
  ///
  /// Signed out is an empty inbox, not an error: this is watched from the
  /// shell and has to be silent on the sign-in screen.
  @override
  Stream<List<AppNotification>> watch() {
    StreamSubscription<User?>? session;
    StreamSubscription<List<AppNotification>>? inbox;
    String? bound;
    var hasBound = false;
    var done = false;

    late final StreamController<List<AppNotification>> out;

    void bind(String? uid) {
      // Cancelling a stream does not un-dispatch an event already on its way,
      // so `bind` can still run once after `onCancel` has swept. Without this
      // it would open a Firestore snapshot listener nothing holds a handle to
      // any more — a listener that stays open, and keeps billing, for the rest
      // of the process.
      if (done) return;
      // `authStateChanges` also fires for the same account (a token refresh,
      // a reload); re-subscribing on those would drop and re-open the snapshot
      // listener for nothing.
      if (hasBound && uid == bound) return;
      final isRebind = hasBound;
      hasBound = true;
      bound = uid;

      inbox?.cancel();
      inbox = null;

      if (uid == null) {
        out.add(const []);
        return;
      }
      // Clear the previous account's rows at the moment the account changes,
      // not whenever the first snapshot for the new one happens to land.
      if (isRebind) out.add(const []);
      inbox = _inboxOf(uid).listen(
        out.add,
        onError: (Object error, StackTrace trace) {
          // A `snapshots()` stream TERMINATES when it errors — it does not
          // recover on its own. Without forgetting the binding here, the
          // same-account short-circuit above would refuse to re-open it, so
          // one transient `permission-denied` (or exactly the
          // FAILED_PRECONDITION this whole change exists to fix) would kill
          // the inbox for the rest of the process. `NotificationsStore` reads
          // an error as an empty inbox, so it would look like nothing was
          // wrong while the bell silently stopped updating until a restart.
          //
          // Forgetting is enough: the next `authStateChanges` event — a token
          // refresh, a resume, a re-auth — then counts as a change and binds
          // again. It is not a retry loop, deliberately; a hard refusal
          // should not be re-asked in a tight circle.
          hasBound = false;
          bound = null;
          out.addError(error, trace);
        },
      );
    }

    out = StreamController<List<AppNotification>>(
      onListen: () {
        session = _auth.authStateChanges().listen((user) => bind(user?.uid));
      },
      onCancel: () async {
        done = true;
        await session?.cancel();
        await inbox?.cancel();
      },
    );
    return out.stream;
  }

  Stream<List<AppNotification>> _inboxOf(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('notifications')
      // Newest first — which is why `notifications.createdAtMs` must keep a
      // COLLECTION+DESCENDING entry in its `firestore.indexes.json` override.
      // A field override replaces Firestore's automatic indexes rather than
      // adding to them, and when this one listed only ASCENDING every read
      // here answered FAILED_PRECONDITION. See test/firestore_indexes_test.dart.
      .orderBy('createdAtMs', descending: true)
      .limit(_limit)
      .snapshots()
      .map(
        (snap) => [
          for (final doc in snap.docs) _decode(doc.id, doc.data()),
        ],
      );

  AppNotification _decode(String id, Map<String, dynamic> data) =>
      AppNotification(
        id: id,
        // Raw, not an enum: a newer backend may send a kind this build has
        // never heard of, and an unknown row should still render.
        kind: data['kind'] as String? ?? 'system',
        title: data['title'] as String? ?? '',
        body: data['body'] as String? ?? '',
        route: data['route'] as String?,
        createdAt: _millis(data['createdAtMs']) ?? DateTime.now(),
        readAt: _millis(data['readAtMs']),
      );

  static DateTime? _millis(Object? value) => value is num
      ? DateTime.fromMillisecondsSinceEpoch(value.toInt())
      : null;
}
