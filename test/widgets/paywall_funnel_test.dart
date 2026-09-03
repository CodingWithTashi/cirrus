import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

/// What the paywall can actually be measured by (docs/12 §4.5).
///
/// Three things were dark before this. `variant` was the constant
/// `'d5_default'`, so every chart cut by it had exactly one bucket. Nothing
/// reported which plan card people *considered* — only the one they bought.
/// And `purchase_cancelled` fires only once the STORE sheet has opened, so
/// backing out of the paywall itself was invisible: for the launch paywall,
/// which nobody asked for, that is precisely the number that says whether it
/// is a door or a nag.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void ignoreFontWidthOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  /// The app on the paywall, reached through [source], as a free account with
  /// the seeded day-12 journey.
  Future<ProviderContainer> openPaywall(
    WidgetTester tester,
    RecordingAnalytics analytics, {
    String source = 'insight',
    Set<PlanPeriod>? offering,
  }) async {
    ignoreFontWidthOverflow();
    final container = ProviderContainer(
      overrides: fastBackendOverrides(premium: false, analytics: analytics),
    );
    addTearDown(container.dispose);
    if (offering != null) {
      container.read(fakeServerProvider).offeringPeriods = offering;
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    // PUSHED, not `go`: every real door pushes (`context.push`), so the
    // paywall has something underneath it and closing it is a pop.
    unawaited(container.read(routerProvider).push(Routes.paywallFrom(source)));
    await tester.pumpAndSettle();
    return container;
  }

  /// Scrolls [finder] into the viewport — the paywall is a long scroller and
  /// the plan cards sit below the fold on a test-sized screen.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    final scrollables = find.ancestor(
      of: finder,
      matching: find.byType(Scrollable),
    );
    if (scrollables.evaluate().isEmpty) return;
    await tester.scrollUntilVisible(finder, 120, scrollable: scrollables.first);
    await tester.pumpAndSettle();
  }

  testWidgets('the view carries its door and where they are in their quit', (
    tester,
  ) async {
    final analytics = RecordingAnalytics();
    final container = await openPaywall(tester, analytics);

    final view = analytics
        .propsOfAll('paywall_viewed')
        .lastWhere((p) => p['source'] == 'insight');
    expect(view['variant'], 'd5_default');
    // A day-3 gate and a day-40 gate are different questions asked of
    // different people; they used to land in the same row.
    expect(
      view['plan_day'],
      container.read(quitStoreProvider)!.plan.dayNumber(
        container.read(nowProvider)(),
      ),
    );
  });

  testWidgets('a paywall with no live prices says so in the variant', (
    tester,
  ) async {
    // This happens in production — a store hiccup, a storefront with nothing
    // configured — and the typed fallbacks under their "prices unavailable"
    // caption are a materially different offer that converts differently.
    // With one hardcoded variant it was indistinguishable from a normal view.
    final analytics = RecordingAnalytics();
    await openPaywall(tester, analytics, offering: const {});

    expect(
      analytics
          .propsOfAll('paywall_viewed')
          .lastWhere((p) => p['source'] == 'insight')['variant'],
      'd5_fallback',
    );
  });

  testWidgets('choosing a card reports what was considered', (tester) async {
    final analytics = RecordingAnalytics();
    await openPaywall(tester, analytics);

    await reveal(tester, find.text(l10n.paywallMonthly));
    await tester.tap(find.text(l10n.paywallMonthly));
    await tester.pumpAndSettle();

    expect(analytics.propsOfAll('plan_selected'), [
      {'period': 'monthly', 'source': 'insight'},
    ]);

    // Re-tapping the card already selected is not a new consideration.
    await tester.tap(find.text(l10n.paywallMonthly));
    await tester.pumpAndSettle();
    expect(analytics.propsOfAll('plan_selected'), hasLength(1));
  });

  testWidgets('backing out of the paywall is reported, with the plan on it', (
    tester,
  ) async {
    final analytics = RecordingAnalytics();
    final container = await openPaywall(tester, analytics, source: 'launch');

    await reveal(tester, find.text(l10n.paywallWeekly));
    await tester.tap(find.text(l10n.paywallWeekly));
    await tester.pumpAndSettle();
    container.read(routerProvider).pop();
    await tester.pumpAndSettle();

    expect(analytics.propsOfAll('paywall_dismissed'), [
      {'source': 'launch', 'plan': 'weekly'},
    ]);
  });

  testWidgets('taking the Free path on purpose is not a dismissal', (
    tester,
  ) async {
    // `free_continued` is that choice's own event. Counting it twice would
    // make the anti-lockout path look like abandonment.
    final analytics = RecordingAnalytics();
    final container = await openPaywall(tester, analytics);

    await reveal(tester, find.text(l10n.paywallFreeLink));
    await tester.tap(find.text(l10n.paywallFreeLink));
    await tester.pumpAndSettle();
    container.read(routerProvider).go(Routes.home);
    await tester.pumpAndSettle();

    expect(analytics.propsOfAll('paywall_dismissed'), isEmpty);
  });

  testWidgets('a paywall closed before the store answered is still counted', (
    tester,
  ) async {
    // Losing it would understate every door's denominator. It gets its own
    // variant, because a spike in it means the store is slow — a conversion
    // problem with a completely different fix from bad copy.
    final analytics = RecordingAnalytics();
    final container = await openPaywall(tester, analytics, offering: const {});
    // Whatever it reported, exactly one view exists for this door.
    expect(
      analytics.propsOfAll('paywall_viewed').where(
        (p) => p['source'] == 'insight',
      ),
      hasLength(1),
    );
    container.read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(
      analytics.propsOfAll('paywall_viewed').where(
        (p) => p['source'] == 'insight',
      ),
      hasLength(1),
      reason: 'a view is reported once, never twice',
    );
  });

  testWidgets('a paywall popped in the same frame still reports its view', (
    tester,
  ) async {
    // The send is deferred a frame so `build` stays side-effect free. A pop
    // inside that frame used to leave the view scheduled-but-unsent AND
    // skipped by the dispose fallback, losing it entirely — and the dispose
    // path itself read `ref`, which Riverpod forbids there.
    final analytics = RecordingAnalytics();
    final container = await openPaywall(tester, analytics, source: 'launch');
    container.read(routerProvider).pop();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      analytics.propsOfAll('paywall_viewed').where(
        (p) => p['source'] == 'launch',
      ),
      hasLength(1),
    );
  });

  group('the push door', () {
    // `Routes.paywall` is in `PushService._allowedRoutes`, so a notification
    // can open the paywall — bare, which the route builder defaults to
    // `direct`, the same value the debug frame map reports. `lp_events.dart`
    // has documented a `push` source all along; nothing ever passed one.
    test('a bare paywall route from a push is tagged', () {
      expect(taggedPushRoute(Routes.paywall), Routes.paywallFrom('push'));
    });

    test('a source the campaign already set is left alone', () {
      // The payload is how a campaign names itself; overwriting it would
      // merge every campaign into one bucket.
      expect(
        taggedPushRoute(Routes.paywallFrom('winback_email')),
        Routes.paywallFrom('winback_email'),
      );
    });

    test('every other destination is untouched', () {
      for (final route in [Routes.home, Routes.coach, Routes.community]) {
        expect(taggedPushRoute(route), route);
      }
    });

    test('an unparseable route is passed through, never crashed on', () {
      // The route is server-supplied. `routeFor` already allow-lists it, but
      // this must not be the thing that throws on a malformed payload.
      expect(taggedPushRoute('::::'), '::::');
    });
  });
}
