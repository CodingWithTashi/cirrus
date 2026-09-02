import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/network/connectivity.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart';

/// What the author sees under their own post, and when (docs/09 issue 6).
///
/// The Sep 1 field test posted from a phone and read "In review — only you
/// can see this" under a clean post, because the one line the feed had
/// covered both "the backend has not answered yet" and "a human must look".
/// A post that the network never carried sat on the same line forever, which
/// read as a stuck screen. Four states now, each with its own words, and the
/// one that is the phone's fault carries the retry.
void main() {
  Future<ProviderContainer> feed({bool online = true}) async {
    final container = ProviderContainer(
      overrides: fastBackendOverrides(online: online),
    );
    addTearDown(container.dispose);
    container.read(communityStoreProvider);
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  Post mine(ProviderContainer c, String text) =>
      c.read(communityStoreProvider).posts.firstWhere((p) => p.text == text);

  test('a clean post is posting for a beat, then live — never held', () async {
    final c = await feed();
    const text = 'day 4, still here';
    c.read(communityStoreProvider.notifier).addPost(
      text: text,
      tag: PostTag.vent,
    );
    // Optimistic insert: the wait for a verdict is `pending`, which renders
    // as "Posting…" — not "In review".
    expect(mine(c, text).status, PostStatus.pending);

    await pumpEventQueue();
    expect(mine(c, text).status, PostStatus.live);
  });

  test('a post that breaks the community rules comes back held', () async {
    final c = await feed();
    const text = 'the new elf bar watermelon is honestly amazing';
    c.read(communityStoreProvider.notifier).addPost(
      text: text,
      tag: PostTag.win,
    );
    await pumpEventQueue();
    // `held`, not `pending`: this is the verdict, not the wait for one.
    expect(mine(c, text).status, PostStatus.held);
  });

  test('offline, the post fails honestly and retry sends it once online', () async {
    final c = await feed(online: false);
    final store = c.read(communityStoreProvider.notifier);
    const text = 'lost my charger. best day of the week.';
    store.addPost(text: text, tag: PostTag.win);
    await pumpEventQueue();
    // Not "Posting…" forever: the network never carried it, and the row
    // says so with the retry on it.
    expect(mine(c, text).status, PostStatus.failed);

    (c.read(connectivityProvider.notifier) as ToggleConnectivity).set(true);
    store.retryPost(mine(c, text).id);
    expect(mine(c, text).status, PostStatus.pending);
    await pumpEventQueue();
    expect(mine(c, text).status, PostStatus.live);
  });

  test('a post the server refuses at the door is blocked, with no retry', () async {
    final c = await feed();
    final store = c.read(communityStoreProvider.notifier);
    const text = 'quit? not with these faggots cheering';
    store.addPost(text: text, tag: PostTag.vent);
    await pumpEventQueue();
    expect(mine(c, text).status, PostStatus.blocked);
    // It never claimed a slot, so it does not count toward the cap...
    expect(store.myPostsToday, 0);
    // ...and a retry would only be refused again.
    store.retryPost(mine(c, text).id);
    await pumpEventQueue();
    expect(mine(c, text).status, PostStatus.blocked);
  });

  test('retry is only for a post that failed', () async {
    final c = await feed();
    final store = c.read(communityStoreProvider.notifier);
    const text = 'week two';
    store.addPost(text: text, tag: PostTag.milestone);
    await pumpEventQueue();
    expect(mine(c, text).status, PostStatus.live);

    // A live post retried would be a duplicate; a pending one is already on
    // its way; a held one is the server's call.
    store.retryPost(mine(c, text).id);
    await pumpEventQueue();
    expect(mine(c, text).status, PostStatus.live);
    expect(
      c.read(communityStoreProvider).posts.where((p) => p.text == text),
      hasLength(1),
    );
  });
}
