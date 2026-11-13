import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// docs/15 QP-A7: Settings is one of the three doors to More help (the slip
/// screen and the daily program are the others).
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('Settings has a More help row that opens the page', (tester) async {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      // The fallback test font is wider than the device's; real overflow is
      // caught on device (see `screen_layout_test.dart`).
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);

    final analytics = RecordingAnalytics();
    final container = ProviderContainer(
      overrides: fastBackendOverrides(analytics: analytics),
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
    unawaited(container.read(routerProvider).push(Routes.settings));
    await tester.pumpAndSettle();

    final row = find.text(l10n.helpTitle, skipOffstage: false);
    expect(row, findsOneWidget, reason: 'no More help row in Settings');
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(container.read(routerProvider).state.uri.path, Routes.help);
    expect(analytics.propsOfAll('help_viewed'), [
      {'source': 'settings'},
    ]);
  });
}
