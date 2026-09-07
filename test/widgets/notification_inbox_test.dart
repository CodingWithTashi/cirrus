import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/core/widgets/lp_misc.dart';
import 'package:last_puff/features/notifications/notifications_screen.dart';

import '../helpers.dart';

/// The in-app inbox and the badge that points at it.
///
/// Why it exists at all: a push is a courtesy that may never arrive. Somebody
/// declined the permission, has no device registered, spent the day's buzz
/// budget, or swiped the shade clear on the bus. All of them still had
/// somebody answer them, and the inbox is the only surface that can say so.
void main() {
  /// The fallback font overflows where the device does not.
  void ignoreFontWidthOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  Future<ProviderContainer> openHome(WidgetTester tester) async {
    final container = ProviderContainer(overrides: fastBackendOverrides());
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
    container.read(routerProvider).go(Routes.home);
    await tester.pumpAndSettle();
    return container;
  }

  /// Posts as this account, then has somebody else reply to it — which is
  /// what the real backend turns into a notification.
  ///
  /// The post is created here rather than taken from the seed, because the
  /// seeded feed is other people's: `notifyPostAuthor` needs an author it
  /// actually recorded, exactly as `postAuthors` works in production.
  ///
  /// The future is pumped rather than plainly awaited: the fake server
  /// answers through a zero-length delay, and a zero-length timer under
  /// `testWidgets` only fires when the tester pumps. Awaiting it directly is
  /// a deadlock — the same one the fake coach's "thinking" timer causes.
  Future<String> myPost(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    final repo = container.read(communityRepositoryProvider);
    final pending = repo.addPost(
      Post(
        id: 'local-1',
        alias: '@quietfox42',
        avatarEmoji: '🦊',
        dayN: 12,
        tag: PostTag.win,
        text: 'twelve days and the mornings are easier',
        createdAt: DateTime(2026, 9, 6),
      ),
    );
    await tester.pumpAndSettle();
    return (await pending)!;
  }

  Future<void> replyTo(
    WidgetTester tester,
    ProviderContainer container,
    String postId, {
    String replyId = 'r1',
    String alias = '@brightmoth17',
    String text = 'this helped me too',
  }) async {
    final pending = container.read(communityRepositoryProvider).addReply(
      postId,
      Reply(
        id: replyId,
        alias: alias,
        avatarEmoji: '🦋',
        text: text,
      ),
    );
    await tester.pumpAndSettle();
    await pending;
    await tester.pumpAndSettle();
  }

  testWidgets('the badge is absent when nothing is waiting', (tester) async {
    final container = await openHome(tester);

    expect(find.byType(NotificationBell), findsOneWidget);
    // A badge is a claim that something is waiting. At zero it must not make
    // one — no "0", nothing at all.
    expect(container.read(notificationsStoreProvider).unread, 0);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('a reply on my post raises the badge', (tester) async {
    final container = await openHome(tester);
    await replyTo(tester, container, await myPost(tester, container));

    expect(container.read(notificationsStoreProvider).unread, 1);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('a busy thread is ONE row, not one per reply', (tester) async {
    // The inbox is keyed by the same tag the shade is, so twenty answers on
    // one post occupy one line in both places.
    final container = await openHome(tester);
    final postId = await myPost(tester, container);
    for (var i = 0; i < 4; i++) {
      await replyTo(tester, container, postId, replyId: 'r$i');
    }

    expect(container.read(notificationsStoreProvider).items, hasLength(1));
    expect(container.read(notificationsStoreProvider).unread, 1);
  });

  testWidgets('a reply that tags somebody else is not my news', (tester) async {
    // The demo backend mirrors `notifyReply`'s branch: a reply that names
    // people is addressed to THEM, so the post's author is not told. Marking
    // read first is what makes it visible — the inbox is keyed by thread, so
    // a wrongly-filed row shows up as the badge coming back rather than as a
    // second line.
    final container = await openHome(tester);
    final postId = await myPost(tester, container);
    await replyTo(tester, container, postId);
    container.read(notificationsStoreProvider.notifier).markAllRead();
    await tester.pumpAndSettle();
    expect(container.read(notificationsStoreProvider).unread, 0);

    await replyTo(
      tester,
      container,
      postId,
      replyId: 'r2',
      alias: '@calmotter9',
      text: '@brightmoth17 that is exactly it',
    );

    expect(container.read(notificationsStoreProvider).unread, 0);
    expect(container.read(notificationsStoreProvider).items, hasLength(1));
  });

  testWidgets('a reply that tags ME arrives as a mention, on its own row', (
    tester,
  ) async {
    // A mention is the one community notification that never collapses, so it
    // is keyed by the reply rather than by the thread.
    final container = await openHome(tester);
    final postId = await myPost(tester, container);
    await replyTo(tester, container, postId);
    await replyTo(
      tester,
      container,
      postId,
      replyId: 'r2',
      alias: '@calmotter9',
      text: '@quietfox42 how did week 2 go',
    );

    final items = container.read(notificationsStoreProvider).items;
    expect(items, hasLength(2));
    expect(items.map((n) => n.kind), contains('communityMention'));
    expect(items.where((n) => n.id == 'mention:r2'), hasLength(1));
  });

  testWidgets('answering my own post tells me nothing', (tester) async {
    // The server compares uids; the fake has one session, so an alias match
    // asks the same question. Either way, being told about yourself is the
    // first thing `notifyReply` refuses to do.
    final container = await openHome(tester);
    final postId = await myPost(tester, container);
    await replyTo(
      tester,
      container,
      postId,
      alias: '@quietfox42',
      text: 'update: still here, still ok',
    );

    expect(container.read(notificationsStoreProvider).items, isEmpty);
  });

  testWidgets('tapping the bell opens the inbox and clears the badge', (
    tester,
  ) async {
    final container = await openHome(tester);
    await replyTo(tester, container, await myPost(tester, container));
    expect(container.read(notificationsStoreProvider).unread, 1);

    await tester.tap(find.byType(NotificationBell));
    await tester.pumpAndSettle();

    expect(
      container.read(routerProvider).state.uri.path,
      Routes.notifications,
    );
    expect(find.text('Someone replied'), findsOneWidget);
    // Opening the screen IS reading them.
    expect(container.read(notificationsStoreProvider).unread, 0);
  });

  testWidgets('the read state survives the fake backend answering again', (
    tester,
  ) async {
    // The store marks read optimistically and the server is told through
    // `syncUserContext`. If that write were dropped, the next emission from
    // the repository would bring the unread row straight back.
    final container = await openHome(tester);
    await replyTo(tester, container, await myPost(tester, container));
    container.read(notificationsStoreProvider.notifier).markAllRead();
    await tester.pumpAndSettle();

    expect(container.read(notificationsStoreProvider).unread, 0);
    // Force a fresh emission from the fake server.
    container.read(fakeServerProvider).markNotificationsRead(const [], 0);
    await tester.pumpAndSettle();
    expect(container.read(notificationsStoreProvider).unread, 0);
  });

  testWidgets('an empty inbox says so rather than showing a spinner', (
    tester,
  ) async {
    final container = await openHome(tester);
    container.read(routerProvider).go(Routes.notifications);
    await tester.pumpAndSettle();

    expect(find.text('Nothing yet'), findsOneWidget);
  });

  testWidgets('a row opens the thread it names', (tester) async {
    final container = await openHome(tester);
    await replyTo(tester, container, await myPost(tester, container));
    final route = container
        .read(notificationsStoreProvider)
        .items
        .first
        .route!;

    container.read(routerProvider).go(Routes.notifications);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Someone replied'));
    await tester.pumpAndSettle();

    expect(container.read(routerProvider).state.uri.path, route);
  });

  testWidgets('back from the inbox works when a link opened it', (
    tester,
  ) async {
    // `GoRouter.pop()` throws on an empty stack rather than doing nothing.
    final container = await openHome(tester);
    container.read(routerProvider).go(Routes.notifications);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackChevron).first);
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, Routes.home);
  });
}
