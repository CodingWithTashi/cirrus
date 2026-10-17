import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/api/firebase/push_service.dart';
import 'package:last_puff/data/api/firebase/reminder_scheduler.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/data/stores/reminder_coordinator.dart';
import 'package:last_puff/domain/analytics/analytics.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/reminder_planner.dart';
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
      expect(request.payload, ReminderKind.checkin.name);
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
    final at = DateTime.now().add(const Duration(seconds: 70));
    final armed = await scheduler.scheduleOnce(
      OneShotReminder(id: 4099, at: at),
      kind: ReminderKind.checkin,
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
    expect(analytics.propsOfAll('reminder_opened'), [
      {'kind': 'checkin'},
    ]);
    marker('checkin-tapped');
    await e2e.waitFor(const Duration(seconds: 3));
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
  void reset() {}
}
