import '../community_api.dart';
import 'fake_server.dart';

/// Placeholder community backend over the FakeServer's JSON post store.
class FakeCommunityApi implements CommunityApi {
  FakeCommunityApi(this._server);

  final FakeServer _server;

  @override
  Future<List<Map<String, dynamic>>> fetchPosts() =>
      _server.respond(() => FakeServer.copyList(_server.posts));

  @override
  Future<void> addPost(Map<String, dynamic> post) =>
      _server.respond(() => _server.insertPost(post));

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

  @override
  Future<void> nudgeBuddy() => _server.respond(() {});
}
