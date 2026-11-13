import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/utils/lp_format.dart';
import 'package:last_puff/core/widgets/lp_buttons.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// docs/15 QP-A11: the Adjust sheet changes the date and nothing else, and
/// does not move it until the person has chosen to.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final now = DateTime(2026, 11, 12, 10, 15);

  String date(DateTime d) => LpFormat.shortDate(d, 'en');

  /// A selected chip reads "30 ✓", so match either form.
  Finder chip(int days) => find.byWidgetPredicate(
    (w) => w is Text && (w.data == '$days' || w.data == '$days ✓'),
  );

  Future<(ProviderContainer, RecordingAnalytics)> openSheet(
    WidgetTester tester, {
    QuitMethod method = QuitMethod.taper,
  }) async {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final analytics = RecordingAnalytics();
    final container = ProviderContainer(
      overrides: fastBackendOverrides(now: now, analytics: analytics),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    final base = journeyOnDay(10, now: now);
    container
        .read(quitStoreProvider.notifier)
        .replaceForTest(
          base.copyWith(plan: base.plan.copyWith(method: method)),
        );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    unawaited(container.read(routerProvider).push(Routes.plan));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.planAdjustCta));
    await tester.pumpAndSettle();
    return (container, analytics);
  }

  Future<void> pick(WidgetTester tester, int days) async {
    await tester.tap(chip(days));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
  }

  bool applyEnabled(WidgetTester tester) => tester
      .widget<LpButton>(find.widgetWithText(LpButton, l10n.planAdjustApply))
      .onTap != null;

  testWidgets('opens with nothing chosen, so there is nothing to apply', (
    tester,
  ) async {
    await openSheet(tester);

    expect(applyEnabled(tester), isFalse);
    // No "✓" on any length: nothing is preselected.
    for (final p in [14, 21, 30, 42]) {
      expect(find.text('$p ✓'), findsNothing, reason: '$p');
    }
  });

  testWidgets('the method toggle is gone; method changes go to a new plan', (
    tester,
  ) async {
    await openSheet(tester);

    expect(find.text(l10n.planMethodTaper), findsNothing);
    expect(find.text(l10n.planMethodCold), findsNothing);
    expect(find.text(l10n.planAdjustNewPlanLink), findsOneWidget);
  });

  testWidgets('the link opens Start a new plan', (tester) async {
    final (container, _) = await openSheet(tester);

    await tester.tap(find.text(l10n.planAdjustNewPlanLink));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(container.read(routerProvider).state.uri.path, Routes.planNew);
  });

  testWidgets('a length that is already their date says so and applies nothing', (
    tester,
  ) async {
    final (container, analytics) = await openSheet(tester);
    final before = container.read(quitStoreProvider)!.plan;

    // 21 days from day 10 of 30 is exactly Freedom Day as it stands.
    await pick(tester, 21);
    expect(find.text(l10n.planAdjustSame), findsOneWidget);
    expect(applyEnabled(tester), isFalse);

    await tester.tap(find.widgetWithText(LpButton, l10n.planAdjustApply));
    await tester.pumpAndSettle();
    expect(container.read(quitStoreProvider)!.plan.paceDays, before.paceDays);
    expect(analytics.propsOfAll('plan_adjusted'), isEmpty);
  });

  testWidgets('a later date shows where it lands and warns it is harder', (
    tester,
  ) async {
    final (container, _) = await openSheet(tester);
    final current = container.read(quitStoreProvider)!.plan.freedomDate;

    await pick(tester, 30);

    final later = DateTime(now.year, now.month, now.day + 29);
    expect(find.text(l10n.planAdjustPreview(date(later))), findsOneWidget);
    expect(find.text(l10n.planAdjustLater), findsOneWidget);
    expect(later.isAfter(current), isTrue);
    expect(applyEnabled(tester), isTrue);
  });

  testWidgets('an earlier date is previewed without the warning', (tester) async {
    await openSheet(tester);

    await pick(tester, 14);

    final earlier = DateTime(now.year, now.month, now.day + 13);
    expect(find.text(l10n.planAdjustPreview(date(earlier))), findsOneWidget);
    expect(find.text(l10n.planAdjustLater), findsNothing);
    expect(applyEnabled(tester), isTrue);
  });

  testWidgets('Apply moves Freedom Day to the date it showed, and reports it', (
    tester,
  ) async {
    final (container, analytics) = await openSheet(tester);

    await pick(tester, 14);
    await tester.tap(find.widgetWithText(LpButton, l10n.planAdjustApply));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    final plan = container.read(quitStoreProvider)!.plan;
    expect(plan.freedomDate, DateTime(now.year, now.month, now.day + 13));
    expect(analytics.propsOfAll('plan_adjusted'), [
      {'delta_days': -7},
    ]);
    // Apply shows a snack, and `showLpSnack` force-closes it on a timer of its
    // own (duration + 250ms). Let that run out before the tree is torn down.
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('a cold-turkey plan has no length to pick, only the way out', (
    tester,
  ) async {
    await openSheet(tester, method: QuitMethod.coldTurkey);

    for (final p in [14, 21, 30, 42]) {
      expect(chip(p), findsNothing, reason: '$p');
    }
    expect(find.text(l10n.planAdjustNewPlanLink), findsOneWidget);
  });
}
