import 'package:cloud_firestore/cloud_firestore.dart';
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
/// KNOWN LIMITATION — `isMine` is still session-scoped. Posts deliberately
/// carry no uid, so "did I write this?" is not derivable from the feed, and
/// the only alternative would be exposing `postAuthors` to readers, which is
/// exactly the thing that keeps the feed anonymous. A restart forgets which
/// posts were yours. That is cosmetic; `postAuthors` remains authoritative
/// server-side for deletion.
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

  final Set<String> _minePostIds = <String>{};
  final Map<String, Set<String>> _myReactions = <String, Set<String>>{};
  final Set<String> _blockedAliases = <String>{};

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');

  @override
  Future<List<Post>> fetchPosts() async {
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

    return [
      for (final doc in snap.docs)
        if (!_blockedAliases.contains(doc.data()['alias']))
          _toPost(doc, repliesByPost[doc.id] ?? const []),
    ];
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

  @override
  Future<void> addPost(Post post) async {
    final json = await _functions.call('createPost', {
      'text': post.text ?? '',
      'tag': post.tag.name,
      'alias': post.alias,
      'avatarEmoji': post.avatarEmoji,
      'dayN': post.dayN,
    });
    final id = json['postId'];
    if (id is String) _minePostIds.add(id);
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

  Post _toPost(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    List<Reply> replies,
  ) {
    final data = doc.data();
    return Post(
      id: doc.id,
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
      myReactions: _myReactions[doc.id] ?? const {},
      replies: replies,
      isMine: _minePostIds.contains(doc.id),
    );
  }

  Reply _toReply(String id, Map<String, dynamic> data) => Reply(
    id: id,
    alias: data['alias'] as String? ?? 'quitter',
    avatarEmoji: data['avatarEmoji'] as String? ?? '🔥',
    text: data['text'] as String? ?? '',
  );
}
