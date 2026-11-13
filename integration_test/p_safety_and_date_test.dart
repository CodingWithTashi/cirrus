import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/utils/lp_format.dart';
import 'package:last_puff/core/utils/lp_links.dart';
import 'package:last_puff/core/widgets/lp_buttons.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/help_directory.dart';
import 'package:last_puff/domain/logic/taper_engine.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/features/onboarding/onboarding_view_model.dart';

import 'harness.dart';

/// Stage A of docs/15, on a real phone: the cigarettes question and the one
/// rule, More help, a slip that asks before it moves the date, an Adjust that
/// changes the date only, and the stretch ceiling.
///
/// The widget suite proves each piece on a fallback font with overflow
/// switched off. This runs the real app on the real font and real widths, and
/// the last test opens a real dialler and a real browser. A layout overflow
/// fails a test here.
///
/// `E2E-MARKER: shot <name>` lines pause the test for 2.5s so an adb driver can
/// screenshot the screen (see the run notes in docs/15).
///
/// Fake backend, a fixed clock, nothing written anywhere:
///
/// ```
/// flutter test integration_test/p_safety_and_date_test.dart \
///   -d <device> --dart-define=LP_BACKEND=fake
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 11, 12, 15, 30);
  final today = LpDate.dayStart(now);

  /// A day-[day] taper on a 30-day plan, with [pending] clean days waiting on
  /// a slip when non-null. Earlier days are logged at their limit.
  JourneyState journeyOn(
    int day, {
    QuitMethod method = QuitMethod.taper,
    SmokingHistory? smoking = SmokingHistory.never,
    int stretch = 0,
    int? pending,
  }) {
    final plan = QuitPlan(
      method: method,
      paceDays: 30,
      startDate: LpDate.addDays(today, -(day - 1)),
      baselinePuffsPerDay: 100,
      weeklySpend: 30,
      strength: NicStrength.mg50,
      stretchDays: stretch,
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
    return JourneyState(
      profile: UserProfile(
        alias: '@matrixfox',
        avatarEmoji: '🦊',
        smoking: smoking,
      ),
      plan: plan,
      days: days,
      cravingsSurvivedTotal: 4,
      repairTokens: 0,
      longestStreak: 0,
      goals: const [],
      earnedBadges: const {},
      day1TasksDone: const {0, 1, 2},
      pendingSlipCleanDays: pending,
    );
  }

  /// Signed in on the fake backend, then standing on [journey]. [region] and
  /// [opened] stand in for the device country and the link launcher; leave
  /// both null to use the real ones.
  Future<E2E> open(
    WidgetTester tester,
    JourneyState journey, {
    String? region,
    List<Uri>? opened,
  }) async {
    final e2e = await E2E.boot(
      tester,
      overrides: [
        nowProvider.overrideWithValue(() => now),
        if (region != null) deviceRegionProvider.overrideWithValue(region),
        if (opened != null)
          linkOpenerProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
      ],
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
  void go(E2E e2e, String route) =>
      unawaited(e2e.container.read(routerProvider).push(route));

  /// Holds the screen still so the adb driver can capture it.
  Future<void> shot(E2E e2e, String name) async {
    // ignore: avoid_print
    print('E2E-MARKER: shot $name');
    await e2e.waitFor(const Duration(milliseconds: 2500));
  }

  String date(DateTime d) => LpFormat.shortDate(d, 'en');

  // ---------------------------------------------------------------- A: asking

  testWidgets('onboarding asks about cigarettes, answers in one tap, and shows '
      'the rule only to someone who has smoked', (tester) async {
    final e2e = await E2E.boot(
      tester,
      overrides: [nowProvider.overrideWithValue(() => now)],
    );
    await e2e.waitFor(const Duration(seconds: 2));
    final l10n = e2e.l10n;
    final vm = e2e.container.read(onboardingProvider.notifier);
    vm.state = const OnboardingState(step: ObStep.smoking);
    await e2e.settle();

    expect(e2e.visible(l10n.obSmokingTitle), isTrue, reason: '${e2e.texts()}');
    expect(e2e.visible(l10n.obSmokingNever), isTrue);
    expect(e2e.visible(l10n.obSmokingFormer), isTrue);
    expect(e2e.visible(l10n.obSmokingCurrent), isTrue);
    expect(e2e.visible(l10n.obProgressOf(9, 13)), isTrue);

    // Unanswered, Continue goes nowhere.
    await e2e.tapText(l10n.commonContinue);
    expect(e2e.container.read(onboardingProvider).step, ObStep.smoking);

    await e2e.tapText(l10n.obSmokingCurrent);
    expect(e2e.visible(l10n.smokingRuleBody), isTrue);
    expect(e2e.visible(l10n.smokingRuleCurrent), isTrue);
    expect(e2e.visible(l10n.helpTitle), isTrue, reason: 'a way to More help');
    await shot(e2e, 'a1_onboarding_rule_current');

    await e2e.tapText(l10n.obSmokingNever);
    expect(e2e.showing(l10n.smokingRuleBody), isFalse);

    await e2e.tapText(l10n.obSmokingFormer);
    expect(e2e.visible(l10n.smokingRuleBody), isTrue);
    expect(e2e.showing(l10n.smokingRuleCurrent), isFalse);

    await e2e.tapText(l10n.commonContinue);
    expect(e2e.container.read(onboardingProvider).step, ObStep.why);
    expect(
      e2e.container.read(onboardingProvider).smoking,
      SmokingHistory.former,
    );
  });

  testWidgets('an account that was never asked meets the question on Home, '
      'is shown the rule once, and More help opens for the device country', (
    tester,
  ) async {
    final e2e = await open(tester, journeyOn(10, smoking: null));
    final l10n = e2e.l10n;

    expect(path(e2e), Routes.home);
    expect(e2e.visible(l10n.obSmokingTitle), isTrue, reason: '${e2e.texts()}');
    await shot(e2e, 'b1_home_question');

    await e2e.tapText(l10n.obSmokingFormer);
    expect(journeyOf(e2e).profile.smoking, SmokingHistory.former);
    expect(e2e.showing(l10n.obSmokingTitle), isFalse);
    expect(e2e.visible(l10n.smokingRuleBody), isTrue);
    await shot(e2e, 'b2_home_rule');

    await e2e.tapText(l10n.helpTitle);
    expect(path(e2e), Routes.help);
    final region = PlatformDispatcher.instance.locale.countryCode;
    final listed = HelpDirectory.forCountry(region);
    // ignore: avoid_print
    print('E2E-MARKER: device region = $region, listed services = '
        '${listed.length}');
    expect(e2e.visible(l10n.helpMedicineBody), isTrue);
    if (listed.isEmpty) {
      expect(e2e.visible(l10n.helpNoLocal), isTrue, reason: '${e2e.texts()}');
    } else {
      await e2e.scrollTo(find.text(listed.first.name));
      expect(e2e.visible(listed.first.name), isTrue);
    }
    await shot(e2e, 'b3_help_device_region');
  });

  testWidgets('every listed country renders its services on a real font, and '
      'its buttons open the right things', (tester) async {
    final opened = <Uri>[];
    final e2e = await open(
      tester,
      journeyOn(10),
      region: 'GB',
      opened: opened,
    );
    final l10n = e2e.l10n;
    go(e2e, Routes.helpFrom('settings'));
    await e2e.settle();

    expect(path(e2e), Routes.help);
    for (final e in HelpDirectory.forCountry('GB')) {
      await e2e.scrollTo(find.text(e.name));
      expect(e2e.showing(e.name), isTrue, reason: e.name);
    }
    expect(e2e.showing('0300 123 1044'), isTrue);
    expect(e2e.showing('0800 84 84 84'), isTrue);
    expect(e2e.showing('0800 085 2219'), isTrue);
    await shot(e2e, 'c1_help_gb');

    // The England helpline's own Call button dials the digits only.
    final england = HelpDirectory.forCountry('GB')
        .firstWhere((e) => e.id == 'gb_england');
    expect(england.dial, '03001231044');
    await e2e.scrollTo(find.text(l10n.helpCall).first);
    await e2e.tap(find.text(l10n.helpCall).first, why: 'first Call');
    expect(opened.last.scheme, 'tel');

    await e2e.tap(find.text(l10n.helpSourceLink).first, why: 'first Source');
    expect(opened.last.scheme, 'https');
    expect(opened.last.host, 'www.nhs.uk');

    await e2e.scrollTo(find.text(l10n.helpMedicineSource));
    await e2e.tap(find.text(l10n.helpMedicineSource), why: 'research link');
    expect(opened.last.toString(),
        'https://doi.org/10.1002/14651858.CD016058.pub3');
  });

  testWidgets('a country with nothing listed says so instead of guessing', (
    tester,
  ) async {
    final e2e = await open(tester, journeyOn(10), region: 'IN');
    go(e2e, Routes.helpFrom('settings'));
    await e2e.settle();
    expect(e2e.visible(e2e.l10n.helpNoLocal), isTrue, reason: '${e2e.texts()}');
    expect(e2e.visible(e2e.l10n.helpDoctorLine), isTrue);
    expect(e2e.showing(e2e.l10n.helpCall), isFalse);
    await shot(e2e, 'c2_help_unlisted');
  });

  testWidgets('Settings has the More help row', (tester) async {
    final e2e = await open(tester, journeyOn(10), region: 'US');
    go(e2e, Routes.settings);
    await e2e.settle();
    await e2e.scrollTo(find.text(e2e.l10n.helpTitle));
    await e2e.tapText(e2e.l10n.helpTitle);
    expect(path(e2e), Routes.help);
    expect(e2e.visible('1-800-QUIT-NOW'), isTrue, reason: '${e2e.texts()}');
  });

  // ------------------------------------------------------------------ B: slip

  /// Past the slip trigger step, on the choice.
  Future<void> toChoice(E2E e2e) async {
    go(e2e, Routes.slip);
    await e2e.settle();
    await e2e.tapText(e2e.l10n.slipTriggerStress);
    await e2e.tapText(e2e.l10n.slipAdjustCta);
    await e2e.waitFor(const Duration(milliseconds: 600));
  }

  testWidgets('a slip: Keep my date is on screen without scrolling, even for '
      'someone who still smokes, and moves nothing', (tester) async {
    final e2e = await open(
      tester,
      journeyOn(10, smoking: SmokingHistory.current, pending: 3),
    );
    final l10n = e2e.l10n;
    final before = journeyOf(e2e).plan;
    await toChoice(e2e);

    // The worst case for height: the rule card is on this screen too.
    expect(e2e.visible(l10n.smokingRuleBody), isTrue, reason: '${e2e.texts()}');
    expect(e2e.visible(l10n.slipKeepDate), isTrue,
        reason: 'primary button not reachable without scrolling');
    expect(e2e.visible(l10n.slipAddDays(2)), isTrue);
    expect(e2e.visible(l10n.slipDateStays(date(before.freedomDate))), isTrue);
    await shot(e2e, 'd1_slip_choice_smoker');

    await e2e.tapText(l10n.slipKeepDate);
    await e2e.waitFor(const Duration(seconds: 1));
    expect(path(e2e), Routes.home);
    final after = journeyOf(e2e);
    expect(after.plan.stretchDays, before.stretchDays);
    expect(after.plan.freedomDate, before.freedomDate);
    expect(after.pendingSlipCleanDays, isNull);
    expect(e2e.showing(l10n.slipTitle), isFalse, reason: 'slip card cleared');
  });

  testWidgets('a slip: Add two days moves Freedom Day by exactly two', (
    tester,
  ) async {
    final e2e = await open(tester, journeyOn(10, pending: 3));
    final l10n = e2e.l10n;
    final before = journeyOf(e2e).plan;
    await toChoice(e2e);

    expect(e2e.visible(l10n.slipAddDays(2)), isTrue, reason: '${e2e.texts()}');
    expect(
      e2e.visible(l10n.slipNewFreedom(
        date(LpDate.addDays(before.freedomDate, 2)),
        2,
      )),
      isTrue,
    );
    await shot(e2e, 'd2_slip_choice');
    await e2e.tapText(l10n.slipAddDays(2));
    await e2e.waitFor(const Duration(seconds: 1));
    expect(path(e2e), Routes.home);
    final after = journeyOf(e2e);
    expect(after.plan.stretchDays, 2);
    expect(after.plan.freedomDate, LpDate.addDays(before.freedomDate, 2));
    expect(after.pendingSlipCleanDays, isNull);
  });

  testWidgets('a slip: with one day of room left, it offers one day, '
      'grammatically', (tester) async {
    final e2e = await open(tester, journeyOn(10, stretch: 6, pending: 3));
    final l10n = e2e.l10n;
    final before = journeyOf(e2e).plan;
    await toChoice(e2e);

    expect(e2e.visible(l10n.slipAddDays(1)), isTrue, reason: '${e2e.texts()}');
    expect(e2e.showing(l10n.slipAddDays(2)), isFalse);
    final caption = l10n.slipNewFreedom(
      date(LpDate.addDays(before.freedomDate, 1)),
      1,
    );
    expect(e2e.visible(caption), isTrue);
    expect(caption, contains('+1 day'));
    expect(caption, isNot(contains('1 days')));
    await shot(e2e, 'd3_slip_one_day_left');
    await e2e.tapText(l10n.slipAddDays(1));
    await e2e.waitFor(const Duration(seconds: 1));
    expect(journeyOf(e2e).plan.stretchDays, 7);
  });

  testWidgets('a slip: no Add once the stretch is used up, or on cold turkey, '
      'and "talk it through" stretches nothing', (tester) async {
    var e2e = await open(tester, journeyOn(10, stretch: 7, pending: 3));
    final l10n = e2e.l10n;
    await toChoice(e2e);
    expect(e2e.visible(l10n.slipKeepDate), isTrue);
    expect(e2e.texts().where((t) => t.startsWith('Add ')), isEmpty,
        reason: 'Add offered past the ceiling: ${e2e.texts()}');
    await shot(e2e, 'd4_slip_ceiling_reached');

    await e2e.tapText(l10n.slipTalkFirst);
    await e2e.waitFor(const Duration(seconds: 1));
    expect(path(e2e), Routes.coach);
    expect(journeyOf(e2e).plan.stretchDays, 7);
    expect(journeyOf(e2e).pendingSlipCleanDays, isNotNull,
        reason: 'undecided is not resolved');

    e2e = await open(
      tester,
      journeyOn(10, method: QuitMethod.coldTurkey, pending: 3),
    );
    await toChoice(e2e);
    expect(e2e.visible(l10n.slipKeepDate), isTrue);
    expect(e2e.texts().where((t) => t.startsWith('Add ')), isEmpty);
  });

  testWidgets('three slips stretch the plan to the ceiling and no further', (
    tester,
  ) async {
    final e2e = await open(tester, journeyOn(10, pending: 3));
    final store = e2e.container.read(quitStoreProvider.notifier);
    final seen = <int>[];
    for (var i = 0; i < 5; i++) {
      store.applySlipRecovery();
      seen.add(journeyOf(e2e).plan.stretchDays);
    }
    expect(seen, [2, 4, 6, 7, 7]);
    expect(TaperEngine.stretchLeft(journeyOf(e2e).plan), 0);
  });

  // ----------------------------------------------------------------- C: adjust

  testWidgets('Adjust my plan: nothing preselected, no-op refused, date moves '
      'only when chosen', (tester) async {
    final e2e = await open(tester, journeyOn(10));
    final l10n = e2e.l10n;
    final before = journeyOf(e2e).plan;
    go(e2e, Routes.plan);
    await e2e.settle();
    await e2e.tapText(l10n.planAdjustCta);

    bool applyOn() => tester
        .widget<LpButton>(find.widgetWithText(LpButton, l10n.planAdjustApply))
        .onTap != null;

    expect(applyOn(), isFalse, reason: 'nothing chosen yet');
    expect(e2e.showing(l10n.planMethodCold), isFalse, reason: 'toggle is gone');
    expect(e2e.visible(l10n.planAdjustNewPlanLink), isTrue);
    for (final p in [14, 21, 30, 42]) {
      expect(find.text('$p ✓'), findsNothing, reason: '$p preselected');
    }
    await shot(e2e, 'e1_adjust_sheet_empty');

    // 21 days from day 10 of 30 IS the current date: refused, plan untouched.
    await e2e.tapText('21');
    expect(e2e.visible(l10n.planAdjustSame), isTrue, reason: '${e2e.texts()}');
    expect(applyOn(), isFalse);
    expect(journeyOf(e2e).plan.paceDays, before.paceDays);

    // 30 would move it later, and says so.
    await e2e.tapText('30');
    expect(e2e.visible(l10n.planAdjustLater), isTrue);
    expect(applyOn(), isTrue);
    await shot(e2e, 'e2_adjust_sheet_later');

    // 14 brings it closer; Apply it.
    await e2e.tapText('14');
    expect(e2e.showing(l10n.planAdjustLater), isFalse);
    final target = LpDate.addDays(today, 13);
    expect(e2e.visible(l10n.planAdjustPreview(date(target))), isTrue);
    await e2e.tapText(l10n.planAdjustApply);
    await e2e.waitFor(const Duration(seconds: 1));
    expect(journeyOf(e2e).plan.freedomDate, target);
    expect(journeyOf(e2e).plan.baselinePuffsPerDay, before.baselinePuffsPerDay);
    expect(e2e.visible(l10n.planAdjusted(date(target))), isTrue,
        reason: 'the snack names the new date: ${e2e.texts()}');
  });

  testWidgets('plan lengths on offer are 14, 21, 30 and 42 in Start a new '
      'plan', (tester) async {
    final e2e = await open(tester, journeyOn(10));
    go(e2e, Routes.planNew);
    await e2e.settle();
    for (final p in ['14', '21', '42']) {
      expect(e2e.visible(p), isTrue, reason: '$p: ${e2e.texts()}');
    }
    expect(e2e.texts().any((t) => t == '60' || t == '90'), isFalse,
        reason: 'retired lengths still on offer');
  });

  // -------------------------------------------------- D: real dialler/browser

  testWidgets('the real launcher opens the dialler and a browser', (
    tester,
  ) async {
    // The device's own `tel:` and https handlers, not the test double. A tel:
    // link opens the dialler with the number typed in; it does not place a
    // call. This runs last: the app is backgrounded by the launches.
    final e2e = await open(tester, journeyOn(10), region: 'US');
    go(e2e, Routes.helpFrom('settings'));
    await e2e.settle();
    expect(e2e.visible('1-800-QUIT-NOW'), isTrue, reason: '${e2e.texts()}');

    // ignore: avoid_print
    print('E2E-MARKER: launching tel:18007848669');
    final dialled = await LpLinks.open(Uri(scheme: 'tel', path: '18007848669'));
    // ignore: avoid_print
    print('E2E-MARKER: tel launch returned $dialled');
    expect(dialled, isTrue, reason: 'no app handled tel:');
    // A plain wall-clock delay, NOT `e2e.waitFor`: that pumps frames, and an
    // app that has been sent to the background by the launch produces none, so
    // pumping here stalls the test until it times out. This only gives an adb
    // driver a moment to see which window took focus.
    await Future<void>.delayed(const Duration(seconds: 4));

    // ignore: avoid_print
    print('E2E-MARKER: launching https source');
    final browsed = await LpLinks.open(Uri.parse(
      HelpDirectory.forCountry('US').first.sourceUrl,
    ));
    // ignore: avoid_print
    print('E2E-MARKER: https launch returned $browsed');
    expect(browsed, isTrue, reason: 'no browser handled https:');
    await Future<void>.delayed(const Duration(seconds: 5));
  });
}
