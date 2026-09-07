import '../../../domain/logic/community_rules.dart';
import '../../../domain/logic/mentions.dart';
import '../../../domain/repositories/repositories.dart';
import '../community_api.dart';
import 'fake_server.dart';

/// Placeholder community backend over the FakeServer's JSON post store.
class FakeCommunityApi implements CommunityApi {
  FakeCommunityApi(this._server);

  final FakeServer _server;

  @override
  Future<List<Map<String, dynamic>>> fetchPosts() =>
      _server.respond(_server.postsForSession);

  @override
  Future<Map<String, dynamic>?> fetchPost(String postId) =>
      _server.respond(() => _server.postById(postId));

  @override
  Future<String> addPost(Map<String, dynamic> post) =>
      _server.respond(() => _server.insertPost(post));

  @override
  Future<String?> postStatus(String postId) =>
      _server.respond(() => _server.postStatus(postId));

  @override
  Future<void> setReaction({
    required String postId,
    required String emoji,
    required bool on,
  }) => _server.respond(() {
    _server.updatePost(postId, (p) {
      final reactions = (p['reactions'] as Map<String, dynamic>? ?? {});
      final mine = (p['myReactions'] as List? ?? []).cast<String>().toSet();
      final count = (reactions[emoji] as num?)?.toInt() ?? 0;
      reactions[emoji] = on ? count + 1 : count - 1;
      on ? mine.add(emoji) : mine.remove(emoji);
      p['reactions'] = reactions;
      p['myReactions'] = mine.toList();
    });
  });

  @override
  Future<void> addReply({
    required String postId,
    required Map<String, dynamic> reply,
  }) => _server.respond(() {
    // The same floor `createReply` enforces. Without it the demo backend
    // accepts replies production drops, and no test on `LP_BACKEND=fake`
    // could ever see the difference.
    if (PostQuality.checkReply(reply['text'] as String? ?? '') != null) {
      throw const ContentRefusedException(ContentRefusal.rules);
    }
    // The same thing `notifyReply` does on the real backend. Without it the
    // inbox would be empty on every fake-backend run, which is every widget
    // test and the whole demo.
    _notify(postId, reply);
    _server.updatePost(
      postId,
      (p) => p['replies'] = [...(p['replies'] as List? ?? []), reply],
    );
  });

  /// Files whatever the post's author would actually be told.
  ///
  /// The author is the only person this backend can notify — it has no
  /// alias→account map and inventing one would mint an identity the demo does
  /// not have. But it must not tell them about a reply that was not for them:
  /// a demo inbox that contradicts the server it imitates is worse than an
  /// empty one, and this rule is new enough to be worth showing.
  ///
  /// Mirrors the branch in `functions/src/lib/notifyReply.ts`, including its
  /// exceptions — you are never told about your own reply, an author who was
  /// named by name hears it as a MENTION rather than as a reply, and on an
  /// SOS the author always hears, because the content of that notification is
  /// how many people came.
  void _notify(String postId, Map<String, dynamic> reply) {
    final post = _server.postById(postId);
    if (post == null) return;
    final authorAlias = (post['alias'] as String? ?? '').toLowerCase();
    final replierAlias = (reply['alias'] as String? ?? '').toLowerCase();
    // Answering yourself is not news. The server compares uids; the fake has
    // only the one session, so an alias match is the same question here.
    if (replierAlias == authorAlias) return;

    final participants = <String>[
      if (post['alias'] is String) post['alias'] as String,
      for (final other in post['replies'] as List? ?? const [])
        if (other is Map && other['alias'] is String) other['alias'] as String,
    ];
    // Mentioning yourself is not a notification, which is why the server
    // passes the replier into `resolveMentions` and this drops them here.
    final named = {
      ...LpMentions.resolveIn(participants, reply['text'] as String? ?? ''),
    }..remove(replierAlias);

    final createdAtMs = _server.now().millisecondsSinceEpoch;
    final route = '/community/post/$postId';
    if (named.contains(authorAlias)) {
      _server.notifyPostAuthor(postId, {
        // Tagged by reply, never by thread: two mentions of the same person
        // must not overwrite each other, which is the whole reason a mention
        // is the one community push that does not collapse.
        'id': 'mention:${reply['id']}',
        'kind': 'communityMention',
        'title': 'Someone tagged you',
        'body': 'You were mentioned in a reply.',
        'route': route,
        'createdAtMs': createdAtMs,
        'readAtMs': null,
      });
      return;
    }
    // Named somebody else, and this is not the one post where the author
    // hears regardless.
    if (named.isNotEmpty && post['tag'] != 'sos') return;

    _server.notifyPostAuthor(postId, {
      'id': 'thread:$postId',
      'kind': 'communityReply',
      'title': 'Someone replied',
      'body': 'Go see what they said.',
      'route': route,
      'createdAtMs': createdAtMs,
      'readAtMs': null,
    });
  }

  @override
  Future<void> reportPost(String postId) =>
      _server.respond(() => _server.reportPost(postId));

  @override
  Future<void> blockAuthor(String alias) => _server.respond(() {});
}
