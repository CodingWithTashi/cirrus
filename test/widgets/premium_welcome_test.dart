import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/api/fake/fake_server.dart';
import 'package:last_puff/data/dto/entitlement_codec.dart';
import 'package:last_puff/data/network/connectivity.dart';
import 'package:last_puff/data/stores/entitlement_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// The screen after a completed purchase (docs/10 §28). Until Sep 6 2026 a
/// purchase popped the paywall and said nothing: the gates unlocked and the
/// person was back on whatever screen they had come from, with no word that
/// anything had happened.
///
/// The paywall's own suite covers HOW it is reached (the CTA, the win-back
/// card, an entitlement arriving under an open paywall). This covers what it
/// says and where it leads.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  /// `flutter test` substitutes a square-glyph fallback font, so overflow in
  /// this harness says nothing about the device (see `screen_layout_test`).
  void ignoreFontWidthOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  /// Bought at 9:41 on Sep 6; the store's trial ends a week later, which is
  /// the instant the trial reminder is planned from.
  final now = DateTime(2026, 9, 6, 9, 41);
  final trial = Entitlement(
    tier: SubscriptionTier.trial,
    productId: 'yearly_3999',
    period: PlanPeriod.yearly,
    expiresAt: DateTime(2026, 9, 13, 9, 41),
    willRenew: true,
    store: BillingStore.other,
    isSandbox: true,
  );
  final paid = Entitlement(
    tier: SubscriptionTier.premium,
    productId: 'monthly_799',
    period: PlanPeriod.monthly,
    expiresAt: DateTime(2026, 10, 6, 9, 41),
    willRenew: true,
    store: BillingStore.other,
    isSandbox: true,
  );

  /// The app signed in on the demo journey with [entitlement] already held
  /// — on both sides of the seam, the way `demoSubscriptionOverrides` seeds
  /// the demo persona, so the first `identify()` answers the store's own
  /// initial value.
  Future<ProviderContainer> open(
    WidgetTester tester,
    Entitlement entitlement,
  ) async {
    ignoreFontWidthOverflow();
    final row = EntitlementCodec.encode(entitlement);
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(premium: false, now: now),
        fakeServerProvider.overrideWith(
          (ref) => FakeServer(
            latency: ref.watch(apiLatencyProvider),
            isOnline: () => ref.read(connectivityProvider),
            now: ref.watch(nowProvider),
          )..seedGuestEntitlement(row),
        ),
        entitlementProvider.overrideWith(
          () => EntitlementStore(initial: EntitlementCodec.decode(row)),
        ),
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
    container.read(routerProvider).go(Routes.home);
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('a trial says its days and its first charge, lists what opened, '
      'and lets go back to where the paywall came from', (tester) async {
    final container = await open(tester, trial);
    final router = container.read(routerProvider);
    unawaited(router.push(Routes.settings));
    await tester.pumpAndSettle();
    unawaited(router.push(Routes.paywallFrom('settings')));
    await tester.pumpAndSettle();
    // What the paywall does the moment the store says yes.
    unawaited(router.pushReplacement(Routes.premiumWelcome));
    await tester.pumpAndSettle();

    expect(find.text(l10n.premiumWelcomeTitle), findsOneWidget);
    expect(find.text(l10n.premiumWelcomeTrialBody(7)), findsOneWidget);
    // The paywall's own seven lines — nothing promised here that it did not.
    for (final line in [
      l10n.paywallFeatCoach,
      l10n.paywallFeatThemes,
      l10n.paywallFeatPanic,
      l10n.paywallFeatForecasts,
      l10n.paywallFeatPlan,
      l10n.paywallFeatReports,
      l10n.paywallFeatCommunity,
    ]) {
      expect(find.text(line), findsOneWidget, reason: line);
    }
    // The charge date is the store's end, and the reminder toggle ships on.
    expect(
      find.textContaining(l10n.premiumWelcomeCharge('Sep 13')),
      findsOneWidget,
    );
    expect(find.textContaining(l10n.premiumWelcomeReminder), findsOneWidget);

    await tester.tap(find.text(l10n.premiumWelcomeCta));
    await tester.pumpAndSettle();
    // Back on Settings: the paywall itself is no longer in the stack.
    expect(router.state.uri.path, Routes.settings);
    expect(find.text(l10n.premiumWelcomeTitle), findsNothing);
  });

  testWidgets('no trial: the plain body and no charge line', (tester) async {
    final container = await open(tester, paid);
    // A deep link with nothing beneath it.
    container.read(routerProvider).go(Routes.premiumWelcome);
    await tester.pumpAndSettle();

    expect(find.text(l10n.premiumWelcomeBody), findsOneWidget);
    expect(find.textContaining(l10n.premiumWelcomeReminder), findsNothing);
    expect(find.text('🔔'), findsNothing);

    await tester.tap(find.text(l10n.premiumWelcomeCta));
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, Routes.home);
  });

  testWidgets('the reminder sentence follows the toggle', (tester) async {
    final container = await open(tester, trial);
    container.read(settingsStoreProvider.notifier).setTrialReminder(false);
    container.read(routerProvider).go(Routes.premiumWelcome);
    await tester.pumpAndSettle();

    expect(
      find.textContaining(l10n.premiumWelcomeCharge('Sep 13')),
      findsOneWidget,
    );
    expect(find.textContaining(l10n.premiumWelcomeReminder), findsNothing);
  });

  testWidgets('every row is a door: a pushed one comes back here, a tab '
      'ends the welcome', (tester) async {
    final container = await open(tester, trial);
    final router = container.read(routerProvider);
    router.go(Routes.premiumWelcome);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(7));

    await tester.tap(find.text(l10n.paywallFeatThemes));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, Routes.settings);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text(l10n.premiumWelcomeTitle), findsOneWidget);

    await tester.tap(find.text(l10n.paywallFeatCoach));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(router.state.uri.path, Routes.coach);
    // Bounded pumps rather than `pumpAndSettle`: the coach tab is never
    // guaranteed to settle. The welcome's exit transition is long over.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(l10n.premiumWelcomeTitle), findsNothing);
  });

  testWidgets('from onboarding the rows are not doors and the CTA opens '
      'day 1', (tester) async {
    final container = await open(tester, trial);
    container.read(routerProvider).go(Routes.premiumWelcomeDay1);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(find.text(l10n.premiumWelcomeCta), findsNothing);
    await tester.tap(find.text(l10n.premiumWelcomeCtaDay1));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(routerProvider).state.uri.path, Routes.day1);
  });
}
