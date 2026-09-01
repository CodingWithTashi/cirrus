/// Wire-level community endpoints. JSON in/out.
abstract interface class CommunityApi {
  Future<List<Map<String, dynamic>>> fetchPosts();

  /// Post JSON carries a client-generated id (Firestore-style). Answers the
  /// id the backend stored it under, which may differ.
  Future<String> addPost(Map<String, dynamic> post);

  /// `posts/{id}.status` by name, or null when the backend has no such post.
  Future<String?> postStatus(String postId);

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

}
