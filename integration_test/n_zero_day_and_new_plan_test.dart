import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/utils/lp_format.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/taper_engine.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/features/home/home_screen.dart';
import 'package:last_puff/features/plan/new_plan_screen.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import 'harness.dart';

/// The Nov 12 2026 retention round (docs/10 §52), on a real device.
///
/// The widget suite proves these on a fallback font with layout overflow
/// switched off, and with the router driven by hand. This runs the real app:
/// the Day-1 walkthrough's barrier over the new zero-day button, the pinned
/// control's real height beside the tab bar, the new-plan page's keyboard,
/// and a journey mutation followed by a navigation — the place two earlier
/// screens came back from the dead. A layout overflow fails the test here.
///
/// Fake backend, a fixed clock, nothing written anywhere:
///
/// ```
/// flutter test integration_test/n_zero_day_and_new_plan_test.dart \
///   -d <device> --dart-define=LP_BACKEND=fake
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // An afternoon: before the evening mood prompt and the check-in hour.
  final now = DateTime(2026, 11, 12, 15, 30);
  final today = LpDate.dayStart(now);

  /// A journey on plan day [day]. Earlier days are logged at their limit
  /// (zero-puff days confirmed clean); [lately] overwrites the days just
  /// before today, newest first.
  JourneyState journeyOn(
    int day, {
    QuitMethod method = QuitMethod.taper,
    int baseline = 200,
    Set<int> tasks = const {0, 1, 2},
    List<int> lately = const [],
  }) {
    final plan = QuitPlan(
      method: method,
      paceDays: 30,
      startDate: LpDate.addDays(today, -(day - 1)),
      baselinePuffsPerDay: baseline,
      weeklySpend: 60,
      strength: NicStrength.mg50,
    );
    final days = <DateTime, DayLog>{};
    for (var d = 1; d < day; d++) {
      final date = LpDate.addDays(plan.startDate, d - 1);
      final limit = d <= plan.totalDays ? TaperEngine.limitFor(plan, d) : 0;
      days[date] = DayLog(
        date: date,
        puffs: limit,
        limit: limit,
        hourBuckets: limit == 0 ? const {} : {10: limit},
        vapeFreeConfirmed: limit == 0,
      );
    }
    for (var back = 1; back <= lately.length; back++) {
      final date = LpDate.addDays(today, -back);
      final puffs = lately[back - 1];
      days[date] = DayLog(
        date: date,
        puffs: puffs,
        limit: 0,
        hourBuckets: puffs == 0 ? const {} : {21: puffs},
        vapeFreeConfirmed: puffs == 0,
      );
    }
    return JourneyState(
      profile: const UserProfile(alias: '@matrixfox', avatarEmoji: '🦊'),
      plan: plan,
      days: days,
      cravingsSurvivedTotal: 14,
      repairTokens: 0,
      longestStreak: 0,
      goals: const [],
      earnedBadges: const {},
      lastPuffAt: null,
      day1TasksDone: tasks,
    );
  }

  /// Signed in on the fake backend, then standing on [journey].
  Future<E2E> open(WidgetTester tester, JourneyState journey) async {
    final e2e = await E2E.boot(
      tester,
      overrides: [nowProvider.overrideWithValue(() => now)],
    );
    await e2e.waitFor(const Duration(seconds: 2));
    await e2e.emailDoor();
    await e2e.tapSpan(e2e.l10n.authLogIn);
    await e2e.enterField(e2e.l10n.authEmailLabel, 'maya@quitmail.com');
    await e2e.enterField(e2e.l10n.authPasswordLabel, 'secret1');
    await e2e.tapText(e2e.l10n.authLogIn);
    await e2e.waitFor(const Duration(seconds: 3));
    expect(
      e2e.container.read(quitStoreProvider),
      isNotNull,
      reason: 'sign-in failed; on screen: ${e2e.texts()}',
    );
    e2e.container.read(quitStoreProvider.notifier).replaceForTest(journey);
    await e2e.settle();
    return e2e;
  }

  String path(E2E e2e) => e2e.container.read(routerProvider).state.uri.path;

  JourneyState journeyOf(E2E e2e) => e2e.container.read(quitStoreProvider)!;

  testWidgets('cold turkey, day one: the checklist asks for a check-in, the '
      'tour lands on the confirmation, and nothing becomes a slip', (
    tester,
  ) async {
    final e2e = await open(
      tester,
      journeyOn(1, method: QuitMethod.coldTurkey, tasks: const {}),
    );
    final l10n = e2e.l10n;
    e2e.container.read(routerProvider).go(Routes.day1);
    await e2e.settle();

    expect(e2e.showing(l10n.day1Task1Zero), isTrue, reason: '${e2e.texts()}');
    expect(e2e.showing(l10n.day1Task1), isFalse);

    // The row walks to Home, under the walkthrough's barrier.
    await e2e.tap(find.text(l10n.day1Task1Zero).first, why: 'the first task');
    await e2e.waitFor(const Duration(seconds: 1));
    expect(path(e2e), Routes.home);
    expect(e2e.visible(l10n.homeStillVapeFree), isTrue);
    expect(e2e.showing(l10n.homeLogPuff), isFalse);
    expect(e2e.showing(l10n.homeIVapedToday), isFalse, reason: 'mid-lesson');

    await e2e.tapText(l10n.homeStillVapeFree);
    await e2e.waitFor(const Duration(seconds: 1));

    // Back on the checklist, ticked; day one is clean and counted.
    expect(path(e2e), Routes.day1);
    expect(e2e.showing(l10n.day1Task1ZeroDone), isTrue);
    var journey = journeyOf(e2e);
    expect(journey.day1TasksDone, {0});
    expect(journey.days[today]!.puffs, 0);
    expect(journey.days[today]!.vapeFreeConfirmed, isTrue);
    expect(journey.pendingSlipCleanDays, isNull);
    expect(e2e.container.read(todayProvider)!.streak, 1);

    // Skip the rest: Home, with the day resting and setup still on offer.
    await e2e.scrollTo(find.text(l10n.day1Skip));
    await e2e.tapText(l10n.day1Skip);
    await e2e.waitFor(const Duration(seconds: 1));
    expect(path(e2e), Routes.home);
    expect(e2e.visible(l10n.homeVapeFreeToday), isTrue);
    expect(e2e.showing(l10n.homeZeroDayDone), isTrue);
    expect(e2e.showing(l10n.homeFinishSetup(1)), isTrue);
    expect(e2e.showing(l10n.homeLeftTight(0)), isFalse);
    expect(e2e.showing(l10n.homeOfLimit(0)), isFalse);

    // The truth can still be told — one tap, one puff — and taken back,
    // slip and all.
    await e2e.tapText(l10n.homeIVapedToday);
    expect(journeyOf(e2e).days[today]!.puffs, 1);
    expect(journeyOf(e2e).pendingSlipCleanDays, isNotNull);
    expect(e2e.visible(l10n.homeLogPuff), isTrue);
    expect(await e2e.waitForText(l10n.commonUndo), isTrue);
    await e2e.tapText(l10n.commonUndo);
    journey = journeyOf(e2e);
    expect(journey.days[today]!.puffs, 0);
    expect(journey.pendingSlipCleanDays, isNull, reason: 'undo took it back');
    expect(e2e.visible(l10n.homeVapeFreeToday), isTrue);

    // The same screen in every language the app ships: a real font, real
    // widths. An overflow anywhere fails here.
    for (final code in ['de', 'es', 'fr', 'it', 'pt', 'en']) {
      e2e.container
          .read(settingsStoreProvider.notifier)
          .setLocale(Locale(code));
      await e2e.settle();
      final local = await AppLocalizations.delegate.load(Locale(code));
      expect(
        e2e.visible(local.homeVapeFreeToday),
        isTrue,
        reason: '$code: ${e2e.texts()}',
      );
      expect(e2e.visible(local.homeIVapedToday), isTrue, reason: code);
    }
    // Let the last snack's own timer run out.
    await e2e.waitFor(const Duration(seconds: 6));
  });

  testWidgets('a finished plan: Home offers the next one, the page starts '
      'it from where they are, and nothing is lost', (tester) async {
    final e2e = await open(
      tester,
      journeyOn(36, lately: const [78, 80, 82, 84, 86, 0, 82]),
    );
    final l10n = e2e.l10n;
    e2e.container.read(routerProvider).go(Routes.home);
    await e2e.settle();
    final before = e2e.container.read(todayProvider)!;
    expect(before.isMaintenance, isTrue);

    await e2e.scrollTo(find.text(l10n.homePlanEndedTitle));
    await e2e.tapText(l10n.homePlanEndedTitle);
    await e2e.waitFor(const Duration(seconds: 1));
    expect(find.byType(NewPlanScreen), findsOneWidget);
    expect(e2e.showing(l10n.newPlanLead), isTrue);
    expect(find.widgetWithText(TextField, '82'), findsOneWidget);
    expect(e2e.showing(l10n.newPlanLevelHint(82)), isTrue);
    expect(e2e.showing(l10n.newPlanToday(78)), isTrue);

    // A different level, typed on the real keyboard, redraws the line.
    await tester.enterText(find.byType(TextField).first, '100');
    await e2e.settle();
    expect(e2e.showing(l10n.newPlanToday(95)), isTrue, reason: '${e2e.texts()}');
    await tester.enterText(find.byType(TextField).first, '82');
    await e2e.settle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await e2e.settle();

    await e2e.scrollTo(find.text('21'));
    await e2e.tapText('21');
    expect(e2e.showing(l10n.newPlanToday(76)), isTrue);
    await e2e.scrollTo(find.text(l10n.newPlanCta));
    await e2e.tapText(l10n.newPlanCta);
    await e2e.waitFor(const Duration(seconds: 2));

    // Home, and it stayed Home: the journey change after the navigation is
    // exactly what used to bring a left screen back.
    expect(path(e2e), Routes.home);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(NewPlanScreen), findsNothing);
    final after = e2e.container.read(todayProvider)!;
    expect(after.dayNumber, 1);
    expect(after.totalDays, 21);
    expect(after.limit, 76);
    expect(after.streak, before.streak);
    expect(after.savedLifetime, before.savedLifetime);
    expect(after.cravingsSurvivedTotal, before.cravingsSurvivedTotal);
    expect(
      e2e.showing(
        l10n.homeGreetingDate(LpFormat.weekdayDate(now, 'en'), 1, 21),
      ),
      isTrue,
      reason: '${e2e.texts()}',
    );
    expect(e2e.visible(l10n.homeLogPuff), isTrue);
    expect(e2e.showing(l10n.homePlanEndedTitle), isFalse);
    expect(e2e.showing(l10n.homeFinishSetup(3)), isFalse);

    // Stats still has last week, and the Plan screen now offers both.
    e2e.container.read(routerProvider).go(Routes.stats);
    await e2e.settle();
    expect(path(e2e), Routes.stats);
    e2e.container.read(routerProvider).go(Routes.home);
    await e2e.settle();
    unawaited(e2e.container.read(routerProvider).push(Routes.plan));
    await e2e.settle();
    expect(e2e.showing(l10n.planAdjustCta), isTrue);
    expect(e2e.showing(l10n.planNewCta), isTrue);
    await e2e.waitFor(const Duration(seconds: 6));
  });

  testWidgets('the sign-out dialog says how to get back and offers the new '
      'plan, and all of it fits', (tester) async {
    final e2e = await open(
      tester,
      journeyOn(36, lately: const [78, 80, 82, 84, 86, 0, 82]),
    );
    final l10n = e2e.l10n;
    unawaited(e2e.container.read(routerProvider).push(Routes.settings));
    await e2e.settle();
    await e2e.scrollTo(find.text(l10n.settingsSignOut));
    await e2e.tapText(l10n.settingsSignOut);
    await e2e.waitFor(const Duration(seconds: 1));

    expect(e2e.visible(l10n.settingsSignOutConfirmTitle), isTrue);
    expect(e2e.visible(l10n.settingsSignOutConfirmBody), isTrue);
    // This session came in by email, and the demo persona subscribes.
    expect(
      e2e.visible(l10n.settingsSignOutMethodEmail),
      isTrue,
      reason: '${e2e.texts()}',
    );
    expect(e2e.visible(l10n.settingsSignOutPremium), isTrue);
    expect(e2e.visible(l10n.commonCancel), isTrue);
    expect(e2e.visible(l10n.settingsSignOutNewPlan), isTrue);

    await e2e.tapText(l10n.settingsSignOutNewPlan);
    await e2e.waitFor(const Duration(seconds: 1));
    expect(path(e2e), Routes.planNew);
    expect(journeyOf(e2e).plan.planNumber, 1, reason: 'still signed in');
  });
}
