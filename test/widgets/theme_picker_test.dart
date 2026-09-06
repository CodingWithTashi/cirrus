import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/app/theme/lp_palette.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

/// Settings → Theme: the palette-family picker.
///
/// The contract: the two Premium families are always VISIBLE and always
/// TAPPABLE (hiding them sells nothing, disabling them answers a tap with
/// silence), a locked tap opens the lock card and commits nothing, and the
/// door it offers is tagged `theme` so its conversion can be read apart from
/// every other Premium door.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// The fallback font overflows where the device does not — same rule as
  /// `screen_layout_test`.
  void ignoreFontWidthOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  /// Settings, open, with the theme sheet already up.
  Future<ProviderContainer> openSheet(
    WidgetTester tester, {
    required bool premium,
    RecordingAnalytics? analytics,
  }) async {
    ignoreFontWidthOverflow();
    final container = ProviderContainer(
      overrides: fastBackendOverrides(premium: premium, analytics: analytics),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    unawaited(
      container
          .read(entitlementProvider.notifier)
          .bindSession(container.read(fakeServerProvider).ensureSessionId()),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(container.read(isPremiumProvider), premium);

    container.read(routerProvider).go(Routes.settings);
    await tester.pumpAndSettle();

    final row = find.text(l10n.settingsTheme);
    await tester.scrollUntilVisible(row, 120);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('every family is listed, locked or not', (tester) async {
    await openSheet(tester, premium: false);

    // Visible, all three. Nobody upgrades for a feature they never saw exist.
    expect(find.text(l10n.settingsThemeEmber), findsWidgets);
    expect(find.text(l10n.settingsThemeHearth), findsWidgets);
    expect(find.text(l10n.settingsThemeTide), findsWidgets);
    // Two locks, one per Premium family.
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
    // And no lock card until one is actually tapped.
    expect(find.text(l10n.settingsThemeLocked), findsNothing);
  });

  testWidgets('a locked family answers with the card and commits nothing', (
    tester,
  ) async {
    final container = await openSheet(tester, premium: false);

    await tester.tap(find.text(l10n.settingsThemeHearth));
    await tester.pumpAndSettle();

    expect(find.text(l10n.settingsThemeLocked), findsOneWidget);
    expect(find.text(l10n.premiumLockCta), findsOneWidget);
    expect(
      container.read(settingsStoreProvider).palette,
      LpPalette.ember,
      reason: 'a family they were never entitled to must not be stored — it '
          'would surface the day they subscribed for something else',
    );
    // The sheet is still up: the lock is an answer, not an exit.
    expect(find.text(l10n.settingsThemeTide), findsWidgets);
  });

  testWidgets('the lock card opens the paywall tagged theme', (tester) async {
    final container = await openSheet(tester, premium: false);

    await tester.tap(find.text(l10n.settingsThemeTide));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.premiumLockCta));
    await tester.pumpAndSettle();

    final uri = container.read(routerProvider).state.uri;
    expect(uri.path, Routes.paywall);
    expect(uri.queryParameters['source'], 'theme');
    expect(
      container.read(settingsStoreProvider).palette,
      LpPalette.ember,
      reason: 'walking to the paywall is not a purchase',
    );
  });

  testWidgets('the door reports itself both ways', (tester) async {
    final analytics = RecordingAnalytics();
    await openSheet(tester, premium: false, analytics: analytics);

    // Filtered by source, not `propsOf`: a free account's Home renders the
    // `nudge` gate on the way here, so it owns the FIRST gate_shown.
    List<Map<String, Object>> from(String event, String source) => [
      for (final props in analytics.propsOfAll(event))
        if (props['source'] == source) props,
    ];

    expect(
      from('gate_shown', 'theme'),
      hasLength(1),
      reason: 'a door nobody taps is bad copy; a door nobody sees is bad '
          'placement, and only gate_shown tells them apart — once per open, '
          'never once per rebuild',
    );

    await tester.tap(find.text(l10n.settingsThemeHearth));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.premiumLockCta));
    await tester.pumpAndSettle();

    expect(from('gate_tapped', 'theme'), hasLength(1));
    expect(from('paywall_viewed', 'theme'), hasLength(1));
    expect(
      from('gate_shown', 'theme'),
      hasLength(1),
      reason: 'still one impression after the tap — counting the tap as a '
          'second gate_shown would cap this door at 50% however well it '
          'converts, and that ratio is the whole point of the event',
    );
  });

  testWidgets('a paying account wears what it picks', (tester) async {
    final container = await openSheet(tester, premium: true);

    expect(find.byIcon(Icons.lock_outline), findsNothing);

    await tester.tap(find.text(l10n.settingsThemeHearth));
    await tester.pumpAndSettle();

    expect(container.read(settingsStoreProvider).palette, LpPalette.hearth);
    // The sheet closes on a real choice, and the app is wearing it.
    expect(find.text(l10n.settingsThemeTide), findsNothing);
    expect(
      Theme.of(tester.element(find.text(l10n.settingsTitle))).brightness,
      isNotNull,
    );
  });

  testWidgets('the Appearance row names the mode, never the family', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: fastBackendOverrides(premium: true),
    );
    addTearDown(container.dispose);
    ignoreFontWidthOverflow();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    container
        .read(settingsStoreProvider.notifier)
        .setThemeMode(ThemeMode.dark);
    container.read(settingsStoreProvider.notifier).setPalette(LpPalette.tide);
    container.read(routerProvider).go(Routes.settings);
    await tester.pumpAndSettle();

    // "Midnight" named the Ember family's dark mode, which stops being true
    // the moment the family is Tide.
    expect(find.textContaining(l10n.settingsAppearanceDark), findsWidgets);
    expect(find.textContaining('Midnight'), findsNothing);
  });
}
