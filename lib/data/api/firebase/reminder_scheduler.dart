import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../domain/logic/reminder_planner.dart';

/// Puts [ReminderSlot]s on the device clock.
///
/// Danger-hour reminders are scheduled ON-DEVICE rather than pushed from a
/// cron (see the note at the top of `functions/src/index.ts`): the times are
/// deterministic once computed, so a local alarm is free, works offline, and
/// spares us an hourly fan-out across the whole userbase.
///
/// Everything policy-shaped — which hours, how early, quiet hours, the daily
/// cap — lives in [ReminderPlanner] and is unit-tested. This class only
/// translates a plan into plugin calls.
class ReminderScheduler {
  ReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const _channelId = 'danger_hours';

  Future<void> _ensureReady() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // The OS prompt belongs to the D4 screen, not to plugin init.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Replaces the whole schedule with [slots].
  ///
  /// Cancel-then-schedule rather than a diff: the plan is at most three
  /// entries, and a diff that goes wrong leaves a user with a notification
  /// they cannot explain and we cannot find.
  Future<void> apply(
    List<ReminderSlot> slots, {
    required String title,
    required String body,
  }) async {
    try {
      await _ensureReady();
      await _plugin.cancelAll();
      for (final slot in slots) {
        await _plugin.periodicallyShowWithDuration(
          id: slot.id,
          title: title,
          body: body,
          repeatDurationInterval: const Duration(days: 1),
          notificationDetails: _details(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } on Object catch (error) {
      // A device that refuses to schedule is a quieter app, not a broken one.
      debugPrint('reminders: schedule failed — $error');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _ensureReady();
      await _plugin.cancelAll();
    } on Object catch (error) {
      debugPrint('reminders: cancel failed — $error');
    }
  }

  NotificationDetails _details() => const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Danger-hour reminders',
      channelDescription:
          'A heads-up just before the hours you usually reach for it.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );
}
