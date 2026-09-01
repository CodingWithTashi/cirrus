import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

/// The community stops inventing people, and its controls start working.
///
/// Three things were wrong on the one screen whose entire value is that
/// somebody real is on the other end:
///
///  * the SOS banner read `17 + replies.length` — a constant floor invented so
///    it would look busy;
///  * a new SOS post claimed `3 replying now` before anybody had seen it, and
///    nothing on the real backend could ever compute that number;
///  * the reply flag was `showLpSnack('Reported')` and nothing else, so the
///    app said a report had been filed and filed none.
class _RecordingCommunity implements CommunityRepository {
  _RecordingCommunity(this._posts);

  final List<Post> _posts;
  final reportedReplies = <({String postId, String replyId})>[];
  final blocked = <String>[];

  @override
  Future<List<Post>> fetchPosts() async => _posts;

  @override
  Future<String?> addPost(Post post) async => null;

  @override
  Stream<PostStatus> watchPostStatus(String postId) => const Stream.empty();

  @override
  Future<void> setReaction(String postId, String emoji, {required bool on}) async {}

  @override
  Future<void> addReply(String postId, Reply reply) async {}

  @override
  Future<void> reportPost(String postId) async {}

  @override
  Future<void> reportReply({
    required String postId,
    required String replyId,
  }) async => reportedReplies.add((postId: postId, replyId: replyId));

  @override
  Future<void> blockAuthor(String alias) async => blocked.add(alias);
}

Post sosPost({
  List<Reply> replies = const [],
  Map<String, int> reactions = const {},
}) => Post(
  id: 'p1',
  alias: '@slowturtle',
  avatarEmoji: '🐢',
  dayN: 3,
  tag: PostTag.sos,
  text: 'sitting outside a gas station',
  createdAt: DateTime.now(),
  replies: replies,
  reactions: reactions,
);

Reply reply(String id, {String alias = '@nightbee'}) =>
    Reply(id: id, alias: alias, avatarEmoji: '🐝', text: 'hold the line');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a new SOS post claims no replies it does not have', () async {
    final repo = _RecordingCommunity([]);
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        communityRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    container.read(quitStoreProvider.notifier).seedDemoJourney();

    final store = container.read(communityStoreProvider.notifier);
    store.addPost(text: 'about to cave', tag: PostTag.sos);

    final mine = container
        .read(communityStoreProvider)
        .posts
        .firstWhere((p) => p.text == 'about to cave');
    expect(
      mine.replies,
      isEmpty,
      reason: 'a post nobody has seen yet has no repliers',
    );
  });

  group('reporting a reply', () {
    test('reaches the backend instead of only showing a snack', () async {
      final repo = _RecordingCommunity([
        sosPost(replies: [reply('r1'), reply('r2')]),
      ]);
      final container = ProviderContainer(
        overrides: [
          ...fastBackendOverrides(),
          communityRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      await container.read(communityStoreProvider.notifier).retryFeed();

      container
          .read(communityStoreProvider.notifier)
          .reportReply(postId: 'p1', replyId: 'r2');

      expect(repo.reportedReplies, [(postId: 'p1', replyId: 'r2')]);
    });

    test('hides it for the reader straight away', () async {
      final repo = _RecordingCommunity([
        sosPost(replies: [reply('r1'), reply('r2')]),
      ]);
      final container = ProviderContainer(
        overrides: [
          ...fastBackendOverrides(),
          communityRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      await container.read(communityStoreProvider.notifier).retryFeed();

      container
          .read(communityStoreProvider.notifier)
          .reportReply(postId: 'p1', replyId: 'r2');

      final post = container.read(communityStoreProvider).posts.single;
      expect(post.replies.map((r) => r.id), ['r1']);
    });
  });

  group('blocking', () {
    test('survives a restart', () async {
      final repo = _RecordingCommunity([sosPost()]);
      final first = ProviderContainer(
        overrides: [
          ...fastBackendOverrides(),
          communityRepositoryProvider.overrideWithValue(repo),
        ],
      );
      await first.read(communityStoreProvider.notifier).retryFeed();
      first.read(communityStoreProvider.notifier).blockAuthor('p1');
      expect(first.read(communityStoreProvider).blocked, {'@slowturtle'});
      // Let the write-behind land before the container goes away.
      await Future<void>.delayed(Duration.zero);
      first.dispose();

      // A second launch, same device.
      final second = ProviderContainer(
        overrides: [
          ...fastBackendOverrides(),
          communityRepositoryProvider.overrideWithValue(
            _RecordingCommunity([sosPost()]),
          ),
        ],
      );
      addTearDown(second.dispose);
      second.read(communityStoreProvider);
      await Future<void>.delayed(Duration.zero);

      expect(
        second.read(communityStoreProvider).blocked,
        contains('@slowturtle'),
        reason: 'an unblocked-on-restart block is a broken promise',
      );
    });

    test('a block made during startup is not undone by the restore', () async {
      SharedPreferences.setMockInitialValues({
        'community.blockedAliases': <String>['@earlier'],
      });
      final container = ProviderContainer(
        overrides: [
          ...fastBackendOverrides(),
          communityRepositoryProvider.overrideWithValue(
            _RecordingCommunity([sosPost()]),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(communityStoreProvider.notifier).retryFeed();
      container.read(communityStoreProvider.notifier).blockAuthor('p1');
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(communityStoreProvider).blocked,
        containsAll(<String>['@earlier', '@slowturtle']),
      );
    });
  });
}
