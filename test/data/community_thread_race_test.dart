import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/repositories/api_community_repository.dart';
import 'package:last_puff/data/stores/community_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart';

/// A notification opens its thread while the feed is still loading
/// (docs/10 §40).
///
/// On a cold start the shell warms the feed (`AppShell`'s `ref.listen`) and the
/// tapped notification opens its thread (`PostDetailScreen`'s post-frame
/// `ensurePost`) within a frame of each other. Two orders lost the reply the
/// notification was about. When the feed finished second, it replaced the list
/// with a page that carries no reply bodies on the real backend — and a post
/// older than the page read "That thread is gone". When the feed landed while
/// the thread read was still on the wire (the order the Pixel 8 caught), the
/// read appended a second copy of the post behind the feed's reply-less one,
/// and the screen found the reply-less copy first. Pull-to-refresh fixed both,
/// which is why it looked intermittent.
///
/// The fake backend answers reads in call order and ships reply bodies in its
/// feed, so nothing in the suite could lose either race. [_WarmFeed] restores
/// the production facts that do, and gates both reads.
class _WarmFeed extends ApiCommunityRepository {
  _WarmFeed(super.api);

  /// Holds the feed read on the wire until the test lets it land.
  Completer<void> gate = Completer<void>();

  /// Holds the thread read on the wire; open unless a test closes it.
  Completer<void> threadGate = Completer<void>()..complete();

  /// A post the page does not include — older than its 50.
  String? outOfPage;

  /// A post the thread read finds gone.
  String? goneOnRead;

  @override
  Future<List<Post>> fetchPosts() async {
    await gate.future;
    return [
      for (final p in await super.fetchPosts())
        if (p.id != outOfPage)
          // Counts, never bodies: `FirebaseCommunityRepository.fetchPosts`.
          p.copyWith(replies: const [], replyCount: p.replyTotal),
    ];
  }

  @override
  Future<Post?> fetchPost(String postId) async {
    await threadGate.future;
    return postId == goneOnRead ? null : super.fetchPost(postId);
  }
}

const _reply = 'you got this, day one is the hardest';

void main() {
  Future<(ProviderContainer, _WarmFeed, String)> coldStart() async {
    late _WarmFeed repo;
    final c = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        communityRepositoryProvider.overrideWith(
          (ref) => repo = _WarmFeed(ref.watch(communityApiProvider)),
        ),
      ],
    );
    addTearDown(c.dispose);
    final raw = await c.read(communityApiProvider).fetchPosts();
    final id = raw.first['id'] as String;
    // The reply the notification is about.
    c.read(fakeServerProvider).updatePost(id, (p) {
      p['replies'] = [
        ...(p['replies'] as List? ?? []),
        {
          'id': 'srv-new',
          'alias': '@wildowl78',
          'avatarEmoji': '🦉',
          'text': _reply,
          'isMine': false,
        },
      ];
    });
    // The shell warms the feed; its read is still on the wire.
    c.read(communityStoreProvider);
    return (c, repo, id);
  }

  Future<void> land(_WarmFeed repo) async {
    repo.gate.complete();
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Post? thread(ProviderContainer c, String id) =>
      c.read(communityStoreProvider).posts.where((p) => p.id == id).firstOrNull;

  List<String?> replies(ProviderContainer c, String id) => [
    for (final r in thread(c, id)?.replies ?? const <Reply>[]) r.text,
  ];

  test('a feed that lands after the thread keeps the new reply', () async {
    final (c, repo, id) = await coldStart();
    await c.read(communityStoreProvider.notifier).ensurePost(id);
    expect(replies(c, id), contains(_reply));

    await land(repo);

    expect(
      replies(c, id),
      contains(_reply),
      reason: 'the feed read began before the thread read and must not win',
    );
    expect(c.read(communityStoreProvider).status, FeedStatus.ready);
  });

  test(
    'a feed that lands while the thread is still reading leaves one copy',
    () async {
      // The order the Pixel 8 caught: the thread read starts before the feed
      // has loaded anything, the feed lands mid-read, the thread lands last.
      // The read used to decide "not in the list" when it STARTED, and append.
      final (c, repo, id) = await coldStart();
      repo.threadGate = Completer<void>();
      final store = c.read(communityStoreProvider.notifier);

      final open = store.ensurePost(id);
      await land(repo);
      repo.threadGate.complete();
      await open;

      final copies = c
          .read(communityStoreProvider)
          .posts
          .where((p) => p.id == id);
      expect(
        copies,
        hasLength(1),
        reason: "the feed's copy must be replaced, not joined",
      );
      expect(replies(c, id), contains(_reply));
    },
  );

  test('a thread older than the page survives the feed landing', () async {
    final (c, repo, id) = await coldStart();
    repo.outOfPage = id;
    await c.read(communityStoreProvider.notifier).ensurePost(id);

    await land(repo);

    expect(
      thread(c, id),
      isNotNull,
      reason: 'it must not turn into "That thread is gone"',
    );
    expect(replies(c, id), contains(_reply));
  });

  test(
    'a thread the read found gone is not brought back by the page',
    () async {
      final (c, repo, id) = await coldStart();
      repo.goneOnRead = id;
      await c.read(communityStoreProvider.notifier).ensurePost(id);

      await land(repo);

      expect(thread(c, id), isNull);
      expect(c.read(communityStoreProvider).threads[id], FeedStatus.ready);
    },
  );

  test(
    'a page read after the thread keeps the replies already loaded',
    () async {
      // The ordinary order: the feed refreshes after the thread was read. Its
      // counts are newer, but it carries no bodies, and blanking a thread it
      // never read would flash an empty thread on the next open.
      final (c, repo, id) = await coldStart();
      await land(repo);
      final store = c.read(communityStoreProvider.notifier);
      await store.ensurePost(id);

      repo.gate = Completer<void>();
      final refresh = store.refreshFeed();
      await land(repo);
      await refresh;

      expect(replies(c, id), contains(_reply));
    },
  );
}
