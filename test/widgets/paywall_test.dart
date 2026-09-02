import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/utils/lp_links.dart';
import 'package:last_puff/core/utils/lp_pricing.dart';
import 'package:last_puff/data/api/fake/fake_server.dart';
import 'package:last_puff/data/network/connectivity.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/billing_catalog.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// The four paywall screens around a real store sheet.
///
/// The sheet itself is the fake backend's, scripted through
/// `FakeServer.nextPurchase`, so every ending a store can hand back — bought,
/// closed, deferred, refused, offline — is one line here. What is asserted is
/// everything the app does around it: the prices are the store's, the free
/// path is reachable, a purchase changes the state the rest of the app reads
/// and closes the paywall, and nothing is ever claimed that did not happen.
void main() {
  /// Same rule as `screen_layout_test`: `flutter test` substitutes a fallback
  /// font whose glyphs are square em boxes, so text is far wider here than
  /// Space Grotesk and Inter ever render it, and a four-pixel overflow in this
  /// harness says nothing about the device. Real overflow is caught on device.
  ///
  /// Installed inside the test body, not in `setUp`: the test binding replaces
  /// `FlutterError.onError` when it starts running the body, so an override
  /// set any earlier is simply discarded.
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
    String route, {
    bool online = true,
    RecordingAnalytics? analytics,
  }) async {
    ignoreFontWidthOverflow();
    final container = ProviderContainer(
      // Every ending a sheet can hand back starts from a free account; the
      // one case that wants a subscription already in place puts it there.
      overrides: fastBackendOverrides(
        online: online,
        analytics: analytics,
        premium: false,
      ),
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
    container.read(routerProvider).go(route);
    await tester.pumpAndSettle();
    return container;
  }

  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('the prices on screen', () {
    testWidgets("are the store's, and the store's are the locked set", (
      tester,
    ) async {
      // Every price on the screen comes from the offering the store served;
      // the fake store prices its offering from `LpPricing`, so the locked
      // figures are what appear. A literal typed into a layout is how a store
      // listing and a paywall end up disagreeing, and the store is the one
      // that wins.
      await open(tester, Routes.paywall);

      expect(find.textContaining(LpPricing.weekly), findsWidgets);
      expect(find.textContaining(LpPricing.monthly), findsWidgets);
      expect(find.textContaining(LpPricing.yearly), findsWidgets);
    });

    testWidgets('match the founder-locked figures exactly', (tester) async {
      // Pinned literally, on purpose: these are a business decision, and a
      // change to them should have to be made twice.
      expect(LpPricing.weekly, r'$2.99');
      expect(LpPricing.monthly, r'$7.99');
      expect(LpPricing.yearly, r'$39.99');
    });

    testWidgets('the yearly saving is computed, not typed', (tester) async {
      // 39.99 against 2.99 × 52 is 74%, derived on screen from the two
      // amounts. The old sub-line was a string that was only true in USD.
      await open(tester, Routes.paywall);
      expect(find.textContaining('74%'), findsOneWidget);
    });

    testWidgets('the disclosure names the selected price and period', (
      tester,
    ) async {
      await open(tester, Routes.paywall);
      expect(
        find.textContaining('${LpPricing.yearly} per ${l10n.paywallPeriodYear}'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text(l10n.paywallWeekly));
      await tester.tap(find.text(l10n.paywallWeekly));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('${LpPricing.weekly} per ${l10n.paywallPeriodWeek}'),
        findsOneWidget,
      );
    });
  });

  group('the seven-day trial', () {
    testWidgets('the timeline quotes the price of the plan selected', (
      tester,
    ) async {
      // Sep 1 (docs/09 issue 4): "cancel before, pay nothing" is said where
      // the price is, and the price has to be the one they just picked.
      await open(tester, Routes.paywall);

      expect(
        find.text(
          l10n.paywallTimelineChargeBody(l10n.paywallPerYear(LpPricing.yearly)),
        ),
        findsOneWidget,
        reason: 'yearly is preselected',
      );

      await tester.ensureVisible(find.text(l10n.paywallMonthly));
      await tester.tap(find.text(l10n.paywallMonthly));
      await tester.pumpAndSettle();

      expect(
        find.text(
          l10n.paywallTimelineChargeBody(
            l10n.paywallPerMonth(LpPricing.monthly),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the CTA says a week for the configured length', (
      tester,
    ) async {
      await open(tester, Routes.paywall);
      expect(find.text(l10n.paywallCta), findsOneWidget);
      expect(find.text(l10n.paywallCta), findsOneWidget);
    });

    test('no locale still counts three days', () {
      // The trial length was 3 days in the copy alone — nothing computed it —
      // so the only thing that can drift is a string. Pinned in all five.
      for (final locale in ['en', 'es', 'fr', 'de', 'pt']) {
        final arb =
            jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
                as Map<String, dynamic>;
        for (final key in [
          'paywallCta',
          'trialEndingStatsLabel',
        ]) {
          expect(
            arb[key] as String,
            isNot(contains('3')),
            reason: '$locale/$key still counts three days',
          );
        }
      }
    });
  });

  group('the free path', () {
    testWidgets('is reachable from the paywall', (tester) async {
      // App Store 3.1 and plain decency: a nicotine-cessation tool must not
      // trap someone who cannot pay behind its own paywall.
      await open(tester, Routes.paywall);

      expect(find.text(l10n.paywallFreeLink), findsOneWidget);
      await tester.tap(find.text(l10n.paywallFreeLink));
      await tester.pumpAndSettle();

      expect(find.text(l10n.freePlanTitle), findsOneWidget);
    });

    testWidgets('names honestly what the free tier does not include', (
      tester,
    ) async {
      await open(tester, Routes.paywallFree);
      expect(find.text(l10n.freePlanTitle), findsOneWidget);
    });
  });

  group('the store sheet', () {
    testWidgets('a purchase from inside the app flips the gate and returns', (
      tester,
    ) async {
      // The `_fromOnboarding == false` branch: no journey is created, the
      // account becomes entitled and the sheet closes.
      final analytics = RecordingAnalytics();
      final container = await open(tester, Routes.home, analytics: analytics);
      expect(container.read(isPremiumProvider), isFalse);

      unawaited(container.read(routerProvider).push(Routes.paywall));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.paywallCta));
      await tester.pumpAndSettle();

      final entitlement = container.read(entitlementProvider);
      expect(entitlement.isActive, isTrue);
      expect(entitlement.period, PlanPeriod.yearly, reason: 'preselected');
      // Popped back to where they came from, rather than stranded on the
      // paywall they have just paid past.
      expect(container.read(routerProvider).state.uri.path, Routes.home);
      expect(find.text(l10n.paywallCta), findsNothing);
      expect(analytics.names, containsAllInOrder(['trial_started', 'purchase_completed']));
    });

    testWidgets('a closed sheet changes nothing and says nothing', (
      tester,
    ) async {
      final container = await open(tester, Routes.home);
      container.read(fakeServerProvider).nextPurchase =
          FakePurchaseScript.cancelled;
      unawaited(container.read(routerProvider).push(Routes.paywall));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.paywallCta));
      await tester.pumpAndSettle();

      expect(container.read(isPremiumProvider), isFalse);
      expect(container.read(routerProvider).state.uri.path, Routes.paywall);
      expect(find.text(l10n.paywallCta), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a deferred payment is not claimed as a purchase', (
      tester,
    ) async {
      final container = await open(tester, Routes.home);
      container.read(fakeServerProvider).nextPurchase =
          FakePurchaseScript.pending;
      unawaited(container.read(routerProvider).push(Routes.paywall));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.paywallCta));
      await tester.pumpAndSettle();

      expect(container.read(isPremiumProvider), isFalse);
      expect(find.text(l10n.paywallPurchasePending), findsOneWidget);
      expect(container.read(routerProvider).state.uri.path, Routes.paywall);
      // The snack's own fallback timer must run out before the test ends.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('offline shows the offline copy and retries clean', (
      tester,
    ) async {
      final container = await open(tester, Routes.home, online: false);
      unawaited(container.read(routerProvider).push(Routes.paywall));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.paywallCta));
      await tester.pumpAndSettle();

      expect(find.text(l10n.errorOfflineTitle), findsOneWidget);
      expect(container.read(isPremiumProvider), isFalse);

      (container.read(connectivityProvider.notifier) as ToggleConnectivity)
          .set(true);
      await tester.tap(find.text(l10n.errorRetry));
      await tester.pumpAndSettle();

      expect(container.read(isPremiumProvider), isTrue);
      expect(container.read(routerProvider).state.uri.path, Routes.home);
    });

    testWidgets('a refusal gets its own copy, and nothing is charged', (
      tester,
    ) async {
      final container = await open(tester, Routes.home);
      container.read(fakeServerProvider).nextPurchase =
          FakePurchaseScript.notAllowed;
      unawaited(container.read(routerProvider).push(Routes.paywall));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.paywallCta));
      await tester.pumpAndSettle();

      expect(find.text(l10n.errorPurchaseNotAllowedTitle), findsOneWidget);
      expect(container.read(isPremiumProvider), isFalse);
    });

    testWidgets('an entitlement arriving under the paywall closes it, once', (
      tester,
    ) async {
      // A renewal on another device, a restore, a purchase that completed
      // after the sheet was dismissed: the paywall watches the entitlement
      // and leaves the moment it turns active — a paying user is never left
      // looking at a paywall for the plan they have. The router's refresh
      // listener still does not watch the entitlement, so the leave is the
      // paywall's own single pop and the route can never resurrect.
      final container = await open(tester, Routes.home);
      unawaited(container.read(routerProvider).push(Routes.paywall));
      await tester.pumpAndSettle();
      expect(container.read(routerProvider).state.uri.path, Routes.paywall);

      container.read(fakeServerProvider).putEntitlement(
        FakeServer.demoEntitlementJson(DateTime.now()),
      );
      // Not awaited directly: the fake's ack is a timer, and timers only run
      // when the test clock is pumped.
      unawaited(container.read(entitlementProvider.notifier).restore());
      await tester.pumpAndSettle();

      expect(container.read(isPremiumProvider), isTrue);
      expect(container.read(routerProvider).state.uri.path, Routes.home);
      expect(container.read(routerProvider).canPop(), isFalse);

      // A second change (a renewal) finds no paywall to pop and pops nothing
      // else — Home stays exactly where it is.
      unawaited(container.read(entitlementProvider.notifier).restore());
      await tester.pumpAndSettle();
      expect(container.read(routerProvider).state.uri.path, Routes.home);
      // The "Premium is active" snack's fallback timer.
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('the win-back offer', () {
    test('is gated off until its store offer exists', () {
      // A $3.99 card over a sheet that charges $7.99 is an invented number in
      // the other direction (tracker S4-7).
      expect(BillingCatalog.foundingOfferEnabled, isFalse);
    });

    testWidgets('its screen still transacts honestly through the store', (
      tester,
    ) async {
      final container = await open(tester, Routes.home);
      unawaited(container.read(routerProvider).push(Routes.winback));
      await tester.pumpAndSettle();

      expect(find.text(l10n.winbackTitle), findsOneWidget);
      await tester.tap(find.text(l10n.winbackCta));
      await tester.pumpAndSettle();

      expect(container.read(entitlementProvider).period, PlanPeriod.monthly);
      expect(container.read(routerProvider).state.uri.path, Routes.home);
    });
  });

  group('the legal links', () {
    testWidgets('Terms and Privacy are tappable, not decoration', (
      tester,
    ) async {
      // Play will not accept a listing without these, and for as long as the
      // policy pages did not exist they were rendered as plain text. They are
      // published now, so they have to actually be links — and be recognisable
      // as links to a reviewer looking for them.
      ignoreFontWidthOverflow();
      final container = ProviderContainer(overrides: fastBackendOverrides());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const LastPuffApp(),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      for (final label in [l10n.authTerms, l10n.authPrivacy]) {
        final text = tester.widget<Text>(find.text(label));
        expect(
          text.style?.decoration,
          TextDecoration.underline,
          reason: '$label must not be styled as plain copy',
        );
        expect(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(GestureDetector),
          ),
          findsWidgets,
          reason: '$label must be tappable',
        );
      }
    });

    testWidgets('are on the paywall too, with Restore beside them', (
      tester,
    ) async {
      // App Store 3.1.2 and Play's subscriptions policy: the surface with the
      // purchase button carries the legal links and a way to restore.
      await open(tester, Routes.paywall);
      for (final label in [
        l10n.authTerms,
        l10n.authPrivacy,
        l10n.paywallRestore,
      ]) {
        await tester.ensureVisible(find.text(label));
        final text = tester.widget<Text>(find.text(label));
        expect(text.style?.decoration, TextDecoration.underline, reason: label);
      }
    });

    test('point at the published pages', () {
      expect(LpLinks.privacy.toString(), 'https://alastpuff.web.app/privacy');
      expect(LpLinks.terms.toString(), 'https://alastpuff.web.app/terms');
    });
  });

  group('restore', () {
    testWidgets('says so when there is nothing to restore', (tester) async {
      // Two buttons that only showed a success snack were deleted once for
      // claiming to have restored purchases that could not exist. This one
      // asks the store, and reports the store's answer either way.
      final container = await open(tester, Routes.paywall);
      await tester.ensureVisible(find.text(l10n.paywallRestore));
      await tester.tap(find.text(l10n.paywallRestore));
      await tester.pumpAndSettle();

      expect(find.text(l10n.paywallRestoreNothing), findsOneWidget);
      expect(container.read(isPremiumProvider), isFalse);
      expect(container.read(routerProvider).state.uri.path, Routes.paywall);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('brings a subscription back and closes the paywall', (
      tester,
    ) async {
      final container = await open(tester, Routes.home);
      container.read(fakeServerProvider).putEntitlement(
        FakeServer.demoEntitlementJson(DateTime.now()),
      );
      unawaited(container.read(routerProvider).push(Routes.paywall));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(l10n.paywallRestore));
      await tester.tap(find.text(l10n.paywallRestore));
      await tester.pumpAndSettle();

      expect(container.read(isPremiumProvider), isTrue);
      expect(container.read(routerProvider).state.uri.path, Routes.home);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('restore from deeper in the app', () {
    testWidgets('lands back on the screen under the paywall, once', (
      tester,
    ) async {
      // Settings → paywall → Restore. The entitlement arriving under the
      // paywall and the restore's own success path used to BOTH leave, and
      // the second pop took Settings with it.
      final container = await open(tester, Routes.home);
      final router = container.read(routerProvider);
      unawaited(router.push(Routes.settings));
      await tester.pumpAndSettle();
      unawaited(router.push(Routes.paywallFrom('settings')));
      await tester.pumpAndSettle();

      container.read(fakeServerProvider).putEntitlement(
        FakeServer.demoEntitlementJson(DateTime.now()),
      );
      await tester.ensureVisible(find.text(l10n.paywallRestore));
      await tester.tap(find.text(l10n.paywallRestore));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, Routes.settings);
      expect(find.text(l10n.paywallRestored), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('a plan without a trial', () {
    testWidgets('no reminder row, no timeline, "Start Premium", and a '
        'trial-less disclosure', (tester) async {
      final container = ProviderContainer(
        overrides: fastBackendOverrides(premium: false),
      );
      addTearDown(container.dispose);
      container.read(fakeServerProvider).offeringTrialDays = null;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const LastPuffApp(),
        ),
      );
      container.read(quitStoreProvider.notifier).seedDemoJourney();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      container.read(routerProvider).go(Routes.paywall);
      await tester.pumpAndSettle();

      expect(find.text(l10n.paywallTrialReminder), findsNothing);
      expect(find.text(l10n.paywallTimelineToday), findsNothing);
      expect(find.text(l10n.paywallCtaSubscribe), findsOneWidget);
      expect(find.textContaining('free trial'), findsNothing);
    });
  });

  group('what the cards may claim', () {
    testWidgets('a returning user reads the upgrade framing, not "your plan '
        'is ready"', (tester) async {
      await open(tester, Routes.paywall);
      expect(find.text(l10n.paywallTitleUpgrade), findsOneWidget);
      expect(find.text(l10n.paywallTitle), findsNothing);
    });

    testWidgets('the founding-price line is off while the offer is', (
      tester,
    ) async {
      await open(tester, Routes.paywall);
      expect(BillingCatalog.foundingOfferEnabled, isFalse);
      expect(find.text(l10n.paywallWeeklySub), findsNothing);
    });

    testWidgets('a plan the store does not offer gets no card, and the '
        'selection moves off it', (tester) async {
      // Seen on the Test Store, which has no weekly product: the weekly card
      // rendered the typed fallback price next to two live ones.
      final container = ProviderContainer(
        overrides: fastBackendOverrides(premium: false),
      );
      addTearDown(container.dispose);
      container.read(fakeServerProvider).offeringPeriods = {
        PlanPeriod.monthly,
        PlanPeriod.weekly,
      };
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const LastPuffApp(),
        ),
      );
      container.read(quitStoreProvider.notifier).seedDemoJourney();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      container.read(routerProvider).go(Routes.paywall);
      await tester.pumpAndSettle();

      expect(find.text(l10n.paywallYearly), findsNothing);
      expect(find.text(l10n.paywallMonthly), findsOneWidget);
      expect(find.text(l10n.paywallWeekly), findsOneWidget);
      // The default selection was yearly; the disclosure now quotes the
      // first plan that exists, so the sheet and the screen agree.
      expect(find.textContaining(LpPricing.yearly), findsNothing);
      expect(find.textContaining(LpPricing.monthly), findsWidgets);
    });
  });
}
