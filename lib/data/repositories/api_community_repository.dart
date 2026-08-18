import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../api/community_api.dart';
import '../dto/community_codec.dart';

/// [CommunityRepository] over the wire-level [CommunityApi].
class ApiCommunityRepository implements CommunityRepository {
  const ApiCommunityRepository(this._api);

  final CommunityApi _api;

  @override
  Future<List<Post>> fetchPosts() async => [
    for (final json in await _api.fetchPosts()) PostCodec.decode(json),
  ];

  @override
  Future<void> addPost(Post post) => _api.addPost(PostCodec.encode(post));

  @override
  Future<void> setReaction(String postId, String emoji, {required bool on}) =>
      _api.setReaction(postId: postId, emoji: emoji, on: on);

  @override
  Future<void> addReply(String postId, Reply reply) =>
      _api.addReply(postId: postId, reply: PostCodec.encodeReply(reply));

  @override
  Future<void> reportPost(String postId) => _api.reportPost(postId);

  @override
  Future<void> blockAuthor(String alias) => _api.blockAuthor(alias);

  @override
  Future<void> nudgeBuddy() => _api.nudgeBuddy();
}
