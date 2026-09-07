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
  _threadFreshness();

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

/// Opening a thread must SHOW what the notification said arrived.
///
/// `ensurePost` used to open with "return if the feed already holds it" — a
/// load-what-is-missing cache. That is exactly backwards for the one caller
/// that matters: a notification tap means *this thread has just changed*, so
/// the cached-and-therefore-skipped case is the case that most needs a read.
///
/// The symptom was reported from a real device: tap "Someone replied", the
/// thread opens rendering the feed's copy from before the reply existed, and
/// the only thing missing from it is the reply you were just told about. The
/// notification was not merely useless — it was misleading.
void _threadFreshness() {
  /// A reply arriving from somebody else, written straight onto the fake
  /// server the way the real backend writes one — never through the store,
  /// which would optimistically insert it locally and hide the bug.
  void replyOnServer(ProviderContainer c, String postId, String text) {
    c.read(fakeServerProvider).updatePost(postId, (p) {
      p['replies'] = [
        ...(p['replies'] as List? ?? []),
        {
          'id': 'srv-${text.hashCode}',
          'alias': '@wildowl78',
          'avatarEmoji': '🦉',
          'text': text,
          'isMine': false,
        },
      ];
    });
  }

  Future<ProviderContainer> loadedFeed() async {
    final container = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(container.dispose);
    container.read(communityStoreProvider);
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  test('re-reads a thread the feed already holds', () async {
    final c = await loadedFeed();
    final store = c.read(communityStoreProvider.notifier);
    final id = c.read(communityStoreProvider).posts.first.id;
    final before = c.read(communityStoreProvider).posts.first.replies.length;

    replyOnServer(c, id, 'day one is the hardest part hang in there');

    await store.ensurePost(id);
    await Future<void>.delayed(Duration.zero);

    final after = c
        .read(communityStoreProvider)
        .posts
        .firstWhere((p) => p.id == id);
    expect(
      after.replies.length,
      before + 1,
      reason: 'opening a thread must re-read it — this is the notification tap',
    );
    expect(
      after.replies.last.text,
      'day one is the hardest part hang in there',
      reason: 'the new reply must actually be the one rendered',
    );
  });

  test('keeps the feed in order when it replaces a thread', () async {
    // The refresh writes the post back IN PLACE. Appending it instead would
    // shuffle a reverse-chronological feed on every notification tap.
    final c = await loadedFeed();
    final store = c.read(communityStoreProvider.notifier);
    final order = [for (final p in c.read(communityStoreProvider).posts) p.id];
    expect(order.length, greaterThan(1), reason: 'need a multi-post fixture');

    replyOnServer(c, order[1], 'showing up for you');
    await store.ensurePost(order[1]);
    await Future<void>.delayed(Duration.zero);

    expect(
      [for (final p in c.read(communityStoreProvider).posts) p.id],
      order,
      reason: 'a refreshed post must not jump position in the feed',
    );
  });

  test('a thread deleted while we held it stops rendering', () async {
    final c = await loadedFeed();
    final store = c.read(communityStoreProvider.notifier);
    final id = c.read(communityStoreProvider).posts.first.id;

    c.read(fakeServerProvider).posts.removeWhere((p) => p['id'] == id);
    await store.ensurePost(id);
    await Future<void>.delayed(Duration.zero);

    expect(
      c.read(communityStoreProvider).posts.any((p) => p.id == id),
      isFalse,
      reason: 'a stale copy of a deleted thread must not stay on screen',
    );
  });
}
