import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/utils/lp_review.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// The store-rating ask, where it lives now and how it behaves there.
///
/// App Store review rejected 1.0.16 on Sep 11 2026 (Guideline 5.6.3) for
/// asking during onboarding. The ask is on the Survived screen behind
/// `ReviewAskPolicy`; these pin what a reviewer would see on a fresh account
/// (nothing), what an engaged user sees (one honest card), and the two rules
/// that carried over from the old step: no star picker, and no claim about
/// what happened after the tap.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  /// Fri Sep 11 2026, mid-afternoon.
  final now = DateTime(2026, 9, 11, 14, 12);

  JourneyState journey({int day = 5, int cravings = 3}) =>
      journeyOnDay(day, now: now).copyWith(cravingsSurvivedTotal: cravings);

  Future<ProviderContainer> boot(
    WidgetTester tester, {
    required JourneyState journey,
    ReviewRoute route = ReviewRoute.sheet,
    void Function(ProviderContainer)? before,
  }) async {
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(now: now),
        reviewRouteProvider.overrideWith((_) async => route),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).replaceForTest(journey);
    before?.call(container);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    return container;
  }

  /// Never `pumpAndSettle` here: the confetti runs for as long as the screen
  /// is up.
  Future<void> openSurvived(WidgetTester tester, ProviderContainer c) async {
    c.read(routerProvider).go(Routes.survived);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('an engaged user is asked, once, plainly', (tester) async {
    final c = await boot(tester, journey: journey());
    await openSurvived(tester, c);

    expect(find.text(l10n.reviewAskTitle), findsOneWidget);
    expect(find.text(l10n.reviewAskCta), findsOneWidget);
    expect(find.text(l10n.commonNotNow), findsOneWidget);
    // Review gating is prohibited on both stores: the first question the
    // person is asked has to be the OS's own. No stars anywhere on the screen.
    expect(find.textContaining('★'), findsNothing);
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
  });

  testWidgets('the reviewer\'s account — day 1, one craving — sees no ask', (
    tester,
  ) async {
    // The path the rejection describes: install, onboard, beat a craving.
    final c = await boot(tester, journey: journey(day: 1, cravings: 1));
    await openSurvived(tester, c);

    expect(find.text(l10n.survivedPlusOne), findsOneWidget);
    expect(find.text(l10n.reviewAskTitle), findsNothing);
    expect(find.text(l10n.reviewAskCta), findsNothing);
  });

  testWidgets('day 2 with many cravings is still too early', (tester) async {
    final c = await boot(tester, journey: journey(day: 2, cravings: 12));
    await openSurvived(tester, c);
    expect(find.text(l10n.reviewAskTitle), findsNothing);
  });

  testWidgets('day 5 with two cravings is not yet a habit', (tester) async {
    final c = await boot(tester, journey: journey(cravings: 2));
    await openSurvived(tester, c);
    expect(find.text(l10n.reviewAskTitle), findsNothing);
  });

  testWidgets('"Not now" is remembered, and holds', (tester) async {
    final c = await boot(tester, journey: journey());
    await openSurvived(tester, c);
    expect(find.text(l10n.reviewAskTitle), findsOneWidget);

    await tester.tap(find.text(l10n.commonNotNow));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(l10n.reviewAskTitle), findsNothing);
    final settings = c.read(settingsStoreProvider);
    expect(settings.reviewAskedCount, 1);
    expect(settings.reviewAskedAt, now);

    // The next craving, same fortnight: still no.
    c.read(routerProvider).go(Routes.home);
    await tester.pump();
    await tester.pumpAndSettle();
    await openSurvived(tester, c);
    expect(find.text(l10n.survivedPlusOne), findsOneWidget);
    expect(find.text(l10n.reviewAskTitle), findsNothing);
  });

  testWidgets('"Rate Cirrus" records the ask and claims nothing after', (
    tester,
  ) async {
    final c = await boot(tester, journey: journey());
    await openSurvived(tester, c);

    await tester.tap(find.text(l10n.reviewAskCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Neither OS reports whether its sheet appeared, so there is nothing
    // honest to say — no "thanks for rating", no snack, no second screen.
    expect(c.read(settingsStoreProvider).reviewAskedCount, 1);
    expect(find.text(l10n.reviewAskTitle), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text(l10n.survivedPlusOne), findsOneWidget);
  });

  testWidgets('a device asked twice is never asked again', (tester) async {
    final c = await boot(
      tester,
      journey: journey(day: 60, cravings: 40),
      before: (c) {
        final store = c.read(settingsStoreProvider.notifier);
        store.markReviewAsked(DateTime(2026, 6, 1));
        store.markReviewAsked(DateTime(2026, 7, 1));
      },
    );
    await openSurvived(tester, c);
    expect(find.text(l10n.reviewAskTitle), findsNothing);
  });

  testWidgets('no card when a tap would go nowhere', (tester) async {
    // Desktop, a phone without a store, `flutter test` on the real plugin.
    // A dead button is worse than none.
    final c = await boot(tester, journey: journey(), route: ReviewRoute.none);
    await openSurvived(tester, c);
    expect(find.text(l10n.reviewAskTitle), findsNothing);
    expect(find.text(l10n.reviewAskCta), findsNothing);
  });

  group('Settings carries the person\'s own way to rate', () {
    // The rows are a lazy `ListView`; the link rows sit at the bottom, so
    // the page has to be scrolled to the support row (which is always there)
    // before either assertion means anything.
    Future<void> openSettingsFooter(
      WidgetTester tester,
      ProviderContainer c,
    ) async {
      c.read(routerProvider).go(Routes.settings);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(l10n.settingsSupport),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a row, when a store can open', (tester) async {
      final c = await boot(tester, journey: journey(day: 1, cravings: 0));
      await openSettingsFooter(tester, c);
      expect(find.text(l10n.reviewAskCta), findsOneWidget);
    });

    testWidgets('no row when nothing would open', (tester) async {
      final c = await boot(
        tester,
        journey: journey(day: 1, cravings: 0),
        route: ReviewRoute.none,
      );
      await openSettingsFooter(tester, c);
      expect(find.text(l10n.settingsSupport), findsOneWidget);
      expect(find.text(l10n.reviewAskCta), findsNothing);
    });
  });
}
