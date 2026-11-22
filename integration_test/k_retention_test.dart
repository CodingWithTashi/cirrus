import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/app/reminder_copy.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/api/firebase/push_service.dart';
import 'package:last_puff/data/api/firebase/reminder_scheduler.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/data/stores/reminder_coordinator.dart';
import 'package:last_puff/domain/analytics/analytics.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/quit_program.dart';
import 'package:last_puff/domain/logic/reminder_planner.dart';
import 'package:last_puff/domain/logic/reminder_tap.dart';
import 'package:last_puff/domain/models/enums.dart';
import 'package:last_puff/firebase_options.dart';

import 'harness.dart';

/// The retention work of docs/10 §51, against the REAL platform pieces.
///
/// The widget suite injects every one of these, which is exactly why it could
/// not see the first bug this file was written to catch: firebase_messaging 16
/// reports a permanent Android refusal as its own value, and the app filed it
/// under "never asked". So here the scheduler is the real
/// `flutter_local_notifications` plugin on the device clock, and the
/// permission is the OS's own answer through FCM — Firebase is initialized for
/// messaging only; the data stays on the fake backend, so nothing is written
/// anywhere and no account is created.
///
/// Some steps need a hand outside the app — the OS permission dialog, the
/// notification shade. The test prints `E2E-MARKER:` lines and waits; the
/// driver (`adb`) watches for them. Run alone:
///
/// ```
/// adb uninstall com.quitvape.last_puff   # a never-asked permission
/// flutter test integration_test/k_retention_test.dart -d <device> \
///   --dart-define=LP_BACKEND=fake
/// ```
///
/// The plan-day-2 morning case needs the OS permission the FIRST case asks
/// for, and a grant does not outlive a run (`flutter test integration_test`
/// uninstalls the app when it ends), so that case is never run alone: either
/// the whole file, or the asking case and the morning in one invocation
/// (`--name` is a regex, and the first case's name has nothing in it to
/// escape):
///
/// ```
/// flutter test integration_test/k_retention_test.dart \
///   --name 'the second notification ask reads the OS, and its yes reaches the OS|plan-day-2 morning' \
///   -d <device> --dart-define=LP_BACKEND=fake
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

  void marker(String name) => debugPrint('E2E-MARKER: $name');

  /// The demo persona, with the real reminder scheduler and the real OS
  /// permission wired in where the fake backend would supply none.
  Future<E2E> signedIn(WidgetTester tester) async {
    final e2e = await E2E.boot(
      tester,
      overrides: [
        reminderCoordinatorProvider.overrideWithValue(
          ReminderCoordinator(scheduler),
        ),
        pushPermissionsProvider.overrideWithValue(
          const PlatformPushPermissions(),
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
    return e2e;
  }

  Future<List<PendingNotificationRequest>> pending() =>
      FlutterLocalNotificationsPlugin().pendingNotificationRequests();

  testWidgets('the second notification ask reads the OS, and its yes '
      'reaches the OS', (tester) async {
    final status = await PushService.permissionStatus();
    expect(
      status,
      PushPermission.notAsked,
      reason: 'needs a fresh install: the OS must never have been asked',
    );
    final e2e = await signedIn(tester);

    e2e.container.read(routerProvider).go(Routes.day1);
    await e2e.settle();
    await e2e.tapText(e2e.l10n.day1CtaHome);
    await e2e.waitFor(const Duration(seconds: 2));
    expect(
      e2e.showing(e2e.l10n.pushAskDayOneTitle),
      isTrue,
      reason: 'no ask after Day 1; on screen: ${e2e.texts()}',
    );
    marker('ask-sheet');
    await e2e.waitFor(const Duration(seconds: 6));

    await e2e.tapText(e2e.l10n.pushAskCta);
    marker('os-dialog');
    // The driver taps "Allow" on the system dialog.
    final end = DateTime.now().add(const Duration(seconds: 90));
    var granted = false;
    while (DateTime.now().isBefore(end)) {
      await e2e.waitFor(const Duration(seconds: 2));
      if (await PushService.permissionStatus() == PushPermission.granted) {
        granted = true;
        break;
      }
    }
    expect(granted, isTrue, reason: 'the OS never reported a grant');
    await e2e.waitFor(const Duration(seconds: 2));
    expect(
      e2e.container.read(routerProvider).state.uri.path,
      Routes.home,
      reason: 'on screen: ${e2e.texts()}',
    );
    expect(
      analytics.propsOfAll('notif_prompt'),
      contains(predicate<Map<String, Object>>((p) => p['granted'] == 'true')),
    );
    // Once, ever.
    expect(e2e.container.read(settingsStoreProvider).pushPromptShown, isTrue);
  });

  testWidgets('a week of evening check-ins sits on the device clock, and '
      'its switch takes down only its own', (tester) async {
    final e2e = await signedIn(tester);
    await e2e.waitFor(const Duration(seconds: 3));

    final journey = e2e.container.read(quitStoreProvider)!;
    final settings = e2e.container.read(settingsStoreProvider);
    final checkins = (await pending())
        .where((r) => CheckinReminderPlanner.ids.contains(r.id))
        .toList();
    final now = DateTime.now();
    final expected = CheckinReminderPlanner.plan(
      journey: journey,
      now: now,
      hour: settings.checkinHour,
      quietStartHour: settings.quietStartHour,
      quietEndHour: settings.quietEndHour,
      enabled: settings.checkinReminderOn,
    );
    debugPrint(
      'E2E-INFO: pending check-ins ${[for (final r in checkins) '${r.id}|${r.title}|${r.body}|${r.payload}']}',
    );
    expect(checkins, isNotEmpty, reason: 'nothing on the device clock');
    expect(checkins.length, expected.length);
    for (final c in expected) {
      final request = checkins.singleWhere((r) => r.id == c.reminder.id);
      // The payload carries the slot and plan day as well as the kind
      // (`checkin|evening|N|`), so it is the decoded tap that is the contract.
      final tap = ReminderTap.decode(request.payload);
      expect(tap?.kind, ReminderKind.checkin, reason: '${request.payload}');
      expect(tap?.slot, ProgramSlot.evening, reason: '${request.payload}');
      expect(request.title, e2e.l10n.checkinNotifTitle(c.planDay));
      expect(
        request.body,
        c.limit == 0
            ? e2e.l10n.checkinNotifBodyZero
            : e2e.l10n.checkinNotifBody(c.limit),
      );
    }

    final others = (await pending())
        .where((r) => !CheckinReminderPlanner.ids.contains(r.id))
        .map((r) => r.id)
        .toSet();
    e2e.container
        .read(settingsStoreProvider.notifier)
        .setCheckinReminder(false);
    await e2e.waitFor(const Duration(seconds: 3));
    final after = await pending();
    expect(
      after.where((r) => CheckinReminderPlanner.ids.contains(r.id)),
      isEmpty,
      reason: 'switched off, and the week is still armed',
    );
    expect(
      after.map((r) => r.id).toSet(),
      others,
      reason: 'switching the check-in off touched another schedule',
    );

    e2e.container.read(settingsStoreProvider.notifier).setCheckinReminder(true);
    await e2e.waitFor(const Duration(seconds: 3));
    expect(
      (await pending()).where((r) => CheckinReminderPlanner.ids.contains(r.id)),
      hasLength(expected.length),
    );

    // The Settings sheet, on a real font.
    e2e.container.read(routerProvider).go(Routes.settings);
    await e2e.settle();
    await e2e.tester.ensureVisible(
      find.text(e2e.l10n.settingsCheckin, skipOffstage: false).first,
    );
    await e2e.settle();
    await e2e.tapText(e2e.l10n.settingsCheckin);
    await e2e.waitFor(const Duration(seconds: 1));
    expect(e2e.showing(e2e.l10n.settingsCheckinToggle), isTrue);
    marker('checkin-sheet');
    await e2e.waitFor(const Duration(seconds: 6));
  });

  testWidgets('a check-in that fires is a real notification, and its tap '
      'lands on Home', (tester) async {
    final e2e = await signedIn(tester);
    e2e.container.read(routerProvider).go(Routes.stats);
    await e2e.settle();

    // Through the app's own scheduler instance, so the tap reaches the app's
    // own `opened` stream. An id outside 4000–4006, so no re-sync cancels it.
    // Counted before arming, so what is asserted is what THIS tap reported,
    // whatever ran earlier in the file.
    final reportedBefore = analytics.propsOfAll('reminder_opened').length;
    final at = DateTime.now().add(const Duration(seconds: 70));
    final armed = await scheduler.scheduleOnce(
      OneShotReminder(id: 4099, at: at),
      tap: const ReminderTap(ReminderKind.checkin),
      title: e2e.l10n.checkinNotifTitle(12),
      body: e2e.l10n.checkinNotifBody(9),
    );
    expect(armed, isTrue);
    marker('checkin-armed ${at.toIso8601String()}');

    // The driver waits for it in the shade and taps it.
    final end = DateTime.now().add(const Duration(minutes: 6));
    while (DateTime.now().isBefore(end)) {
      await e2e.waitFor(const Duration(seconds: 2));
      if (e2e.container.read(routerProvider).state.uri.path == Routes.home) {
        break;
      }
    }
    expect(
      e2e.container.read(routerProvider).state.uri.path,
      Routes.home,
      reason: 'the tap never routed; on screen: ${e2e.texts()}',
    );
    // Given a moment to report a second time, so a double report fails here.
    await e2e.waitFor(const Duration(seconds: 3));
    expect(analytics.propsOfAll('reminder_opened').skip(reportedBefore), [
      {'kind': 'checkin'},
    ], reason: 'exactly one new reminder_opened, and it is this tap\'s');
    marker('checkin-tapped');
  });

  testWidgets('a plan-day-2 morning that fires is a real notification, and '
      'its tap lands on Home with its slot', (tester) async {
    // A precondition, not a step: the first case in this file is the one that
    // asks the OS, and a grant does not outlive a run, so this one run alone
    // would skip it and fail much later and much less clearly — a `StateError:
    // No element` on iOS, a six-minute wait for a notification that was never
    // posted on Android. Fail here instead, saying what to do.
    expect(
      await PushService.permissionStatus(),
      PushPermission.granted,
      reason:
          'this case needs the OS notification permission already granted, '
          'and a grant does not outlive a run (flutter test integration_test '
          'uninstalls the app when it ends, and iOS shows no Notifications '
          'switch for an app that never asked). Run it in ONE invocation with '
          'the file\'s first case, which asks and has the driver tap Allow: '
          'flutter test integration_test/k_retention_test.dart --name '
          '\'the second notification ask reads the OS, and its yes reaches '
          'the OS|plan-day-2 morning\' -d <device> '
          '--dart-define=LP_BACKEND=fake (the whole file also works)',
    );
    final e2e = await signedIn(tester);
    e2e.container.read(routerProvider).go(Routes.stats);
    await e2e.settle();

    // Built through the REAL planner, from a plan whose day 1 is today: the
    // demo persona is on day 12, and a morning only exists for plan days 2
    // and 3. The journey is never committed — only planned against — so the
    // app's own coordinator keeps arming the persona's real day 12.
    //
    // One reading of the clock for both the plan's day one and the planner's
    // `now`: two readings straddling midnight would have the planner start from
    // plan day 2 and arm today's 09:00 rather than tomorrow's, a different
    // morning from the one this case describes.
    final now = DateTime.now();
    final persona = e2e.container.read(quitStoreProvider)!;
    final day1 = persona.copyWith(
      plan: persona.plan.copyWith(
        method: QuitMethod.taper,
        startDate: LpDate.dayStart(now),
      ),
    );
    final planned = CheckinReminderPlanner.plan(
      journey: day1,
      now: now,
      hour: 20,
      quietStartHour: 23,
      quietEndHour: 8,
      enabled: true,
    ).where((c) => c.slot == ProgramSlot.morning).toList();
    expect(
      planned,
      isNotEmpty,
      reason: 'the planner armed no morning for a taper on plan day 1',
    );
    final m = planned.first;
    // Fails loudly if the planner stops producing the morning this case is
    // about, rather than quietly testing some other notification.
    expect(m.planDay, 2, reason: '$m');
    expect(m.reminder.id, 5102, reason: '$m');
    expect(m.message, isNull, reason: 'a plain morning, not a program one: $m');

    final copy = checkinCopy(e2e.l10n, m);
    // Through the app's own scheduler instance, so the tap reaches the app's
    // own `opened` stream. Id 5199, outside 5102/5103 and the program's
    // 5000–5002, so no re-sync cancels it; the title and body are the planned
    // morning's own, the slot and day ride on its payload, and only the time
    // is brought forward to now + 70 seconds.
    // Counted before arming, so what is asserted is what THIS tap reported,
    // whatever ran earlier in the file.
    final reportedBefore = analytics.propsOfAll('reminder_opened').length;
    final at = DateTime.now().add(const Duration(seconds: 70));
    final armed = await scheduler.scheduleOnce(
      OneShotReminder(id: 5199, at: at),
      tap: m.tap,
      title: copy.title,
      body: copy.body,
    );
    expect(armed, isTrue);
    final onDevice = (await pending()).singleWhere((r) => r.id == 5199);
    expect(ReminderTap.decode(onDevice.payload), m.tap);
    expect(onDevice.title, copy.title);
    expect(onDevice.body, copy.body);
    // The title last: it has a space in it, and the driver searches the shade
    // for it.
    marker('morning-armed ${at.toIso8601String()} title=${copy.title}');

    // The driver waits for it in the shade and taps it.
    final end = DateTime.now().add(const Duration(minutes: 6));
    while (DateTime.now().isBefore(end)) {
      await e2e.waitFor(const Duration(seconds: 2));
      if (e2e.container.read(routerProvider).state.uri.path == Routes.home) {
        break;
      }
    }
    expect(
      e2e.container.read(routerProvider).state.uri.path,
      Routes.home,
      reason: 'the tap never routed; on screen: ${e2e.texts()}',
    );
    // Given a moment to report a second time, so a double report fails here.
    await e2e.waitFor(const Duration(seconds: 3));
    expect(analytics.propsOfAll('reminder_opened').skip(reportedBefore), [
      {'kind': 'checkin', 'slot': 'morning', 'plan_day': 2},
    ], reason: 'exactly one new reminder_opened, and it is this tap\'s');
    marker('morning-tapped');
  });

  testWidgets('on an offer day a free account gets a card on Home, never a '
      'paywall over it — and the paywall it opens closes', (tester) async {
    final e2e = await signedIn(tester);
    final fake = e2e.container.read(fakeServerProvider)
      ..putEntitlement({
        'tier': 'free',
        'productId': 'yearly_3999',
        'expiresAt': DateTime.now()
            .subtract(const Duration(days: 1))
            .toUtc()
            .toIso8601String(),
      });
    await e2e.container
        .read(entitlementProvider.notifier)
        .bindSession(fake.ensureSessionId());
    final store = e2e.container.read(quitStoreProvider.notifier);
    final journey = e2e.container.read(quitStoreProvider)!;
    // Plan day 14: an offer day.
    store.replaceForTest(
      journey.copyWith(
        plan: journey.plan.copyWith(
          startDate: LpDate.addDays(LpDate.dayStart(DateTime.now()), -13),
        ),
      ),
    );
    await e2e.waitFor(const Duration(seconds: 2));

    // A launch: the splash is what decides the offer.
    e2e.container.read(routerProvider).go(Routes.splash);
    await e2e.waitFor(const Duration(seconds: 6));
    expect(
      e2e.container.read(routerProvider).state.uri.path,
      Routes.home,
      reason: 'a launch put something over Home; on screen: ${e2e.texts()}',
    );
    final title = find.text(e2e.l10n.homeOfferTitle(14), skipOffstage: false);
    expect(title, findsOneWidget, reason: 'on screen: ${e2e.texts()}');
    await e2e.tester.ensureVisible(title);
    await e2e.settle();
    marker('offer-card');
    await e2e.waitFor(const Duration(seconds: 6));

    await e2e.tap(find.text(e2e.l10n.homeOfferTitle(14)), why: 'the card');
    await e2e.waitFor(const Duration(seconds: 2));
    expect(
      e2e.container.read(routerProvider).state.uri.toString(),
      Routes.paywallFrom('offer_card'),
    );
    marker('paywall');
    await e2e.waitFor(const Duration(seconds: 6));

    await e2e.tap(
      find.bySemanticsLabel(e2e.l10n.commonClose),
      why: 'the paywall close',
    );
    await e2e.waitFor(const Duration(seconds: 2));
    expect(e2e.container.read(routerProvider).state.uri.path, Routes.home);
    expect(
      find.text(e2e.l10n.homeOfferTitle(14), skipOffstage: false),
      findsNothing,
      reason: 'the card came back after it was opened',
    );
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
  void setUserProperties(Map<String, Object> properties) {}

  @override
  void reset() {}
}
