import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// The danger-hours sheet after the Sep 1 field test (docs/09 issue 5).
///
/// The question it was asked was "9 PM – 12 AM: how many notifications, and
/// when?" — and the sheet had no answer on it. It now offers only the hours
/// whose nudge will actually fire, and prints the exact time for the hour
/// under the thumb. These tests pin that the words reach the screen and that
/// Save stores what the sentence promised.
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

  Future<ProviderContainer> openSettings(WidgetTester tester) async {
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
    container.read(routerProvider).go(Routes.settings);
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> openSheet(WidgetTester tester) async {
    final row = find.text(l10n.settingsDangerHours);
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text(l10n.settingsDangerHoursTitle), findsOneWidget);
  }

  testWidgets('offers only the hours whose nudge will fire', (tester) async {
    await openSettings(tester);
    await openSheet(tester);

    // 9am is the first hour whose nudge (8:50am) clears the 11pm–8am quiet
    // hours; 11pm is the last (10:50pm). Midnight through 8am would save and
    // then never fire, which is exactly the trap the old slider set.
    expect(find.text('9 AM'), findsOneWidget);
    expect(find.text('11 PM'), findsOneWidget);
    expect(find.text('8 AM'), findsNothing);
    expect(find.text('12 AM'), findsNothing);
    expect(find.text('2 AM'), findsNothing);
  });

  testWidgets('says the exact time, follows the tap, and saves it', (
    tester,
  ) async {
    final container = await openSettings(tester);
    await openSheet(tester);

    // The shipped default is 9pm, so the promise opens as 8:50pm.
    expect(find.text(l10n.settingsDangerHoursNudge('8:50 PM')), findsOneWidget);

    await tester.tap(find.text('10 PM'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.settingsDangerHoursNudge('9:50 PM')), findsOneWidget);
    expect(find.text(l10n.settingsDangerHoursNudge('8:50 PM')), findsNothing);

    await tester.tap(find.text(l10n.commonSave));
    await tester.pumpAndSettle();

    final settings = container.read(settingsStoreProvider);
    expect(settings.dangerStartHour, 22);
    expect(settings.dangerHoursCustom, isTrue);
    // Sheet gone, and the Settings row shows the hour — not a range nothing
    // reads.
    expect(find.text(l10n.settingsDangerHoursTitle), findsNothing);
    expect(find.text(l10n.settingsDangerHoursEdit('10 PM')), findsOneWidget);
  });

  testWidgets('a start the old slider saved inside quiet hours lands on the '
      'nearest hour that works', (tester) async {
    final container = await openSettings(tester);
    // Midnight, as the old noon-to-2am slider could store it.
    container.read(settingsStoreProvider.notifier).setDangerWindow(0, 3);
    await tester.pumpAndSettle();
    await openSheet(tester);

    // 11pm is one hour away on the clock face; 9am is nine. The sheet opens
    // on a choice that fires rather than on nothing.
    expect(find.text(l10n.settingsDangerHoursNudge('10:50 PM')), findsOneWidget);
  });
}
