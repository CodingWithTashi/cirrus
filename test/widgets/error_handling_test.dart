import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/app_errors.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/network/connectivity.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart';

/// End-to-end coverage of the friendly error surfaces: the offline banner,
/// the offline dialog on lifecycle CTAs, the feed's failed state + retry,
/// the coach's in-thread fallback, the 404 route, and the crash screen.
void main() {
  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    required bool online,
  }) async {
    final container = ProviderContainer(
      overrides: fastBackendOverrides(online: online),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2)); // splash beat
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('offline banner shows offline, hides online', (tester) async {
    final container = await pumpApp(tester, online: false);

    AnimatedSlide slide() => tester.widget<AnimatedSlide>(
      find.ancestor(
        of: find.textContaining('offline —'),
        matching: find.byType(AnimatedSlide),
      ),
    );
    expect(slide().offset, Offset.zero);

    (container.read(connectivityProvider.notifier) as ToggleConnectivity).set(
      true,
    );
    await tester.pumpAndSettle();
    expect(slide().offset, isNot(Offset.zero));
  });

  testWidgets('offline login shows the offline dialog with retry', (
    tester,
  ) async {
    final container = await pumpApp(tester, online: false);
    container.read(routerProvider).go(Routes.login);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'secret1');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('No wifi, no worries'), findsOneWidget);
    expect(find.text('Run it back'), findsOneWidget);

    // Connection comes back → retry from the dialog lands on Home.
    (container.read(connectivityProvider.notifier) as ToggleConnectivity).set(
      true,
    );
    await tester.tap(find.text('Run it back'));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('feed failure shows the error state; retry recovers', (
    tester,
  ) async {
    final container = await pumpApp(tester, online: false);
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    container.read(routerProvider).go(Routes.community);
    await tester.pumpAndSettle();

    expect(find.text('The feed ghosted us'), findsOneWidget);

    (container.read(connectivityProvider.notifier) as ToggleConnectivity).set(
      true,
    );
    await tester.tap(find.text('Run it back'));
    await tester.pumpAndSettle();
    expect(find.text('The feed ghosted us'), findsNothing);
    expect(find.textContaining('gas station'), findsOneWidget);
  });

  test('coach owns a lost connection in-thread, refunds the message', () async {
    final container = ProviderContainer(
      overrides: fastBackendOverrides(online: false),
    );
    addTearDown(container.dispose);
    container.read(quitStoreProvider.notifier).seedDemoJourney();

    await container.read(coachStoreProvider.notifier).send('craving hard');

    final coach = container.read(coachStoreProvider);
    expect(coach.isTyping, isFalse);
    expect(coach.freeUsedToday, 0);
    expect(coach.messages.last.template, CoachTemplate.connectionLost);
  });

  testWidgets('unknown routes land on the friendly dead-end', (tester) async {
    final container = await pumpApp(tester, online: true);
    container.read(routerProvider).go('/definitely-not-a-route');
    await tester.pumpAndSettle();

    expect(find.byType(RouteNotFoundScreen), findsOneWidget);
    expect(find.text("This page doesn't exist"), findsOneWidget);

    await tester.tap(find.text('Take me home'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    // Signed out → sign-in; the test platform (android) shows Google.
    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('a crashed subtree renders the friendly crash screen', (
    tester,
  ) async {
    // Restored before the body ends — the test binding verifies the builder
    // wasn't left changed.
    final previous = ErrorWidget.builder;
    ErrorWidget.builder = LpErrors.crashScreen;
    try {
      await tester.pumpWidget(const MaterialApp(home: _Boom()));
      expect(tester.takeException(), isA<StateError>());
      expect(find.textContaining('awkward'), findsOneWidget);
    } finally {
      ErrorWidget.builder = previous;
    }
  });

  testWidgets('offline is invisible on Home — logging stays optimistic', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: fastBackendOverrides(online: false),
    );
    addTearDown(container.dispose);
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    await tester.tap(find.text('LOG PUFF'));
    await tester.pump(const Duration(milliseconds: 200)); // PressScale beat
    // 52 seeded + 1 — applied instantly even though every save fails offline.
    expect(container.read(todayProvider)!.puffs, 53);

    // Let the undo snack live out its bounded life so no timers leak.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });
}

class _Boom extends StatelessWidget {
  const _Boom();

  @override
  Widget build(BuildContext context) => throw StateError('boom');
}
