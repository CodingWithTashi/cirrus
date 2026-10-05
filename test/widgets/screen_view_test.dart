import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';

import '../helpers.dart';

/// Every screen a person can stand on reports a screen view.
///
/// Two holes were found by reading the production dashboard rather than the
/// code (Oct 5 2026). Across every account that had ever opened the app there
/// was not one `/panic` or `/panic/survived` view, and Home had fewer viewers
/// than the Day-1 checklist that leads to it:
///
/// - The panic takeover, the arena and the Survived screen build their own
///   `CustomTransitionPage`, and go_router only names the pages it builds
///   itself. A page with no name is dropped by `LpAnalyticsObserver`, so the
///   one flow the product exists for left no trace.
/// - `StatefulShellRoute` hands the root navigator a page for the SHELL, which
///   has no path of its own. Landing on a tab by `go` — which is how every
///   account arrives on Home — reported nothing; only a tap on the tab bar did.
void main() {
  Future<(ProviderContainer, RecordingAnalytics)> open(
    WidgetTester tester,
  ) async {
    final analytics = RecordingAnalytics();
    final container = ProviderContainer(
      overrides: fastBackendOverrides(analytics: analytics),
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
    return (container, analytics);
  }

  testWidgets('landing on Home by navigation is a screen view', (tester) async {
    // Nobody taps a tab to get here: the splash sends a restored journey
    // straight to Home, exactly as the Day-1 checklist does when it finishes.
    final (container, analytics) = await open(tester);
    expect(container.read(routerProvider).state.uri.path, Routes.home);

    expect(analytics.screens.where((s) => s == Routes.home), hasLength(1));
    expect(analytics.screens.last, Routes.home);
  });

  testWidgets('a tab reached by navigation is reported once, and going to '
      'the tab already showing is not a new view', (tester) async {
    final (container, analytics) = await open(tester);
    container.read(routerProvider).go(Routes.home);
    await tester.pumpAndSettle();
    analytics.screens.clear();

    container.read(routerProvider).go(Routes.stats);
    await tester.pumpAndSettle();
    expect(analytics.screens, [Routes.stats]);

    // The same tab again is not a new view.
    container.read(routerProvider).go(Routes.stats);
    await tester.pumpAndSettle();
    expect(analytics.screens, [Routes.stats]);
  });

  testWidgets('the panic takeover and the Survived screen are screen views', (
    tester,
  ) async {
    final (container, analytics) = await open(tester);
    container.read(routerProvider).go(Routes.home);
    await tester.pumpAndSettle();
    analytics.screens.clear();

    unawaited(container.read(routerProvider).push(Routes.panic));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(analytics.screens, contains(Routes.panic));

    unawaited(container.read(routerProvider).push(Routes.survived));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(analytics.screens, contains(Routes.survived));
  });

  testWidgets('a screen go_router builds itself was always a screen view', (
    tester,
  ) async {
    // The control: Health reported nothing on the dashboard either, from any
    // account, and this is why that reads as "nobody opened it" rather than
    // as a third hole.
    final (container, analytics) = await open(tester);
    container.read(routerProvider).go(Routes.home);
    await tester.pumpAndSettle();
    analytics.screens.clear();

    unawaited(container.read(routerProvider).push(Routes.health));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(analytics.screens, [Routes.health]);
  });

  testWidgets('the arena is a screen view, and never carries its query', (
    tester,
  ) async {
    final (container, analytics) = await open(tester);
    container.read(routerProvider).go(Routes.home);
    await tester.pumpAndSettle();
    analytics.screens.clear();

    unawaited(container.read(routerProvider).push('${Routes.game}?g=orbs'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(analytics.screens, contains(Routes.game));
    expect(analytics.screens.where((s) => s.contains('?')), isEmpty);
  });
}
