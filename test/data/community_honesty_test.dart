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
  Future<Post?> fetchPost(String postId) async =>
      (await fetchPosts()).where((p) => p.id == postId).firstOrNull;

  @override
  Future<List<Post>> fetchPosts() async => _posts;

  @override
  Future<String?> addPost(Post post) async => null;

  @override
  Stream<PostStatus> watchPostStatus(String postId) => const Stream.empty();

  @override
  Future<void> setReaction(
    String postId,
    String emoji, {
    required bool on,
  }) async {}

  /// Makes `addReply` answer the way `createReply` does for a slur or an
  /// over-long reply: a final refusal, not a dropped connection.
  bool refuseReplies = false;

  @override
  Future<void> addReply(String postId, Reply reply) async {
    if (refuseReplies) {
      throw const ContentRefusedException(ContentRefusal.rules);
    }
  }

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
  int? replyCount,
}) => Post(
  id: 'p1',
  alias: '@slowturtle',
  avatarEmoji: '🐢',
  dayN: 3,
  tag: PostTag.sos,
  text: 'sitting outside a gas station',
  createdAt: DateTime.now(),
  replies: replies,
  replyCount: replyCount,
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

  group('the feed counts replies without downloading them', () {
    // `fetchPosts` used to run an unlimited `collectionGroup('replies')` — every
    // live reply in the app, on every feed open — to render "3 replied". The
    // count is server-maintained now (`posts/{id}.replyCount`, kept by the
    // `onReplyStatus` trigger) and the feed loads no reply bodies at all.
    test('reads the server count when the list is empty', () {
      // Exactly the feed's shape: a number, and nothing loaded.
      final post = sosPost(replies: const [], replyCount: 7);
      expect(post.replyTotal, 7);
      expect(post.replies, isEmpty);
    });

    test('falls back to the loaded replies when there is no count', () {
      // A post written before the field existed, and every post on the fake
      // backend — where the loaded list IS the whole truth.
      expect(sosPost(replies: [reply('r1'), reply('r2')]).replyTotal, 2);
      expect(sosPost().replyTotal, 0);
    });

    test('a thread agrees with its own card', () {
      final post = sosPost(replies: [reply('r1')], replyCount: 1);
      expect(post.replyTotal, 1);
    });

    Future<ProviderContainer> opened({
      int? replyCount,
      bool refuse = false,
    }) async {
      final repo = _RecordingCommunity([sosPost(replyCount: replyCount)])
        ..refuseReplies = refuse;
      final container = ProviderContainer(
        overrides: [
          ...fastBackendOverrides(),
          communityRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      container.read(quitStoreProvider.notifier).seedDemoJourney();
      await container.read(communityStoreProvider.notifier).retryFeed();
      return container;
    }

    Post postIn(ProviderContainer c) =>
        c.read(communityStoreProvider).posts.firstWhere((p) => p.id == 'p1');

    test('an optimistic reply moves the COUNT, not just the list', () async {
      // Otherwise the thread shows the new reply while the card behind it
      // still reads one fewer, until the next feed load.
      final container = await opened(replyCount: 4);
      await container
          .read(communityStoreProvider.notifier)
          .addReply('p1', 'you have got this');
      expect(postIn(container).replyTotal, 5);
      expect(postIn(container).replyCount, 5);
    });

    test('a refused reply takes its count back with it', () async {
      final container = await opened(replyCount: 4, refuse: true);
      final sent = await container
          .read(communityStoreProvider.notifier)
          .addReply('p1', 'a reply the server will refuse');
      expect(sent, isFalse);
      expect(postIn(container).replyTotal, 4);
      expect(postIn(container).replyCount, 4);
    });

    test('a post with no server count still counts up as you reply', () async {
      final container = await opened();
      expect(postIn(container).replyTotal, 0);
      await container
          .read(communityStoreProvider.notifier)
          .addReply('p1', 'you have got this');
      expect(postIn(container).replyTotal, 1);
      expect(
        postIn(container).replyCount,
        isNull,
        reason: 'no count was known, so none is invented — the list answers',
      );
    });
  });

  group('a reply that was refused stops claiming it was sent', () {
    Future<(ProviderContainer, _RecordingCommunity)> opened({
      required bool refuse,
    }) async {
      final repo = _RecordingCommunity([sosPost()])..refuseReplies = refuse;
      final container = ProviderContainer(
        overrides: [
          ...fastBackendOverrides(),
          communityRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      container.read(quitStoreProvider.notifier).seedDemoJourney();
      await container.read(communityStoreProvider.notifier).retryFeed();
      return (container, repo);
    }

    List<Reply> repliesIn(ProviderContainer c) => c
        .read(communityStoreProvider)
        .posts
        .firstWhere((p) => p.id == 'p1')
        .replies;

    test('a refusal takes it back out of the thread and says so', () async {
      // Every outcome used to go through `.ignore()`, so a reply the callable
      // refused — a slur, or anything over its 300-character limit — sat in
      // the author's own thread looking sent, forever, while nobody else
      // could ever see it.
      final (container, _) = await opened(refuse: true);
      final before = repliesIn(container).length;

      final sent = await container
          .read(communityStoreProvider.notifier)
          .addReply('p1', 'a reply the server will refuse');

      expect(sent, isFalse, reason: 'the caller has to be able to say so');
      expect(
        repliesIn(container).length,
        before,
        reason: 'a refused reply must not keep rendering as sent',
      );
    });

    test('an accepted reply stays, and answers true', () async {
      final (container, _) = await opened(refuse: false);
      final before = repliesIn(container).length;

      final sent = await container
          .read(communityStoreProvider.notifier)
          .addReply('p1', 'you have got this');

      expect(sent, isTrue);
      expect(repliesIn(container).length, before + 1);
    });

    test('offline KEEPS the reply — that is the local-first stance', () async {
      // A dropped connection is not a verdict on the reply. The offline
      // banner is already telling that story, and a reply that vanishes
      // because the radio was waking would be the worse outcome.
      final repo = _OfflineReplies([sosPost()]);
      final container = ProviderContainer(
        overrides: [
          ...fastBackendOverrides(),
          communityRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      container.read(quitStoreProvider.notifier).seedDemoJourney();
      await container.read(communityStoreProvider.notifier).retryFeed();
      final before = repliesIn(container).length;

      final sent = await container
          .read(communityStoreProvider.notifier)
          .addReply('p1', 'sent from a tunnel');

      expect(sent, isTrue);
      expect(repliesIn(container).length, before + 1);
    });
  });
}

/// Answers `addReply` the way a dead connection does.
class _OfflineReplies extends _RecordingCommunity {
  _OfflineReplies(super.posts);

  @override
  Future<void> addReply(String postId, Reply reply) async =>
      throw const NoConnectionException();
}
