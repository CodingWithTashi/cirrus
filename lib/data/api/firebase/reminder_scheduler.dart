import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../domain/logic/reminder_planner.dart';

/// What the coordinator needs from a scheduler. Exists so the scheduling
/// DECISIONS can be tested without a platform channel — the decisions are the
/// part that can be wrong in a way a user notices.
abstract interface class ReminderSink {
  Future<void> apply(
    List<ReminderSlot> slots, {
    required String title,
    required String body,
  });

  Future<void> cancelAll();
}

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
///
/// **It used to translate it wrong, and silently.** `periodicallyShow` repeats
/// every 24h *from the moment it is called*, so `slot.hour` and `slot.minute`
/// — the entire output of the planner — were computed, fingerprinted, tested,
/// and then dropped on the floor. Whatever moment the app last happened to
/// sync became the daily notification time, forever. A user who opened the app
/// at 07:14 got their "danger hour" nudge at 07:14. The feature looked built
/// from every angle except the one that mattered.
class ReminderScheduler implements ReminderSink {
  ReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const _channelId = 'danger_hours';

  Future<void> _ensureReady() async {
    if (_ready) return;
    // A repeating daily alarm must be anchored in a real zone, not in UTC and
    // not in a fixed offset: without the database, a user who crosses DST gets
    // their 9pm nudge at 8pm for half the year.
    tzdata.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } on Object catch (error) {
      // Keep whatever `timezone` defaulted to rather than failing to schedule.
      debugPrint('reminders: timezone lookup failed — $error');
    }
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

  @override
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
        await _plugin.zonedSchedule(
          id: slot.id,
          title: title,
          body: body,
          scheduledDate: nextOccurrence(slot, tz.TZDateTime.now(tz.local)),
          // The whole point: repeat at this WALL-CLOCK time every day, rather
          // than every 24 hours from now.
          matchDateTimeComponents: DateTimeComponents.time,
          notificationDetails: _details(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } on Object catch (error) {
      // A device that refuses to schedule is a quieter app, not a broken one.
      debugPrint('reminders: schedule failed — $error');
    }
  }

  /// The next time at or after [now] that reads [slot]'s hour and minute.
  ///
  /// `zonedSchedule` rejects a date in the past, so a slot whose time has
  /// already passed today has to start tomorrow. Takes [now] rather than
  /// reading the clock so the thing that was silently wrong for the whole life
  /// of this feature — which wall-clock time a reminder lands on — is directly
  /// assertable.
  @visibleForTesting
  static tz.TZDateTime nextOccurrence(ReminderSlot slot, tz.TZDateTime now) {
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      slot.hour,
      slot.minute,
    );
    if (!next.isAfter(now)) {
      // The NEXT CALENDAR DAY at the same wall-clock time, not 24 hours later.
      // `add(Duration(days: 1))` adds 24 absolute hours, so across a DST
      // fall-back a 20:50 reminder lands at 19:50 and stays an hour early for
      // the rest of the winter. TZDateTime normalizes the day overflow.
      next = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        slot.hour,
        slot.minute,
      );
    }
    return next;
  }

  @override
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
