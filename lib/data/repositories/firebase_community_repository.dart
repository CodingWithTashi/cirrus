import 'package:cloud_firestore/cloud_firestore.dart';

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
/// KNOWN LIMITATION — `isMine` and `myReactions` are tracked in this instance
/// for the session only. Posts deliberately carry no uid, and `reactions` is
/// a `{emoji: count}` map with no per-user keying, so neither can be derived
/// from the documents. The real fix is the `reactions{uid: emoji}` data-model
/// change tracked as S3-7; until then a restart forgets which posts were
/// yours. That is a cosmetic loss, not a correctness one — the server's view
/// of authorship (postAuthors) is unaffected and remains authoritative for
/// deletion.
class FirebaseCommunityRepository implements CommunityRepository {
  FirebaseCommunityRepository({
    FirebaseFirestore? firestore,
    LpFunctions? functions,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? LpFunctions();

  final FirebaseFirestore _db;
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
      (repliesByPost[postId] ??= []).add(_toReply(doc.data()));
    }

    return [
      for (final doc in snap.docs)
        if (!_blockedAliases.contains(doc.data()['alias']))
          _toPost(doc, repliesByPost[doc.id] ?? const []),
    ];
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
    // Reactions are one of only two client-writable fields (firestore.rules).
    // The count is adjusted with an atomic increment so two people reacting at
    // once cannot clobber each other.
    await _posts.doc(postId).update({
      'reactions.$emoji': FieldValue.increment(on ? 1 : -1),
    });
    final mine = _myReactions[postId] ??= <String>{};
    on ? mine.add(emoji) : mine.remove(emoji);
  }

  @override
  Future<void> reportPost(String postId) async {
    // The rules accept a report only as an exact +1 — never an assignment —
    // so this must be an increment, not a read-modify-write.
    await _posts.doc(postId).update({'reportCount': FieldValue.increment(1)});
  }

  @override
  Future<void> blockAuthor(String alias) async {
    // Blocking is viewer-side by design: aliases are per-account and there is
    // no server-side relationship to store. Mutual invisibility (docs/03 §9)
    // is the moderation queue's job, not this call's.
    _blockedAliases.add(alias);
  }

  @override
  Future<void> nudgeBuddy() async {
    // Quit Buddies is descoped (founder decision, Aug 2026 — functions/README).
    // The UI still ships, so this is a no-op rather than a throw: a button
    // that does nothing quietly beats one that shows an error for a feature
    // that was cut on purpose.
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

  Reply _toReply(Map<String, dynamic> data) => Reply(
    alias: data['alias'] as String? ?? 'quitter',
    avatarEmoji: data['avatarEmoji'] as String? ?? '🔥',
    text: data['text'] as String? ?? '',
  );
}
