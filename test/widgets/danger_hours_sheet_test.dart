import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/widgets/lp_selectables.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/features/settings/quiet_hours_band.dart';
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
    // then never fire, which is exactly the trap the old slider set. Scoped
    // to the chips: the rail under them labels its axis "12 AM" too.
    Finder chip(String label) => find.widgetWithText(LpChip, label);
    expect(chip('9 AM'), findsOneWidget);
    expect(chip('11 PM'), findsOneWidget);
    expect(chip('8 AM'), findsNothing);
    expect(chip('12 AM'), findsNothing);
    expect(chip('2 AM'), findsNothing);
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

    // The rail made the sheet taller than the test viewport; Save may sit
    // below the fold, as it does on a short phone.
    await tester.ensureVisible(find.text(l10n.commonSave));
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

  group('quiet hours on the rail (docs/10 §28)', () {
    /// The rail's gesture area and its cell width, for drags in hours.
    (Rect, double) rail(WidgetTester tester) {
      final rect = tester.getRect(find.byType(QuietHoursBand));
      return (rect, rect.width / QuietTrack.cells);
    }

    Offset onRail(Rect rect, double cell, double position) =>
        Offset(rect.left + position * cell, rect.top + QuietHoursBand.height / 2);

    testWidgets('opens on the stored window, said in hours', (tester) async {
      await openSettings(tester);
      await openSheet(tester);

      // A `SectionLabel`, so upper-cased on the way to the screen.
      expect(
        find.text(l10n.settingsQuietHoursLabel.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text('11 PM – 8 AM · ${l10n.settingsQuietHoursLength(9)}'),
        findsOneWidget,
      );
      expect(find.text(l10n.settingsQuietHours('11 PM – 8 AM')), findsOneWidget);
    });

    testWidgets('dragging the start knob re-answers the chips and the promise, '
        'and Save keeps both', (tester) async {
      final container = await openSettings(tester);
      await openSheet(tester);
      // 11 PM first: the hour the new window is about to swallow.
      await tester.tap(find.text('11 PM'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.settingsDangerHoursNudge('10:50 PM')), findsOneWidget);

      // The start knob sits at cell 11 (11 PM on a noon-to-noon rail). Two
      // cells left is 9 PM.
      final (rect, cell) = rail(tester);
      await tester.dragFrom(onRail(rect, cell, 11), Offset(-2 * cell, 0));
      await tester.pumpAndSettle();

      // 10 PM and 11 PM would fire inside the new window, so they are gone;
      // the selection stepped to 9 PM, the nearest hour that still fires,
      // and the promise followed it.
      expect(find.textContaining('11 PM'), findsNothing);
      expect(find.text('10 PM'), findsNothing);
      expect(find.text(l10n.settingsDangerHoursNudge('8:50 PM')), findsOneWidget);
      expect(find.text(l10n.settingsQuietHours('9 PM – 8 AM')), findsOneWidget);
      expect(
        find.text('9 PM – 8 AM · ${l10n.settingsQuietHoursLength(11)}'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text(l10n.commonSave));
      await tester.tap(find.text(l10n.commonSave));
      await tester.pumpAndSettle();
      final settings = container.read(settingsStoreProvider);
      expect(settings.quietStartHour, 21);
      expect(settings.quietEndHour, 8);
      expect(settings.dangerStartHour, 21);
      expect(settings.dangerHoursCustom, isTrue);
    });

    testWidgets('dragging the band by its middle slides the whole night', (
      tester,
    ) async {
      await openSettings(tester);
      await openSheet(tester);

      // The shipped band spans cells 11–20. Grab its middle and slide two
      // cells right: 1 AM – 10 AM, still nine hours.
      final (rect, cell) = rail(tester);
      await tester.dragFrom(onRail(rect, cell, 15.5), Offset(2 * cell, 0));
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsQuietHours('1 AM – 10 AM')), findsOneWidget);
      expect(
        find.text('1 AM – 10 AM · ${l10n.settingsQuietHoursLength(9)}'),
        findsOneWidget,
      );
      // 10 AM's nudge (9:50 AM) now lands inside; 1 AM's (12:50 AM) does not.
      expect(find.text('10 AM'), findsNothing);
      expect(find.text('1 AM'), findsOneWidget);
    });

    testWidgets('a tap on the rail brings the nearer knob to it', (tester) async {
      await openSettings(tester);
      await openSheet(tester);

      // Cell 8 is 8 PM, three cells left of the start knob and far from the
      // end: the start comes to it.
      final (rect, cell) = rail(tester);
      await tester.tapAt(onRail(rect, cell, 8));
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsQuietHours('8 PM – 8 AM')), findsOneWidget);
    });

    testWidgets('closing the sheet unsaved keeps the stored window', (
      tester,
    ) async {
      final container = await openSettings(tester);
      await openSheet(tester);
      final (rect, cell) = rail(tester);
      await tester.dragFrom(onRail(rect, cell, 11), Offset(-2 * cell, 0));
      await tester.pumpAndSettle();
      expect(find.text(l10n.settingsQuietHours('9 PM – 8 AM')), findsOneWidget);

      // Swipe away, no Save.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text(l10n.settingsDangerHoursTitle), findsNothing);
      expect(container.read(settingsStoreProvider).quietStartHour, 23);
      expect(container.read(settingsStoreProvider).quietEndHour, 8);
    });

    testWidgets('each knob is a slider to a screen reader, an hour a step', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openSettings(tester);
      await openSheet(tester);

      final start = tester.getSemantics(
        find.bySemanticsLabel(l10n.settingsQuietHoursStartHandle),
      );
      expect(start.value, '11 PM');
      final actions = start.getSemanticsData();
      expect(actions.hasAction(SemanticsAction.increase), isTrue);
      expect(actions.hasAction(SemanticsAction.decrease), isTrue);

      tester.semantics.performAction(
        find.semantics.byLabel(l10n.settingsQuietHoursStartHandle),
        SemanticsAction.decrease,
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.settingsQuietHours('10 PM – 8 AM')), findsOneWidget);

      final end = tester.getSemantics(
        find.bySemanticsLabel(l10n.settingsQuietHoursEndHandle),
      );
      expect(end.value, '8 AM');
      handle.dispose();
    });
  });
}
