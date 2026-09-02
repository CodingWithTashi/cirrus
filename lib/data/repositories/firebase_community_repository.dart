import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../api/firebase/functions_client.dart';

/// The community feed over Firestore + the `createPost`/`createReply`
/// callables.
///
/// Reads go direct to Firestore (the rules expose only `status == 'live'`, so
/// nothing unmoderated can arrive here); writes go through callables, because
/// a post must be born without an author uid on it and only the server can
/// stamp the authorship mapping (docs/05 §6).
///
/// `myReactions` is read from the `reactors` subcollection, so it survives a
/// restart and a device change — the reaction is stored, not remembered.
///
/// **`isMine` is decided by the backend, per account.** `createPost` writes a
/// server-owned mirror at `users/{uid}/posts/{postId}` (status, text, tag),
/// readable only by its owner, and `moderatePost`/`reportPost`/
/// `resolveModeration` keep its `status` in step with the post. Reading that
/// mirror on every fetch answers two questions the feed could not before:
/// which posts are the caller's (durably, across restarts and devices) and
/// what state the caller's own posts are in, including the held and refused
/// ones the rules hide from everybody else.
///
/// It used to be a session-scoped `Set<String>` on this object. This object
/// lives for the whole process, so a post written by whoever signed in first
/// stayed "mine" for whoever signed in next on the same phone — and "mine"
/// is exactly the condition that hides Report, Mute and Block (QA H3, three
/// accounts on one device). Posts still carry no uid; the mirror lives under
/// the author's own document, so the feed stays anonymous.
class FirebaseCommunityRepository implements CommunityRepository {
  FirebaseCommunityRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    LpFunctions? functions,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _functions = functions ?? LpFunctions();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final LpFunctions _functions;

  /// Feed page size. The community is a supporting surface, not an infinite
  /// scroll — docs/03 §9 describes a reverse-chron feed, not a timeline.
  static const int _feedLimit = 50;

  /// Per account, never shared across sign-ins on one device.
  final Map<String, Set<String>> _blockedByUid = <String, Set<String>>{};
  final Map<String, Set<String>> _myReactions = <String, Set<String>>{};

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');

  CollectionReference<Map<String, dynamic>> _myPosts(String uid) =>
      _db.collection('users').doc(uid).collection('posts');

  Set<String> get _blockedAliases =>
      _blockedByUid[_auth.currentUser?.uid ?? ''] ??= <String>{};

  @override
  Future<List<Post>> fetchPosts() async {
    final uid = _auth.currentUser?.uid;
    final snap = await _posts
        .where('status', isEqualTo: 'live')
        .orderBy('createdAt', descending: true)
        .limit(_feedLimit)
        .get();

    // Replies come back in ONE collection-group query rather than one query
    // per post — a 50-post feed would otherwise cost 51 round trips.
    final replies = await _db
        .collectionGroup('replies')
        .where('status', isEqualTo: 'live')
        .get();
    final repliesByPost = <String, List<Reply>>{};
    for (final doc in replies.docs) {
      final postId = doc.reference.parent.parent?.id;
      if (postId == null) continue;
      (repliesByPost[postId] ??= []).add(_toReply(doc.id, doc.data()));
    }

    await _loadMyReactions();
    final mine = uid == null
        ? const <String, Map<String, dynamic>>{}
        : await _loadMine(uid);

    final feed = [
      for (final doc in snap.docs)
        if (!_blockedAliases.contains(doc.data()['alias']))
          _toPost(
            doc.id,
            doc.data(),
            repliesByPost[doc.id] ?? const [],
            isMine: mine.containsKey(doc.id),
          ),
    ];

    // The caller's own posts the rules hide from everyone else — held for
    // review, refused, or simply not classified yet. They render in the
    // author's feed wearing their state (QA M5: "Posted." and then gone).
    final liveIds = {for (final doc in snap.docs) doc.id};
    for (final entry in mine.entries) {
      if (liveIds.contains(entry.key)) continue;
      final status = _statusOf(entry.value['status']);
      if (status == PostStatus.live) continue; // paged out of the 50; fine
      feed.add(_toPost(entry.key, entry.value, const [], isMine: true));
    }
    return feed;
  }

  /// One collection-group query for every reaction this viewer has left,
  /// rather than a read per post. The rules permit it because the query
  /// filters on the `uid` field.
  Future<void> _loadMyReactions() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final mine = await _db
        .collectionGroup('reactors')
        .where('uid', isEqualTo: uid)
        .get();

