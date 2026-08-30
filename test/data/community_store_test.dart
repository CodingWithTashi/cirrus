import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/community_store.dart';
import 'package:last_puff/data/stores/providers.dart';

import '../helpers.dart';

/// Reporting and blocking — the two reader-side moderation controls
/// (App Store Guideline 1.2).
///
/// Both hide content, and both are easy to get subtly wrong in a way nobody
/// notices: the wrong post disappears, or the right one doesn't.
void main() {
  Future<ProviderContainer> feed() async {
    final container = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(container.dispose);
    container.read(communityStoreProvider);
    // The initial fetch is async even at zero latency.
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(communityStoreProvider).status,
      FeedStatus.ready,
      reason: 'feed did not load',
    );
    return container;
  }

  test('three reports on one post hide it', () async {
    final c = await feed();
    final store = c.read(communityStoreProvider.notifier);
    final id = c.read(communityStoreProvider).posts.first.id;

    store.reportPost(id);
    expect(c.read(communityStoreProvider).posts.first.hidden, isFalse);
    store.reportPost(id);
    expect(c.read(communityStoreProvider).posts.first.hidden, isFalse);
    store.reportPost(id);

    expect(
      c.read(communityStoreProvider).posts.firstWhere((p) => p.id == id).hidden,
      isTrue,
      reason: 'three reports on one post must hide it',
    );
  });

  test('one report each on three posts hides none of them', () async {
    // The bug this pins: the auto-hide counter was a single int across the
    // whole feed, so the third post anyone reported vanished on its FIRST
    // report. Found on device, because it needs three real posts to show up.
    final c = await feed();
    final store = c.read(communityStoreProvider.notifier);
    final ids = c
        .read(communityStoreProvider)
        .posts
        .take(3)
        .map((p) => p.id)
        .toList();
    expect(ids, hasLength(3));

    for (final id in ids) {
      store.reportPost(id);
    }

    final posts = c.read(communityStoreProvider).posts;
    for (final id in ids) {
      expect(
        posts.firstWhere((p) => p.id == id).hidden,
        isFalse,
        reason: 'post $id hid after a single report',
      );
    }
  });

  test('a hidden post leaves the visible feed', () async {
    final c = await feed();
    final store = c.read(communityStoreProvider.notifier);
    final id = c.read(communityStoreProvider).posts.first.id;

    for (var i = 0; i < CommunityStore.autoHideReports; i++) {
      store.reportPost(id);
    }

    expect(
      c.read(communityStoreProvider).visible(DateTime.now()).any((p) => p.id == id),
      isFalse,
      reason: 'a reported-out post must not still be readable',
    );
  });

  test('blocking takes every post by that author, not just the one', () async {
    final c = await feed();
    final store = c.read(communityStoreProvider.notifier);
    final target = c.read(communityStoreProvider).posts.first;

    store.blockAuthor(target.id);

    final visible = c.read(communityStoreProvider).visible(DateTime.now());
    expect(
      visible.any((p) => p.alias == target.alias),
      isFalse,
      reason: 'blocking must remove the author, not a single post',
    );
  });
}
