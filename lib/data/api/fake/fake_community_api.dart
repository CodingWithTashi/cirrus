import '../../../domain/logic/community_rules.dart';
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
    _server.updatePost(
      postId,
      (p) => p['replies'] = [...(p['replies'] as List? ?? []), reply],
    );
  });

  @override
  Future<void> reportPost(String postId) =>
      _server.respond(() => _server.reportPost(postId));

  @override
  Future<void> blockAuthor(String alias) => _server.respond(() {});

}
