import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../api/community_api.dart';
import '../dto/codec_helpers.dart';
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
  Future<String?> addPost(Post post) => _api.addPost(PostCodec.encode(post));

  /// The fake backend moderates synchronously on insert, so one read is the
  /// whole story.
  @override
  Stream<PostStatus> watchPostStatus(String postId) async* {
    final name = await _api.postStatus(postId);
    if (name == null) return;
    yield enumByName(PostStatus.values, name, PostStatus.live);
  }

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

  /// The demo backend has no reply moderation to reach — `reportReply` is a
  /// callable, and there is no server here. Doing nothing is the honest
  /// answer; the store still hides the reply for this reader.
  @override
  Future<void> reportReply({
    required String postId,
    required String replyId,
  }) async {}
}
