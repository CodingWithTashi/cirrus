import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/api/firebase/push_messages.dart';
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

  @override
  Future<void> ensureChannels() async {}

  void dispose() {
    opened.close();
    foreground.close();
    tokens.close();
  }
}
