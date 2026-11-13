import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/utils/program_copy.dart';
import 'package:last_puff/data/api/firebase/reminder_scheduler.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/data/stores/reminder_coordinator.dart';
import 'package:last_puff/domain/analytics/analytics.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/quit_program.dart';
import 'package:last_puff/domain/logic/reminder_planner.dart';
import 'package:last_puff/domain/logic/taper_engine.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/features/home/widgets/program_card.dart';
import 'package:last_puff/firebase_options.dart';

import 'harness.dart';

/// docs/15 stage B on a real phone: the daily program.
///
/// The earlier device fixtures sit on a day-12 taper, which is outside the
/// program, so they prove nothing about it. This runs the real app on the real
/// font with the REAL notification scheduler, and reads what the OS actually
/// holds — id, payload and body — through `pendingNotificationRequests()`.
///
/// **Reading the OS list instead of the shade** is deliberate. A phone in Do Not
/// Disturb posts a notification and shows nothing, so a test that waits for one
/// on screen cannot be driven (docs/10 §52). The pending list is the same
/// contract, and it cannot be hidden. What it cannot show is a TAP; that stays
/// with `m_reminder_tap_test.dart`.
///
/// **The clock is the device's.** The scheduler refuses an instant in the past,
/// so nothing here is pinned to a date. The fixture is a cold-turkey account on
/// its quit day (plan day one, program day zero), where tomorrow's 09:00 message
/// is always ahead of now whatever time the suite runs.
///
/// `E2E-MARKER: shot <name>` lines pause 2.5s for an adb driver to screenshot.
/// Do not pump frames after the app has been sent to the background.
///
/// ```
/// flutter test integration_test/o_quit_program_test.dart -d <device> \
///   --dart-define=LP_BACKEND=fake
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final scheduler = ReminderScheduler();
  final analytics = _Recording();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  });

  // Nothing armed by one test may be pending in the next.
  tearDown(() => FlutterLocalNotificationsPlugin().cancelAll());

  Future<List<PendingNotificationRequest>> pending() =>
      FlutterLocalNotificationsPlugin().pendingNotificationRequests();

  Future<void> shot(E2E e2e, String name) async {
    debugPrint('E2E-MARKER: shot $name');
    await e2e.waitFor(const Duration(milliseconds: 2500));
  }

  /// A cold-turkey account on plan day [day] of the DEVICE's own clock, setup
  /// finished, cigarettes answered, so no other card competes for the slot.
  JourneyState coldOn(int day, {SmokingHistory smoking = SmokingHistory.never}) {
    final today = LpDate.dayStart(DateTime.now());
    final plan = QuitPlan(
      method: QuitMethod.coldTurkey,
      paceDays: 30,
      startDate: LpDate.addDays(today, -(day - 1)),
      baselinePuffsPerDay: 100,
      weeklySpend: 30,
      strength: NicStrength.mg50,
    );
    final days = <DateTime, DayLog>{};
    for (var d = 1; d < day; d++) {
      final date = LpDate.addDays(plan.startDate, d - 1);
      days[date] = DayLog(
        date: date,
        puffs: 0,
        limit: TaperEngine.limitFor(plan, d),
        vapeFreeConfirmed: true,
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
      cravingsSurvivedTotal: 3,
      repairTokens: 0,
      longestStreak: 0,
      goals: const [],
      earnedBadges: const {},
      day1TasksDone: const {0, 1, 2},
    );
  }

  Future<E2E> open(WidgetTester tester, JourneyState journey) async {
    final e2e = await E2E.boot(
      tester,
      overrides: [
        reminderCoordinatorProvider.overrideWithValue(
          ReminderCoordinator(scheduler),
        ),
        analyticsProvider.overrideWithValue(analytics),
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
    await e2e.waitFor(const Duration(seconds: 3));
    return e2e;
  }

  String path(E2E e2e) => e2e.container.read(routerProvider).state.uri.path;
  JourneyState journeyOf(E2E e2e) => e2e.container.read(quitStoreProvider)!;
  Finder inCard(String text) =>
      find.descendant(of: find.byType(ProgramCard), matching: find.text(text));

  testWidgets('a cold-turkey quit day: the card, a mood, and the reply', (
    tester,
  ) async {
    final e2e = await open(tester, coldOn(1));
    final l10n = e2e.l10n;
    expect(path(e2e), Routes.home, reason: '${e2e.texts()}');

    // Program day zero: the card is up, with the day in its title.
    expect(find.byType(ProgramCard), findsOneWidget, reason: '${e2e.texts()}');
    expect(inCard(l10n.programCardTitle(1)), findsOneWidget);
    expect(inCard(l10n.programQuestion), findsOneWidget);
    for (final label in [
      l10n.programBtnCraving,
      l10n.programBtnStress,
      l10n.programBtnSlipped,
      l10n.programBtnMore,
    ]) {
      expect(e2e.visible(label), isTrue, reason: '$label hit-testable');
    }
    await shot(e2e, 'p1_program_card_quit_day');

    await e2e.tap(inCard(l10n.moodRough), why: 'the rough chip');
    final j = journeyOf(e2e);
    expect(j.logFor(DateTime.now())!.mood, Mood.rough);
    final reply = QuitProgram.replyFor(
      Mood.rough,
      ProgramTrack.onTrack,
      seed: j.plan.dayNumber(DateTime.now()),
      hasWhy: false,
    ).text(l10n);
    expect(e2e.showing(reply), isTrue, reason: 'the written reply: ${e2e.texts()}');
    await shot(e2e, 'p2_program_reply');

    expect(analytics.propsOfAll('program_reply'), [
      {'mood': 'rough', 'track': 'onTrack'},
    ]);
    // The old evening mood prompt does not also appear: one check-in a day.
    expect(e2e.showing(l10n.moodTitle), isFalse);
  });

  testWidgets('tomorrow\'s 09:00 message is pending on the OS with the program '
      'payload and its full text', (tester) async {
    final e2e = await open(tester, coldOn(1));
    final l10n = e2e.l10n;
    await e2e.waitFor(const Duration(seconds: 2));

    final all = await pending();
    final program = all.where((r) => r.payload == 'program').toList();
    expect(program, isNotEmpty, reason: 'pending: ${all.map((r) => r.id)}');
    // ignore: avoid_print
    print('E2E-MARKER: pending program ids ${program.map((r) => r.id).toList()}');

    // Program day one's morning: id 5001, tomorrow at 09:00, its own words.
    final d1am = program.where((r) => r.id == 5001).toList();
    expect(d1am, hasLength(1), reason: 'ids: ${program.map((r) => r.id)}');
    expect(d1am.single.body, ProgramMessage.d1am.text(l10n));
    expect(d1am.single.title, l10n.checkinNotifTitle(2));

    // Day two's morning too, and each evening with its own message.
    final d2am = program.where((r) => r.id == 5002).single;
    expect(d2am.body, ProgramMessage.d2am.text(l10n));
    final d1pm = program.where((r) => r.id == 4001).single;
    expect(d1pm.body, ProgramMessage.d1pm.text(l10n));

    // Every program body is a program message — never a check-in's sentence —
    // and nothing exceeds what the plan allows pending at once.
    final bodies = {
      for (final m in ProgramMessage.values) m.text(l10n),
    };
    for (final r in program) {
      expect(bodies, contains(r.body), reason: 'id ${r.id}: ${r.body}');
    }
    expect(all.length, lessThanOrEqualTo(19));
  });

  testWidgets('switching the daily message off takes down its own ids and '
      'nothing else', (tester) async {
    final e2e = await open(tester, coldOn(1));
    await e2e.waitFor(const Duration(seconds: 2));

    // Something that is NOT the program's, armed through the same scheduler.
    final other = OneShotReminder(
      id: TrialReminderPlanner.id,
      at: DateTime.now().add(const Duration(hours: 2)),
    );
    expect(
      await scheduler.scheduleOnce(
        other,
        kind: ReminderKind.trial,
        title: 'trial',
        body: 'a trial reminder',
      ),
      isTrue,
    );

    final programIds = {
      ...CheckinReminderPlanner.ids,
      ...CheckinReminderPlanner.morningIds,
    };
    expect(
      (await pending()).any((r) => programIds.contains(r.id)),
      isTrue,
      reason: 'premise: the program is armed',
    );

    e2e.container.read(settingsStoreProvider.notifier).setCheckinReminder(false);
    await e2e.waitFor(const Duration(seconds: 3));

    final after = await pending();
    expect(
      after.where((r) => programIds.contains(r.id)),
      isEmpty,
      reason: 'left behind: ${after.map((r) => r.id)}',
    );
    expect(
      after.any((r) => r.id == TrialReminderPlanner.id),
      isTrue,
      reason: 'the trial reminder is not the program\'s to cancel',
    );

    // And it comes back with the switch.
    e2e.container.read(settingsStoreProvider.notifier).setCheckinReminder(true);
    await e2e.waitFor(const Duration(seconds: 3));
    expect(
      (await pending()).where((r) => r.payload == 'program'),
      isNotEmpty,
    );
  });

  testWidgets('a program day with a check-up: the nicotine question follows '
      'the reply, and cigarettes brings up the one rule', (tester) async {
    // Plan day 8 is program day seven.
    final e2e = await open(tester, coldOn(8));
    final l10n = e2e.l10n;
    expect(find.byType(ProgramCard), findsOneWidget, reason: '${e2e.texts()}');
    expect(inCard(l10n.programCheckupNicotineQ), findsNothing);

    await e2e.tap(inCard(l10n.moodOkay), why: 'the okay chip');
    expect(inCard(l10n.programCheckupNicotineQ), findsOneWidget,
        reason: 'after the reply: ${e2e.texts()}');
    await shot(e2e, 'p3_program_checkup');

    await e2e.tap(inCard(l10n.programCheckupCigarettes), why: 'cigarettes');
    expect(
      journeyOf(e2e).checkups[LpDate.dayStart(DateTime.now())],
      {CheckupKind.nicotine: CheckupAnswer.cigarettes},
    );
    expect(e2e.showing(l10n.smokingRuleBody), isTrue);
    expect(analytics.propsOfAll('checkup_answered'), [
      {'kind': 'nicotine', 'answer': 'cigarettes'},
    ]);
    await shot(e2e, 'p4_program_checkup_rule');
  });

  testWidgets('Stress: a minute to breathe, on the real renderer', (tester) async {
    final e2e = await open(tester, coldOn(3));
    final l10n = e2e.l10n;
    await e2e.tap(inCard(l10n.programBtnStress), why: 'Stress');
    expect(e2e.showing(l10n.programStressTitle), isTrue,
        reason: '${e2e.texts()}');
    // Let the ring run for a moment: a painter that divided by the missing hold
    // phase would throw here.
    await e2e.waitFor(const Duration(seconds: 3));
    await shot(e2e, 'p5_program_stress');
    await e2e.tapText(l10n.commonDone);
    expect(e2e.showing(l10n.programStressTitle), isFalse);
  });

  testWidgets('Slipped: the doors, and nothing moved', (tester) async {
    final e2e = await open(tester, coldOn(3, smoking: SmokingHistory.former));
    final l10n = e2e.l10n;
    final before = journeyOf(e2e).plan;
    await e2e.tap(inCard(l10n.programBtnSlipped), why: 'Slipped');
    expect(e2e.showing(l10n.programSlippedTitle), isTrue);
    expect(e2e.showing(l10n.smokingRuleBody), isTrue,
        reason: 'a former smoker sees the one rule');
    await shot(e2e, 'p6_program_slipped');
    expect(journeyOf(e2e).plan.freedomDate, before.freedomDate);

    await e2e.tapText(l10n.planNewCta);
    expect(path(e2e), Routes.planNew);
  });

  testWidgets('the 90-day question has its own card', (tester) async {
    // Plan day 92 is program day 91, past the end of the program.
    final e2e = await open(tester, coldOn(92));
    final l10n = e2e.l10n;
    expect(find.byType(ProgramCard), findsNothing);
    expect(find.byType(Program90Card), findsOneWidget,
        reason: '${e2e.texts()}');
    await shot(e2e, 'p7_program_90');
    await e2e.tapText(l10n.programCheckupNone);
    expect(
      journeyOf(e2e).checkups[LpDate.dayStart(DateTime.now())],
      {CheckupKind.vaped90: CheckupAnswer.notVaped},
    );
    expect(analytics.propsOfAll('quit_status_reported'), [
      {'at': 90, 'vape_free': 'true'},
    ]);
  });
}

class _Recording implements AnalyticsSink {
  final List<AnalyticsEvent> events = [];

  List<Map<String, Object>> propsOfAll(String name) => [
    for (final e in events)
      if (e.name == name) e.props,
  ];

  @override
  void track(AnalyticsEvent event) => events.add(event);

  @override
  void screenViewed(String name) {}

  @override
  void identify(String userId) {}

  @override
  void reset() {}
}
