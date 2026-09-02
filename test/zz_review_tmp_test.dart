import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/features/panic/panic_screens.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import 'helpers.dart';

void main() {
  testWidgets('REVIEW: survive then close flow -> analytics events', (
    tester,
  ) async {
    final a = RecordingAnalytics();
    final c = ProviderContainer(
      overrides: [...fastBackendOverrides(analytics: a)],
    );
    addTearDown(c.dispose);
    Widget app(Widget home) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: LpTheme.midnight(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );
    await tester.pumpWidget(app(const PanicFlow()));
    await tester.pump(const Duration(milliseconds: 400));
    c.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pump(const Duration(milliseconds: 400));
    c.read(panicProvider.notifier).setIntensity(7);
    c.read(panicProvider.notifier).survive(intensityAfter: 3);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(app(const SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 400));
    final outcomes = a.events.where((e) => e.name == 'craving_outcome').toList();
    // ignore: avoid_print
    print('REVIEW craving_outcome events: $outcomes');
    // ignore: avoid_print
    print('REVIEW all events: ${a.events}');
  });
}
