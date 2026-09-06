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

  @override
  Stream<List<AppNotification>> watch() {
    final uid = _auth.currentUser?.uid;
    // Signed out: an empty inbox, not an error. This is watched from the shell
    // and must be silent on the sign-in screen.
    if (uid == null) return Stream.value(const []);

    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAtMs', descending: true)
        .limit(_limit)
        .snapshots()
        .map(
          (snap) => [
            for (final doc in snap.docs) _decode(doc.id, doc.data()),
          ],
        );
  }

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