    _myReactions.clear();
    for (final doc in mine.docs) {
      final postId = doc.reference.parent.parent?.id;
      final emoji = doc.data()['emoji'];
      if (postId == null || emoji is! String) continue;
      (_myReactions[postId] ??= <String>{}).add(emoji);
    }
  }

  /// The server-owned mirror of this account's posts: id → document.
  Future<Map<String, Map<String, dynamic>>> _loadMine(String uid) async {
    final snap = await _myPosts(uid)
        .orderBy('createdAt', descending: true)
        .limit(_feedLimit)
        .get();
    return {for (final doc in snap.docs) doc.id: doc.data()};
  }

  @override
  Future<String?> addPost(Post post) async {
    final Map<String, dynamic> json;
    try {
      json = await _functions.call('createPost', {
        'text': post.text ?? '',
        'tag': post.tag.name,
        'alias': post.alias,
        'avatarEmoji': post.avatarEmoji,
        'dayN': post.dayN,
        // The local id, so a retry of a send whose response was lost lands
        // on the same server document instead of minting a second post.
        'clientId': post.id,
      });
    } on FirebaseFunctionsException catch (error) {
      // The server refused the CONTENT — the rules prefilter at the door, or
      // the daily cap — as opposed to the app or the network, which
      // `LpFunctions` has already mapped. Final either way; the reason
      // decides the words (docs/09 issue 6).
      switch (error.code) {
        case 'invalid-argument':
          throw const ContentRefusedException(ContentRefusal.rules);
        case 'resource-exhausted':
          throw const ContentRefusedException(ContentRefusal.dailyCap);
        case 'permission-denied':
          throw const ContentRefusedException(ContentRefusal.premium);
      }
      rethrow;
    }
    final id = json['postId'];
    return id is String ? id : null;
  }

  /// Follows the mirror document: `pending` while `moderatePost` is still
  /// running, then whatever it decided. Closes on a final state, and closes
  /// too when the SERVER says there is no such row — a cache-only "missing"
  /// is the normal first snapshot and is waited through, but a row the
  /// backend does not have would otherwise hold a listener open for the
  /// rest of the session. Reading `posts/{id}` directly would be denied
  /// while it is pending, which is the whole reason the mirror exists.
  @override
  Stream<PostStatus> watchPostStatus(String postId) async* {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await for (final snap in _myPosts(uid).doc(postId).snapshots()) {
      if (!snap.exists) {
        if (snap.metadata.isFromCache) continue;
        return;
      }
      final status = _statusOf(snap.data()?['status']);
      yield status;
      // `held` is not final: `remoderateHeld` or the founder flips it later,
      // and the author should see that land without a restart.
      if (status != PostStatus.pending && status != PostStatus.held) return;
    }
  }

  @override
  Future<void> addReply(String postId, Reply reply) async {
    await _functions.call('createReply', {
      'postId': postId,
      'text': reply.text ?? '',
      'alias': reply.alias,
      'avatarEmoji': reply.avatarEmoji,
    });
  }

  @override
  Future<void> setReaction(
    String postId,
    String emoji, {
    required bool on,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // The client writes only its OWN reaction; the aggregate count is derived
    // by the onReaction trigger. A client that could write the count directly
    // could give any post any popularity it liked.
    final ref = _posts.doc(postId).collection('reactors').doc(uid);
    if (on) {
      // uid is duplicated into the body so the collection-group read in
      // fetchPosts is provable to the rules — see firestore.rules.
      await ref.set({'emoji': emoji, 'uid': uid});
    } else {
      await ref.delete();
    }

    final mine = _myReactions[postId] ??= <String>{};
    on ? mine.add(emoji) : mine.remove(emoji);
  }

  @override
  Future<void> reportPost(String postId) async {
    // A callable, mirroring reportReply. The raw reportCount increment this
    // used to do fed a counter no server code read — no dedupe, no auto-hide,
    // no moderation-queue row — so the report button did nothing anyone could
    // act on. The server keys reports by reporter and hides at 3.
    await _functions.call('reportPost', {'postId': postId});
  }

  @override
  Future<void> reportReply({
    required String postId,
    required String replyId,
  }) async {
    await _functions.call('reportReply', {
      'postId': postId,
      'replyId': replyId,
    });
  }

  @override
  Future<void> blockAuthor(String alias) async {
    // Blocking is viewer-side by design: aliases are per-account and there is
    // no server-side relationship to store. Mutual invisibility (docs/03 §9)
    // is the moderation queue's job, not this call's.
    _blockedAliases.add(alias);
  }

  static PostStatus _statusOf(Object? raw) => switch (raw) {
    'live' => PostStatus.live,
    'held' => PostStatus.held,
    'blocked' => PostStatus.blocked,
    // Unknown reads as "not visible yet", the conservative direction — and
    // never as `failed`, which only the local send path may set.
    _ => PostStatus.pending,
  };

  Post _toPost(
    String id,
    Map<String, dynamic> data,
    List<Reply> replies, {
    required bool isMine,
  }) => Post(
    id: id,
    alias: data['alias'] as String? ?? 'quitter',
    avatarEmoji: data['avatarEmoji'] as String? ?? '🔥',
    dayN: (data['dayN'] as num?)?.toInt() ?? 0,
    tag: PostTag.values.firstWhere(
      (t) => t.name == data['tag'],
      orElse: () => PostTag.win,
    ),
    text: data['text'] as String? ?? '',
    createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    reactions: {
      for (final e in (data['reactions'] as Map? ?? const {}).entries)
        e.key as String: (e.value as num).toInt(),
    },
    myReactions: _myReactions[id] ?? const {},
    replies: replies,
    isMine: isMine,
    status: _statusOf(data['status'] ?? 'live'),
  );

  Reply _toReply(String id, Map<String, dynamic> data) => Reply(
    id: id,
    alias: data['alias'] as String? ?? 'quitter',
    avatarEmoji: data['avatarEmoji'] as String? ?? '🔥',
    text: data['text'] as String? ?? '',
  );
}
