import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// docs/15 QP-B6: the evening check-in became the daily message. One switch and
/// one hour still, and its sheet now says what is actually sent: an evening
/// message about the plan, plus the first three mornings from the date.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('Settings calls it the daily message, and its sheet says what is '
      'sent', (tester) async {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
    tester.view.physicalSize = const Size(393, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
    unawaited(container.read(routerProvider).push(Routes.settings));
    await tester.pumpAndSettle();

    expect(find.text('Evening check-in'), findsNothing);
    final row = find.text(l10n.settingsCheckin, skipOffstage: false);
    expect(row, findsOneWidget);
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.text(l10n.settingsCheckin), findsWidgets);
    expect(find.text(l10n.settingsCheckinBody), findsOneWidget);
    expect(find.text(l10n.settingsCheckinToggle), findsOneWidget);
    // The honest line about the mornings, and nothing about today's limit,
    // which is no longer what the message is about.
    expect(l10n.settingsCheckinBody.toLowerCase(), contains('three mornings'));
    expect(l10n.settingsCheckinBody.toLowerCase(), isNot(contains('limit')));
  });
}
