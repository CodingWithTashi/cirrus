import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/api/fake/fake_server.dart';
import 'package:last_puff/data/backend_mode.dart';
import 'package:last_puff/data/stores/community_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart';

/// QA H3 (Aug 31 2026, production, three accounts): another user's fresh
/// live post rendered no "⋯" menu — no Report, no Mute, no Block — while
/// older posts showed all three. The controls existed; they were gated on
/// `!post.isMine`, and "mine" was decided by state that outlived the account:
/// a post written by whoever was signed in before stayed "mine" for whoever
/// signed in next on the same device. App Store Guideline 1.2 needs Report
/// and Block on EVERY piece of someone else's content from the moment it is
/// visible, so ownership has to be per account and decided by the backend.
///
/// Driven through the fake backend, which carried the same defect in a purer
/// form: `isMine: true` was written INTO the post on the wire, so every
/// reader of the store was its author.
void main() {
  late FakeServer server;

  setUp(() => server = FakeServer(latency: Duration.zero));

  /// One "app session": its own container, sharing the one backend.
  Future<ProviderContainer> session(String email) async {
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        backendModeProvider.overrideWithValue(BackendMode.fake),
        fakeServerProvider.overrideWithValue(server),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(quitStoreProvider.notifier)
        .logIn(email: email, password: 'secret1');
    container.read(communityStoreProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(communityStoreProvider).status, FeedStatus.ready);
    return container;
  }

  Post? findPost(ProviderContainer c, String text) => c
      .read(communityStoreProvider)
      .posts
      .where((p) => p.text == text)
      .firstOrNull;

  test("another account's post is not mine — report stays available", () async {
    const text = 'day 1, terrified, but here';

    final a = await session('a@quitmail.com');
    a
        .read(communityStoreProvider.notifier)
        .addPost(text: text, tag: PostTag.day1);
    await Future<void>.delayed(Duration.zero);
    expect(
      findPost(a, text)?.isMine,
      isTrue,
      reason: 'the author sees it as theirs',
    );
    a.read(quitStoreProvider.notifier).signOut();
    await Future<void>.delayed(Duration.zero);

    final b = await session('b@quitmail.com');
    final seenByB = findPost(b, text);
    expect(seenByB, isNotNull, reason: "B's feed must carry A's live post");
    expect(
      seenByB!.isMine,
      isFalse,
      reason: "A's post must be reportable from B's account",
    );
  });

  test('ownership survives a cold restart of the same account', () async {
    const text = 'week two and the mornings are easier';

    final first = await session('a@quitmail.com');
    first
        .read(communityStoreProvider.notifier)
        .addPost(text: text, tag: PostTag.win);
    await Future<void>.delayed(Duration.zero);
    first.read(quitStoreProvider.notifier).signOut();
    await Future<void>.delayed(Duration.zero);

    // A new process: nothing remembered on the client.
    final again = await session('a@quitmail.com');
    expect(
      findPost(again, text)?.isMine,
      isTrue,
      reason: 'the backend, not the session, knows whose post this is',
    );
  });
}
