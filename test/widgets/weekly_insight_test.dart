import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';
import 'package:last_puff/features/insight/insight_screen.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// The Sunday AI report reaching the screen (`weeklyInsight`, docs/04 §5).
///
/// Same class of bug as B11: the cron generated a report every week and the
/// screen rendered authored placeholder copy over hardcoded bars, so the
/// model's words were produced, paid for, and never seen. These tests pin the
/// two halves — the report renders when there is one, and the authored cards
/// stand in when there isn't.
void main() {
  const report = WeeklyInsight(
    weekId: '2026-08-30',
    headline: 'Thursday is your hard day',
    pattern: 'Three of your four over-limit days this month were Thursdays.',
    win: 'You survived nine cravings, up from four last week.',
    watchout: 'Your 9pm window is creeping back toward baseline.',
    move: 'Put your kit in another room before 8:30pm on Thursday.',
  );

  ProviderContainer containerWith(WeeklyInsight? insight) {
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        serverStateRepositoryProvider.overrideWithValue(
          _StubServerState(insight),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    return container;
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LpTheme.midnight(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const InsightScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("the model's report replaces the authored cards", (tester) async {
    final container = containerWith(report);
    await pumpScreen(tester, container);

    expect(find.text(report.headline), findsOneWidget);
    expect(find.text(report.pattern), findsOneWidget);
    // The authored week-one copy must be gone, not merely pushed off-screen —
    // showing both would be two contradictory claims about the same week.
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.insight1Headline), findsNothing);
  });

  testWidgets("the report's next move rides the last card", (tester) async {
    final container = containerWith(report);
    await pumpScreen(tester, container);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(report.win), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(report.watchout), findsOneWidget);
    expect(find.text(report.move), findsOneWidget);
  });

  testWidgets('no report falls back to the authored cards', (tester) async {
    final container = containerWith(null);
    await pumpScreen(tester, container);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.insight1Headline), findsOneWidget);
    expect(find.text(report.headline), findsNothing);
  });
}

class _StubServerState implements ServerStateRepository {
  const _StubServerState(this._insight);

  final WeeklyInsight? _insight;

  @override
  Future<PlanAdvice?> planAdvice() async => null;

  @override
  Future<WeeklyInsight?> latestInsight() async => _insight;
}
