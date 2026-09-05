import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/api/fake/fake_server.dart';
import 'package:last_puff/data/api/firebase/reminder_scheduler.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/data/stores/reminder_coordinator.dart';
import 'package:last_puff/domain/logic/reminder_planner.dart';

import '../helpers.dart';

/// Where a tap on one of our notifications lands.
///
/// The scheduler only reports the tap (`ReminderSink.opened`); the app decides
/// the screen. A trial reminder is about the trial, so it opens the screen
/// that says when it ends and where to manage it; a danger-hour nudge is about
/// the hour ahead, so it opens Home. A tap that arrives while the splash still
/// owns the first screen waits for the splash to decide — the splash ends in
/// a `go` that replaces the stack, and a push before it would simply vanish.
void main() {
  Future<(ProviderContainer, _TapSink)> open(
    WidgetTester tester, {
    Map<String, dynamic>? entitlement,
    bool viaSplash = false,
  }) async {
    final sink = _TapSink();
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(premium: false),
        reminderCoordinatorProvider.overrideWithValue(
          ReminderCoordinator(sink),
        ),
      ],
    );
    addTearDown(container.dispose);
    final fake = container.read(fakeServerProvider);
    if (viaSplash) fake.signIn('tap@test');
    if (entitlement != null) fake.putEntitlement(entitlement);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    if (!viaSplash) {
      container.read(quitStoreProvider.notifier).seedDemoJourney();
      unawaited(
        container
            .read(entitlementProvider.notifier)
            .bindSession(fake.ensureSessionId()),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      container.read(routerProvider).go(Routes.home);
      await tester.pumpAndSettle();
    }
    return (container, sink);
  }

  String path(ProviderContainer c) => c.read(routerProvider).state.uri.path;

  Map<String, dynamic> trial() => {
    'tier': 'trial',
    'productId': 'yearly_3999',
    'expiresAt': DateTime.now()
        .add(const Duration(days: 2))
        .toUtc()
        .toIso8601String(),
    'willRenew': true,
  };

  testWidgets('a trial reminder opens the trial-ending screen', (tester) async {
    final (container, sink) = await open(tester, entitlement: trial());
    sink.taps.add(ReminderKind.trial);
    await tester.pumpAndSettle();
    expect(path(container), Routes.trialEnding);
  });

  testWidgets('once the trial is over, the same tap lands on Settings', (
    tester,
  ) async {
    // Converted (or lapsed) between the alarm being set and the tap: the
    // trial-ending screen would talk about a trial that no longer exists.
    final (container, sink) = await open(
      tester,
      entitlement: FakeServer.demoEntitlementJson(DateTime.now()),
    );
    sink.taps.add(ReminderKind.trial);
    await tester.pumpAndSettle();
    expect(path(container), Routes.settings);
  });

  testWidgets('a danger-hour nudge lands on Home from anywhere', (
    tester,
  ) async {
    final (container, sink) = await open(tester);
    container.read(routerProvider).go(Routes.stats);
    await tester.pumpAndSettle();
    sink.taps.add(ReminderKind.danger);
    await tester.pumpAndSettle();
    expect(path(container), Routes.home);
  });

  testWidgets('a milestone celebration opens the badge grid', (tester) async {
    final (container, sink) = await open(tester);
    sink.taps.add(ReminderKind.milestone);
    await tester.pumpAndSettle();
    expect(path(container), Routes.milestones);
  });

  testWidgets('a milestone tap PUSHES, so the badge grid can be left', (
    tester,
  ) async {
    // Milestones is a pushed detail screen with a back chevron. A `go` would
    // land there with nothing to go back to.
    final (container, sink) = await open(tester);
    sink.taps.add(ReminderKind.milestone);
    await tester.pumpAndSettle();
    expect(path(container), Routes.milestones);

    container.read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(path(container), Routes.home);
  });

  testWidgets('a tap that cold-started the app waits for the splash', (
    tester,
  ) async {
    final (container, sink) = await open(
      tester,
      entitlement: trial(),
      viaSplash: true,
    );
    expect(path(container), Routes.splash);
    sink.taps.add(ReminderKind.trial);
    await tester.pump();
    // Nothing pushed over the splash; the tap is held.
    expect(path(container), Routes.splash);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
    expect(path(container), Routes.trialEnding);
    // …over Home, so closing it does not land back on the splash.
    container.read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(path(container), Routes.home);
  });
}

class _TapSink implements ReminderSink {
  final taps = StreamController<ReminderKind>.broadcast();

  @override
  Stream<ReminderKind> get opened => taps.stream;

  @override
  Future<void> apply(
    List<ReminderSlot> slots, {
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> scheduleOnce(
    OneShotReminder reminder, {
    required ReminderKind kind,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}
}
