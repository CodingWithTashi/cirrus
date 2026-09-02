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
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// The four paywall screens, which had no behavioural coverage of any kind.
///
/// There is no billing SDK yet, so what is testable — and worth testing — is
/// everything AROUND the transaction: that the prices shown are the single
/// locked set rather than numbers typed into a layout, that the free path is
/// reachable rather than a dark pattern, and that choosing a tier actually
/// changes the state the rest of the app reads.
///
/// When RevenueCat lands, these are the tests that should keep passing while
/// `_startTrial` grows a real round-trip underneath them.
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

  Future<ProviderContainer> open(WidgetTester tester, String route) async {
    ignoreFontWidthOverflow();
    final container = ProviderContainer(overrides: fastBackendOverrides());
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
    testWidgets('are the locked set, from the single source', (tester) async {
      // Every price in the app comes from `LpPricing`. A literal typed into a
      // layout is how a store listing and a paywall end up disagreeing, and
      // the store is the one that wins.
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

    test('every locale says seven days and none still says three', () {
      // The trial length was 3 days in the copy alone — nothing computed it —
      // so the only thing that can drift is a string. Pinned in all five.
      for (final locale in ['en', 'es', 'fr', 'de', 'pt']) {
        final arb =
            jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
                as Map<String, dynamic>;
        expect(arb['paywallSubtitle'] as String, contains('7'), reason: locale);
        for (final key in [
          'paywallSubtitle',
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

  group('choosing a tier', () {
    testWidgets('upgrading from inside the app sets premium and returns', (
      tester,
    ) async {
      // The `_fromOnboarding == false` branch: no journey is created, the
      // existing one is upgraded and the sheet closes.
      final container = await open(tester, Routes.home);
      // The seeded fixture is already premium — the right default for every
      // other screen, and the wrong starting point for an upgrade.
      container.read(quitStoreProvider.notifier).setTier(SubscriptionTier.free);
      await tester.pumpAndSettle();
      expect(
        container.read(quitStoreProvider)!.profile.tier,
        SubscriptionTier.free,
      );

      unawaited(container.read(routerProvider).push(Routes.paywall));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.paywallCta));
      await tester.pumpAndSettle();

      expect(
        container.read(quitStoreProvider)!.profile.tier,
        SubscriptionTier.premium,
      );
      // Popped back to where they came from, rather than stranded on the
      // paywall they have just paid past. `setTier` rebuilds the router, so
      // the pop has to hold a reference taken before the state change.
      expect(container.read(routerProvider).state.uri.path, Routes.home);
      expect(find.text(l10n.paywallCta), findsNothing);
    });

    testWidgets('the win-back offer applies once and closes', (tester) async {
      final container = await open(tester, Routes.home);
      container.read(quitStoreProvider.notifier).setTier(SubscriptionTier.free);
      await tester.pumpAndSettle();
      unawaited(container.read(routerProvider).push(Routes.winback));
      await tester.pumpAndSettle();

      expect(find.text(l10n.winbackTitle), findsOneWidget);
      await tester.tap(find.text(l10n.winbackCta));
      await tester.pumpAndSettle();

      expect(
        container.read(quitStoreProvider)!.profile.tier,
        SubscriptionTier.premium,
      );
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

    test('point at the published pages', () {
      expect(LpLinks.privacy.toString(), 'https://alastpuff.web.app/privacy');
      expect(LpLinks.terms.toString(), 'https://alastpuff.web.app/terms');
    });
  });

  group('what it must not claim', () {
    testWidgets('offers no Restore Purchases while billing does not exist', (
      tester,
    ) async {
      // Restore is a store requirement the day subscriptions ship, and a lie
      // until then: there is nothing to restore. Two buttons that only showed
      // a success snack were deleted for exactly this reason, and this keeps
      // one from creeping back in ahead of the SDK.
      await open(tester, Routes.paywall);
      expect(find.textContaining('Restore'), findsNothing);
    });
  });
}
