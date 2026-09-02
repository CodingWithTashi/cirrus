import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/community_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';

import '../helpers.dart';

/// A held post is not the end of the story: `remoderateHeld` re-asks the
/// classifier minutes later, and the founder decides the rest. The author's
/// feed has to keep listening through `held`, or the whole point of the
/// sweeper — minutes, not hours — is invisible to the one person it was
/// built for (docs/09 issue 6, review).
///
/// The fake backend answers a status once, so this drives the store with a
/// repository stub whose status streams stay open.
class _StubRepository implements CommunityRepository {
  _StubRepository({this.initial = const []});

  final List<Post> initial;
  final Map<String, StreamController<PostStatus>> streams = {};

  StreamController<PostStatus> streamFor(String id) =>
      streams[id] ??= StreamController<PostStatus>.broadcast();

  @override
  Future<List<Post>> fetchPosts() async => initial;

  @override
  Future<String?> addPost(Post post) async => 'srv-${post.id}';

  @override
  Stream<PostStatus> watchPostStatus(String postId) => streamFor(postId).stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<(ProviderContainer, _StubRepository)> feed({
    List<Post> initial = const [],
  }) async {
    final repo = _StubRepository(initial: initial);
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        communityRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    container.read(communityStoreProvider);
    await pumpEventQueue();
    expect(container.read(communityStoreProvider).status, FeedStatus.ready);
    return (container, repo);
  }

  Post mine(ProviderContainer c, String text) =>
      c.read(communityStoreProvider).posts.firstWhere((p) => p.text == text);

  test('a post held after posting goes live when the verdict later flips', () async {
    final (c, repo) = await feed();
    const text = 'day one, terrified';
    c.read(communityStoreProvider.notifier).addPost(text: text, tag: PostTag.vent);
    await pumpEventQueue();
    final id = mine(c, text).id;
    expect(id, startsWith('srv-'), reason: 'rebound to the server id');

    // The classifier was down: the mirror says held.
    repo.streamFor(id).add(PostStatus.held);
    await pumpEventQueue();
    expect(mine(c, text).status, PostStatus.held);

    // Fifteen minutes later the sweeper re-asked and published it.
    repo.streamFor(id).add(PostStatus.live);
    await pumpEventQueue();
    expect(mine(c, text).status, PostStatus.live);
  });

  test('a post loaded already held keeps a watch from the start', () async {
    final held = Post(
      id: 'srv-old',
      alias: '@me',
      avatarEmoji: '🔥',
      dayN: 3,
      tag: PostTag.vent,
      text: 'posted last night',
      createdAt: DateTime(2026, 9, 1, 23, 10),
      isMine: true,
      status: PostStatus.held,
    );
    final (c, repo) = await feed(initial: [held]);
    expect(mine(c, 'posted last night').status, PostStatus.held);

    repo.streamFor('srv-old').add(PostStatus.live);
    await pumpEventQueue();
    expect(mine(c, 'posted last night').status, PostStatus.live);
  });

  test('a settled verdict closes the watch', () async {
    final (c, repo) = await feed();
    const text = 'day two';
    c.read(communityStoreProvider.notifier).addPost(text: text, tag: PostTag.win);
    await pumpEventQueue();
    final id = mine(c, text).id;

    repo.streamFor(id).add(PostStatus.blocked);
    await pumpEventQueue();
    expect(mine(c, text).status, PostStatus.blocked);

    // Nobody is listening any more: a stray later event changes nothing.
    repo.streamFor(id).add(PostStatus.live);
    await pumpEventQueue();
    expect(mine(c, text).status, PostStatus.blocked);
  });
}
