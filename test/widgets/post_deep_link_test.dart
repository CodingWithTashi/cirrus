import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:last_puff/core/widgets/lp_error.dart';
import 'package:last_puff/core/widgets/lp_misc.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';

import '../helpers.dart';

/// Opening one post directly, which is what a notification does.
///
/// `PostDetailScreen` used to read its post out of the loaded feed and render
/// `Scaffold(body: SizedBox.shrink())` when it was not there — a blank screen
/// with no app bar, no spinner, no message and no way back. That was not an
/// edge case for a push: the feed is one bounded page, and a reply can arrive
/// days after its post has scrolled out of it.
void main() {
  /// The fallback font overflows where the device does not — same rule as
  /// `screen_layout_test`.
  void ignoreFontWidthOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  Future<ProviderContainer> open(
    WidgetTester tester,
    CommunityRepository repo,
    String postId,
  ) async {
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        communityRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    container.read(routerProvider).go(Routes.communityPost(postId));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('a post outside the loaded feed is fetched and shown', (
    tester,
  ) async {
    ignoreFontWidthOverflow();
    await open(tester, _StubCommunity(one: _post('far-back')), 'far-back');

    expect(find.text('a post the feed never loaded'), findsOneWidget);
  });

  testWidgets('a post that is gone says so instead of showing nothing', (
    tester,
  ) async {
    ignoreFontWidthOverflow();
    final container = await open(tester, _StubCommunity(), 'deleted');

    expect(find.byType(LpErrorState), findsOneWidget);
    expect(
      container.read(communityStoreProvider).threads['deleted'],
      isNotNull,
    );
  });

  testWidgets('a failed fetch offers a retry rather than a blank screen', (
    tester,
  ) async {
    ignoreFontWidthOverflow();
    await open(tester, _StubCommunity(throws: true), 'p9');

    expect(find.byType(LpErrorState), findsOneWidget);
    expect(find.text('Run it back'), findsOneWidget);
  });

  testWidgets('a post the rules refuse reads as gone, not as a failure', (
    tester,
  ) async {
    // The rule is `resource.data.status == 'live'`, and `resource` is null for
    // a document that is not there — so a missing, blocked or unclassified
    // post answers PERMISSION_DENIED rather than an empty snapshot. That
    // refusal IS the answer. Reading it as a failure put "check your signal"
    // in front of a deleted thread on a device with a fine connection, which
    // is what the emulator pass caught.
    ignoreFontWidthOverflow();
    await open(tester, _StubCommunity(), 'deleted');

    expect(find.text('That thread is gone'), findsOneWidget);
    expect(find.text('Run it back'), findsNothing);
  });

  testWidgets('the back chevron works when a push opened the screen', (
    tester,
  ) async {
    // `GoRouter.pop()` THROWS on an empty stack, so this used to be the one
    // control on the screen guaranteed to fail on the path a push takes.
    ignoreFontWidthOverflow();
    final container = await open(
      tester,
      _StubCommunity(one: _post('far-back')),
      'far-back',
    );

    await tester.tap(find.byType(BackChevron).first);
    await tester.pumpAndSettle();
    expect(
      container.read(routerProvider).state.uri.path,
      Routes.community,
    );
  });

  testWidgets('opening a thread tells the server it has been read', (
    tester,
  ) async {
    // What lets the next reply start a fresh notification group rather than
    // adding to a count already seen.
    final context = _RecordingContext();
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        communityRepositoryProvider.overrideWithValue(
          _StubCommunity(one: _post('p3')),
        ),
        userContextRepositoryProvider.overrideWithValue(context),
      ],
    );
    addTearDown(container.dispose);
    ignoreFontWidthOverflow();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    container.read(routerProvider).go(Routes.communityPost('p3'));
    await tester.pumpAndSettle();

    expect(context.read, contains('p3'));
  });
}

Post _post(String id) => Post(
  id: id,
  alias: '@quietfox42',
  avatarEmoji: '🦊',
  dayN: 3,
  tag: PostTag.win,
  text: 'a post the feed never loaded',
  createdAt: DateTime(2026, 9, 1),
);

/// A community backend with an empty feed and, optionally, one findable post.
class _StubCommunity implements CommunityRepository {
  _StubCommunity({this.one, this.throws = false});

  final Post? one;
  final bool throws;

  @override
  Future<List<Post>> fetchPosts() async => const [];

  @override
  Future<Post?> fetchPost(String postId) async {
    if (throws) throw const NoConnectionException();
    return one?.id == postId ? one : null;
  }

  @override
  Future<String?> addPost(Post post) async => post.id;

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
  }) async {}

  @override
  Future<void> blockAuthor(String alias) async {}
}

class _RecordingContext implements UserContextRepository {
  final read = <String>[];

  @override
  Future<void> sync({
    String? fcmToken,
    Map<String, Object?>? pushPrefs,
    List<String>? readThreads,
    List<String>? readNotifications,
  }) async {
    if (readThreads != null) read.addAll(readThreads);
  }

  @override
  Future<void> unregister() async {}
}
