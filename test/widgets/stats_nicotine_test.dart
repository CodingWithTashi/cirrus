import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/widgets/lp_charts.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/dependence_engine.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// The nicotine card says only what completed, confirmed days say
/// (docs/10 §41).
///
/// It printed "≈ 14mg ↓" with the arrow baked into the string, so it pointed
/// down beside a line that climbed.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  void ignoreFontWidthOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  final now = DateTime(2026, 9, 13, 10);

  Future<void> pumpStats(WidgetTester tester, JourneyState journey) async {
    ignoreFontWidthOverflow();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: fastBackendOverrides(now: now),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).replaceForTest(journey);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    container.read(routerProvider).go(Routes.stats);
    await tester.pumpAndSettle();
  }

  Finder down() => find.byIcon(Icons.arrow_downward_rounded);
  Finder up() => find.byIcon(Icons.arrow_upward_rounded);

  testWidgets('fewer puffs than the day before: down, and the figure is '
      'yesterday', (tester) async {
    await pumpStats(
      tester,
      journeyOnDay(4, now: now, puffsByDay: {1: 90, 2: 60, 3: 40}),
    );
    final mg = DependenceEngine.nicotineMg(40, NicStrength.mg50).round();

    expect(find.text('≈ ${l10n.statsNicotineValue(mg)}'), findsOneWidget);
    expect(down(), findsOneWidget);
    expect(up(), findsNothing);
  });

  testWidgets('more puffs than the day before: up, never down', (tester) async {
    await pumpStats(
      tester,
      journeyOnDay(3, now: now, puffsByDay: {1: 20, 2: 21}),
    );

    expect(up(), findsOneWidget);
    expect(down(), findsNothing);
  });

  testWidgets('day one has no finished day: no figure, arrow or line', (
    tester,
  ) async {
    await pumpStats(tester, journeyOnDay(1, now: now));

    expect(find.textContaining('mg'), findsNothing);
    expect(down(), findsNothing);
    expect(up(), findsNothing);
    expect(find.byType(TrendLine), findsNothing);
  });
}
