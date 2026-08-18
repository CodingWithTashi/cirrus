/// Wire-level community endpoints. JSON in/out.
abstract interface class CommunityApi {
  Future<List<Map<String, dynamic>>> fetchPosts();

  /// Post JSON carries a client-generated id (Firestore-style).
  Future<void> addPost(Map<String, dynamic> post);

  Future<void> setReaction({
    required String postId,
    required String emoji,
    required bool on,
  });

  Future<void> addReply({
    required String postId,
    required Map<String, dynamic> reply,
  });

  Future<void> reportPost(String postId);

  Future<void> blockAuthor(String alias);

  Future<void> nudgeBuddy();
}
