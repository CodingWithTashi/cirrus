import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/api/firebase/push_messages.dart';
import 'package:last_puff/data/api/firebase/push_service.dart';
import 'package:last_puff/data/stores/providers.dart';

import '../helpers.dart';

/// Where a tapped push lands, in each of the three app states.
///
/// This suite could not exist before `PushMessages`. `_PushSync` used to read
/// `PushService`'s statics and bail out unless the backend was Firebase, and
/// `fastBackendOverrides()` pins every widget test to the fake backend — so
/// nothing here was reachable, including the cold-start path, which is
/// simultaneously the one that mattered most and the one hardest to check by
/// hand.
///
/// The cold start is the case that was broken. The splash spends 1.5s on its
/// branding beat plus `restoreSession()` before it navigates; a push resolves
/// within milliseconds of launch. Navigating first meant the router's redirect
/// ran with no journey restored yet, sent the tap to `/auth`, and popped the
/// splash — whose `_advance()` then returned at its `!mounted` guard and never
/// navigated at all. A signed-in user tapping a notification with the app
/// closed landed on the sign-in screen for the account they were already in.
void main() {
  _foregroundOnSameScreen();

  Future<(ProviderContainer, _FakePush)> open(
    WidgetTester tester, {
    bool viaSplash = false,
    RemoteMessage? initial,
  }) async {
    final push = _FakePush()..initial = initial;
    addTearDown(push.dispose);
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(premium: false),
        pushMessagesProvider.overrideWithValue(push),
      ],
    );
    addTearDown(container.dispose);
    final fake = container.read(fakeServerProvider);
    if (viaSplash) fake.signIn('push@test');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    if (!viaSplash) {
      container.read(quitStoreProvider.notifier).seedDemoJourney();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      container.read(routerProvider).go(Routes.home);
      await tester.pumpAndSettle();
    }
    return (container, push);
  }

  String path(ProviderContainer c) => c.read(routerProvider).state.uri.path;

  RemoteMessage message(String route) =>
      RemoteMessage(data: <String, String>{'route': route});

  testWidgets('a background tap opens the thread it names', (tester) async {
    final (container, push) = await open(tester);
    push.opened.add(message('/community/post/p7'));
    await tester.pumpAndSettle();

    expect(path(container), '/community/post/p7');
  });

  testWidgets('the thread stacks, so its back chevron has somewhere to go', (
    tester,
  ) async {
    // `GoRouter.pop()` THROWS on an empty stack rather than doing nothing, so
    // a `go`-delivered detail screen has a chevron that throws.
    final (container, push) = await open(tester);
    push.opened.add(message('/community/post/p7'));
    await tester.pumpAndSettle();

    container.read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(path(container), Routes.home);
  });

  testWidgets('a cold-start tap waits for the splash and still lands', (
    tester,
  ) async {
    // Set BEFORE the first frame: the post-frame callback that reads it fires
    // within milliseconds of launch, which is the whole point.
    final (container, _) = await open(
      tester,
      viaSplash: true,
      initial: message('/community/post/p7'),
    );
    await tester.pump();
    // Held, not navigated: going now is what used to end on the sign-in
    // screen, because the redirect ran before the session was restored.
    expect(path(container), Routes.splash);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
    expect(path(container), '/community/post/p7');

    // …over Home, so closing it does not land back on the splash.
    container.read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(path(container), Routes.home);
  });

  testWidgets('a cold-start tap does not spend a launch-paywall slot', (
    tester,
  ) async {
    final (container, _) = await open(
      tester,
      viaSplash: true,
      initial: message('/community/post/p7'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    // The paywall would have been covered by the thread a moment later, and
    // its slots are capped for the lifetime of the account.
    expect(path(container), '/community/post/p7');
    expect(
      container.read(settingsStoreProvider).launchPaywallShownCount,
      0,
    );
  });

  testWidgets('a route we do not accept opens the app and nothing else', (
    tester,
  ) async {
    final (container, push) = await open(tester);
    push.opened.add(message('/settings/secret'));
    await tester.pumpAndSettle();

    expect(path(container), Routes.home);
  });

  testWidgets('a push naming no route at all is harmless', (tester) async {
    final (container, push) = await open(tester);
    push.opened.add(const RemoteMessage());
    await tester.pumpAndSettle();

    expect(path(container), Routes.home);
  });

  testWidgets('a non-thread destination replaces rather than stacking', (
    tester,
  ) async {
    final (container, push) = await open(tester);
    push.opened.add(message(Routes.insight));
    await tester.pumpAndSettle();

    expect(path(container), Routes.insight);
  });

  testWidgets('a foreground push draws a banner that opens the thread', (
    tester,
  ) async {
    final (container, push) = await open(tester);
    push.foreground.add(
      RemoteMessage(
        data: const <String, String>{'route': '/community/post/p7'},
        notification: const RemoteNotification(
          title: 'Someone replied',
          body: 'Go see what they said.',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The banner is drawn rather than the app navigating under the reader.
    expect(path(container), Routes.home);
    expect(find.text('Go see what they said.'), findsOneWidget);

    // `showLpSnack` carries a fallback timer that force-closes at
    // `duration + 250ms`; leaving it pending fails the test binding.
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}

/// A [PushMessages] the test drives by hand.
/// A push that lands while you are ALREADY reading the thread it is about.
///
/// "Open" is the wrong word and the wrong action there. `_openFrom` ends in
/// `_router.push`, so it would stack a second identical copy of the thread on
/// top of the one being read — and neither copy would show the new reply,
/// because neither re-reads on its own. Founder report, Sep 7.
void _foregroundOnSameScreen() {
  Future<(ProviderContainer, _FakePush, String)> onThread(
    WidgetTester tester,
  ) async {
    final push = _FakePush();
    addTearDown(push.dispose);
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(premium: false),
        pushMessagesProvider.overrideWithValue(push),
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

    container.read(communityStoreProvider);
    await tester.pumpAndSettle();
    final id = container.read(communityStoreProvider).posts.first.id;

    // Pushed, not `go`n: a notification-delivered thread sits ON TOP of Home,
    // which is what gives its back chevron somewhere to go. The future it
    // returns completes when the route is popped, so it is deliberately not
    // awaited here.
    unawaited(container.read(routerProvider).push(Routes.communityPost(id)));
    await tester.pumpAndSettle();
    return (container, push, id);
  }

  RemoteMessage reply(String route) => RemoteMessage(
    data: <String, String>{'route': route, 'kind': 'communityReply'},
    notification: const RemoteNotification(
      title: 'Someone replied',
      body: 'Go see what they said.',
    ),
  );

  testWidgets('offers Refresh, not Open, for the thread on screen', (
    tester,
  ) async {
    final (container, push, id) = await onThread(tester);
    expect(
      container.read(routerProvider).state.uri.path,
      Routes.communityPost(id),
    );

    push.foreground.add(reply(Routes.communityPost(id)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Refresh'), findsOneWidget);
    expect(
      find.text('Open'),
      findsNothing,
      reason: 'Open would push a second copy of the thread already on screen',
    );
    // The snack's fallback timer must not outlive the tree.
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('still offers Open for a DIFFERENT thread', (tester) async {
    final (container, push, id) = await onThread(tester);
    final other = container.read(communityStoreProvider).posts
        .firstWhere((p) => p.id != id)
        .id;

    push.foreground.add(reply(Routes.communityPost(other)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Refresh'), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('Refresh acts in place — it never stacks a second copy', (
    tester,
  ) async {
    // The whole point of the branch. `_openFrom` ends in `_router.push`, so
    // "Open" on the screen you are already reading would put an identical
    // thread on top of it: same content, an extra back press to escape, and
    // the new reply in neither copy. Refresh must leave the stack alone.
    //
    // That the re-read itself works is pinned where it can be proven without
    // fighting the fake backend's async: `test/data/community_store_test.dart`
    // ('re-reads a thread the feed already holds'), which goes red against the
    // old load-if-missing `ensurePost`.
    final (container, push, id) = await onThread(tester);
    final router = container.read(routerProvider);

    push.foreground.add(reply(Routes.communityPost(id)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Refresh'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      router.state.uri.path,
      Routes.communityPost(id),
      reason: 'Refresh stays where the reader is',
    );

    // One pop returns to Home. With a stacked duplicate it would land on the
    // thread again, which is exactly what the reader would have felt.
    router.pop();
    await tester.pumpAndSettle();
    expect(
      router.state.uri.path,
      Routes.home,
      reason: 'a second copy of the thread was pushed underneath',
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}

class _FakePush implements PushMessages {
  final opened = StreamController<RemoteMessage>.broadcast();
  final foreground = StreamController<RemoteMessage>.broadcast();
  final tokens = StreamController<String>.broadcast();

  /// The push that cold-started the app, set before the first frame settles.
  RemoteMessage? initial;

  @override
  Stream<RemoteMessage> get onOpened => opened.stream;

  @override
  Stream<RemoteMessage> get onForeground => foreground.stream;

  @override
  Stream<String> get onTokenRefresh => tokens.stream;

  @override
  Future<RemoteMessage?> initialMessage() async => initial;

  /// This suite is about taps, not registration — but the seam carries both,
  /// so answer honestly: no token, never asked. That is the one combination
  /// `PushTokenRegistrar` treats as final and does not retry, which keeps its
  /// backoff timer out of a test that is not about it.
  @override
  Future<String?> token() async => null;

  @override
  Future<PushPermission> permission() async => PushPermission.notAsked;

  @override
  Future<void> ensureChannels() async {}

  void dispose() {
    opened.close();
    foreground.close();
    tokens.close();
  }
}
