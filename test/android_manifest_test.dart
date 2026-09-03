import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Android manifest is a shippability gate, so it gets a test.
///
/// Google Play rejected the Sep 2026 submission with: "Your app uses the
/// USE_EXACT_ALARM permission. If your app's core functionality is not
/// 'calendar' or 'alarm clock', you're not eligible to use this permission and
/// must remove it from your app, across all tracks."
///
/// It was never needed. Both reminder paths schedule with
/// `AndroidScheduleMode.inexactAllowWhileIdle`, which the plugin routes to
/// `AlarmManagerCompat.setAndAllowWhileIdle` — no exact-alarm permission is
/// consulted on that branch. The two `uses-permission` lines were pure
/// declaration: they bought nothing at runtime and cost the release.
///
/// The other half is the mirror image — a manifest entry that IS load-bearing
/// and was missing. Since v16 the plugin declares only `POST_NOTIFICATIONS`
/// and `VIBRATE` in its own manifest, so the two receivers `AlarmManager`
/// delivers to belong to the host app. Without them every `zonedSchedule()`
/// armed an alarm that fired into an undeclared component: no notification,
/// no error, planner and coordinator both correct. Exactly the shape of the
/// `periodicallyShow` bug this feature already survived once.
void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  /// The `uses-permission` entries only. Matching on the raw string would
  /// let the comment that explains WHY the exact-alarm permissions are gone
  /// fail the test for naming them.
  final declared = RegExp(r'<uses-permission[^>]*android:name="([^"]+)"')
      .allMatches(manifest)
      .map((m) => m.group(1)!)
      .toSet();

  bool declaresPermission(String name) =>
      declared.contains('android.permission.$name');

  final receivers = RegExp(r'<receiver[^>]*android:name="([^"]+)"', dotAll: true)
      .allMatches(manifest)
      .map((m) => m.group(1)!)
      .toSet();

  bool declaresReceiver(String name) =>
      receivers.contains('com.dexterous.flutterlocalnotifications.$name');

  group('AndroidManifest', () {
    test('declares no restricted exact-alarm permission', () {
      // Play restricts USE_EXACT_ALARM to calendar and alarm-clock apps, and
      // gates SCHEDULE_EXACT_ALARM behind the same policy question. Cirrus is
      // neither, and its reminders are inexact by design — so neither may
      // appear here, in a plugin we add, or in a `tools:` merge rule.
      expect(declaresPermission('USE_EXACT_ALARM'), isFalse);
      expect(declaresPermission('SCHEDULE_EXACT_ALARM'), isFalse);
    });

    test('schedules inexactly, matching the permissions it declares', () {
      final scheduler = File(
        'lib/data/api/firebase/reminder_scheduler.dart',
      ).readAsStringSync();
      // The manifest and the schedule mode are one decision in two files. An
      // `exact` mode here throws `ExactAlarmPermissionException` on every
      // Android 14 device, because the permission it needs is gone for good.
      expect(scheduler.contains('AndroidScheduleMode.exact'), isFalse);
      expect(scheduler.contains('AndroidScheduleMode.alarmClock'), isFalse);
      expect(
        'AndroidScheduleMode.inexactAllowWhileIdle'.allMatches(scheduler).length,
        2,
        reason: 'both zonedSchedule calls must stay inexact',
      );
    });

    test('declares the receivers scheduled notifications are delivered to', () {
      expect(declaresReceiver('ScheduledNotificationReceiver'), isTrue);
      expect(declaresReceiver('ScheduledNotificationBootReceiver'), isTrue);
      // The boot receiver is inert without it, and pending reminders would be
      // dropped by every restart.
      expect(declaresPermission('RECEIVE_BOOT_COMPLETED'), isTrue);
    });

    test('still asks for the runtime notification grant', () {
      expect(declaresPermission('POST_NOTIFICATIONS'), isTrue);
    });
  });
}
