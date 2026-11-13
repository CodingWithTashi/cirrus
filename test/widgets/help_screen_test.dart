import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/features/help/help_screen.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// docs/15 QP-A7: the page that says there is more help than an app, and where
/// to find it for the country the phone is in.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  /// `PressScale` schedules a 120ms `Future.delayed` after every tap (the
  /// release bounce), and the harness fails a test that ends with it pending.
  Future<void> settleTap(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 150));

  Future<({RecordingAnalytics analytics, List<Uri> opened})> pump(
    WidgetTester tester, {
    required String? region,
    String source = 'settings',
  }) async {
    // Tall enough to build every card: a ListView only builds what is on screen.
    tester.view.physicalSize = const Size(393, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final analytics = RecordingAnalytics();
    final opened = <Uri>[];
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(analytics: analytics),
        deviceRegionProvider.overrideWithValue(region),
        linkOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LpTheme.midnight(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HelpScreen(source: source),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    return (analytics: analytics, opened: opened);
  }

  testWidgets('says what the medicine is, without a dose or a promise', (
    tester,
  ) async {
    await pump(tester, region: 'US');

    expect(find.text(l10n.helpTitle), findsOneWidget);
    expect(find.text(l10n.helpMedicineTitle), findsOneWidget);
    expect(find.text(l10n.helpMedicineBody), findsOneWidget);
    // It must hand the decision to someone who can make it.
    expect(l10n.helpMedicineBody, contains('doctor or pharmacist'));
  });

  testWidgets('lists the services for the device country, with their source', (
    tester,
  ) async {
    await pump(tester, region: 'US');

    expect(find.text('1-800-QUIT-NOW'), findsOneWidget);
    expect(find.text('1-800-784-8669'), findsOneWidget);
    expect(find.text(l10n.helpNoLocal), findsNothing);
  });

  testWidgets('calling opens the dialler with the digits only', (tester) async {
    final r = await pump(tester, region: 'US');

    await tester.tap(find.text(l10n.helpCall));
    await settleTap(tester);

    expect(r.opened, [Uri.parse('tel:18007848669')]);
    expect(r.analytics.propsOfAll('help_link_opened'), [
      {'kind': 'call'},
    ]);
  });

  testWidgets('the source link opens the official page it was checked against', (
    tester,
  ) async {
    final r = await pump(tester, region: 'US');

    await tester.tap(find.text(l10n.helpSourceLink));
    await settleTap(tester);

    expect(r.opened.single.host, 'smokefree.gov');
    expect(r.analytics.propsOfAll('help_link_opened'), [
      {'kind': 'source'},
    ]);
  });

  testWidgets('the research link opens the review the medicine line cites', (
    tester,
  ) async {
    final r = await pump(tester, region: 'US');

    await tester.tap(find.text(l10n.helpMedicineSource));
    await settleTap(tester);

    expect(
      r.opened.single.toString(),
      'https://doi.org/10.1002/14651858.CD016058.pub3',
    );
    expect(r.analytics.propsOfAll('help_link_opened'), [
      {'kind': 'medicine'},
    ]);
  });

  testWidgets('the United Kingdom lists every nation, not just England', (
    tester,
  ) async {
    await pump(tester, region: 'GB');

    expect(find.text('0300 123 1044'), findsOneWidget);
    expect(find.text('0800 84 84 84'), findsOneWidget);
    expect(find.text('0800 085 2219'), findsOneWidget);
  });

  testWidgets('a country with nothing listed says so and points to a doctor', (
    tester,
  ) async {
    final r = await pump(tester, region: 'ZZ');

    expect(find.text(l10n.helpNoLocal), findsOneWidget);
    expect(find.text(l10n.helpDoctorLine), findsOneWidget);
    expect(find.text(l10n.helpCall), findsNothing);
    expect(r.opened, isEmpty);
    // The medicine section does not depend on the country.
    expect(find.text(l10n.helpMedicineBody), findsOneWidget);
  });

  testWidgets('a phone that reports no region is treated as unlisted', (
    tester,
  ) async {
    await pump(tester, region: null);
    expect(find.text(l10n.helpNoLocal), findsOneWidget);
  });

  testWidgets('reports one view, with the door it came through', (tester) async {
    final r = await pump(tester, region: 'US', source: 'slip');

    expect(r.analytics.propsOfAll('help_viewed'), [
      {'source': 'slip'},
    ]);
  });
}
