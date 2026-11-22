import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/data/api/firebase/reminder_scheduler.dart';
import 'package:last_puff/domain/logic/reminder_planner.dart';
import 'package:last_puff/domain/logic/reminder_tap.dart';

/// A tapped reminder reaches Dart — on the platform's own notification, with
/// the app's own app delegate.
///
/// The one thing no widget test can see: `reminder_tap_test.dart` injects the
/// tap. On an iPhone the tap comes from `UNUserNotificationCenter`, through
/// its delegate, through `FlutterAppDelegate`, into the plugin — and until
/// Nov 12 2026 nothing was the delegate, so not one tap ever arrived (zero
/// `reminder_opened` from 114 iPhones in four weeks).
///
/// Uses the real [ReminderScheduler] and nothing else of the app: no backend,
/// no account, nothing written anywhere. Two steps need a hand outside the
/// app, announced on `E2E-MARKER:` lines — the OS permission sheet, then the
/// banner itself:
///
/// ```
/// flutter test integration_test/m_reminder_tap_test.dart -d <simulator> \
///   --dart-define=LP_BACKEND=fake
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a tap on a scheduled reminder is delivered with its kind', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('reminder tap probe'))),
      ),
    );

    final scheduler = ReminderScheduler();
    final opened = Completer<ReminderTap>();
    final taps = scheduler.opened.listen((tap) {
      if (!opened.isCompleted) opened.complete(tap);
    });
    addTearDown(taps.cancel);

    debugPrint('E2E-MARKER: permission');
    final plugin = FlutterLocalNotificationsPlugin();
    final granted =
        await plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true) ??
        await plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
    debugPrint('E2E-MARKER: permission-answered $granted');
    expect(granted, isTrue, reason: 'the hand outside the app taps Allow');

    final armed = await scheduler.scheduleOnce(
      OneShotReminder(
        id: 4999,
        at: DateTime.now().add(const Duration(seconds: 8)),
      ),
      tap: const ReminderTap(ReminderKind.checkin),
      title: 'Cirrus tap probe',
      body: 'Tap this banner',
    );
    expect(armed, isTrue);
    debugPrint('E2E-MARKER: scheduled');

    final tap = await opened.future.timeout(
      const Duration(seconds: 150),
      onTimeout: () => fail('no tap reached Dart within 150 s'),
    );
    debugPrint('E2E-MARKER: opened ${tap.kind.name}');
    expect(tap, const ReminderTap(ReminderKind.checkin));
  });
}
