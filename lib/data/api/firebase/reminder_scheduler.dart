import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../domain/logic/reminder_planner.dart';
import '../../../domain/logic/reminder_tap.dart';

/// What the coordinator needs from a scheduler. Exists so the scheduling
/// DECISIONS can be tested without a platform channel — the decisions are the
/// part that can be wrong in a way a user notices.
abstract interface class ReminderSink {
  /// Replaces the repeating danger-hour schedule (ids 1000–1023) with [slots].
  Future<void> apply(
    List<ReminderSlot> slots, {
    required String title,
    required String body,
  });

  /// One notification at one instant — the trial-ending reminder and the
  /// milestone celebration. Replaces any earlier one with the same id.
  ///
  /// [tap] becomes the payload, which is the only thing that tells a tap
  /// where to land. It was hardcoded to `trial` while that was the only
  /// one-shot; a second kind through the same door had to make it a parameter
  /// or every milestone tap would have opened the trial-ending screen. It is a
  /// [ReminderTap] rather than a bare kind since the daily program's mornings:
  /// the slot, the plan day and the message ride in the payload too, so the
  /// tap can say which of them brought somebody back.
  ///
  /// Answers whether the notification is now on the device clock. A refusal
  /// (plugin not initialised, the platform rejecting the instant) is swallowed
  /// rather than thrown — reminders are never worth a crash — but the caller
  /// has to know: a milestone marked "celebrated" on the strength of a
  /// schedule that never armed is silenced for ever. A `true` is NOT an answer
  /// about the OS notification permission: Android arms the alarm without
  /// asking for it and iOS's plugin swallows the unauthorized add, so a phone
  /// that refused notifications still answers true.
  Future<bool> scheduleOnce(
    OneShotReminder reminder, {
    required ReminderTap tap,
    required String title,
    required String body,
  });

  Future<void> cancel(int id);

  /// Everything, both schedules: sign-out and notifications-off.
  Future<void> cancelAll();

  /// Taps on this app's reminders — while it runs, when it is resumed, and
  /// the tap that cold-started it (reported once the scheduler initialises).
  /// The sink only reports; routing is the app's decision.
  Stream<ReminderTap> get opened;
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
  final _opened = StreamController<ReminderTap>.broadcast();

  @override
  Stream<ReminderTap> get opened => _opened.stream;

  /// A payload is text the OS hands back; anything not a known kind (an old
  /// build's notification, a foreign one) is dropped rather than routed. A bare
  /// kind name — every payload an older build armed — still decodes.
  void _report(String? payload) {
    final tap = ReminderTap.decode(payload);
    if (tap != null) _opened.add(tap);
  }

  static const _channelId = 'danger_hours';
  static const _trialChannelId = 'trial_reminders';
  static const _milestoneChannelId = 'milestone_celebrations';

  /// The check-in channel, defined ONCE: [_ensureAndroidChannels] creates it
  /// and [oneShotDetails] names it from the same fields, so what Android holds
  /// and what a notification claims cannot drift. The id is permanent and its
  /// importance is immutable once the OS has it; see [oneShotDetails].
  @visibleForTesting
  static const checkinChannel = AndroidNotificationChannel(
    'evening_checkins',
    'Check-ins',
    description: 'A morning or evening note about your plan.',
    importance: Importance.defaultImportance,
  );

  /// The start in flight, so callers that arrive while it runs wait for it
  /// instead of starting their own. The app fires `ReminderCoordinator.sync` on
  /// every journey, settings and entitlement change without awaiting or
  /// serializing it, so at a cold start two of them can be inside their first
  /// call at once. Each used to initialize the plugin and read the tap that
  /// launched the app, so a cold-start tap was reported twice as
  /// `reminder_opened`.
  Future<void>? _starting;

  /// Starts the scheduler once; later and concurrent callers share that start.
  /// A start that fails is forgotten, so the next call tries again, as it did
  /// when the guard was only a flag set after the awaits.
  Future<void> _ensureReady() async {
    if (_ready) return;
    final start = _starting ??= _start();
    try {
      await start;
    } on Object {
      if (identical(_starting, start)) _starting = null;
      rethrow;
    }
  }

  Future<void> _start() async {
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
        // The brand ring as a white-on-transparent silhouette, NOT the
        // launcher icon. Android builds a notification icon from the ALPHA
        // CHANNEL alone, so a full-colour, fully-opaque launcher icon renders
        // as a solid white square in the status bar — which is what every
        // scheduled reminder looked like. Same asset the manifest names for
        // server pushes, so both halves match.
        android: AndroidInitializationSettings('@drawable/ic_stat_cirrus'),
        iOS: DarwinInitializationSettings(
          // The OS prompt belongs to the D4 screen, not to plugin init.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => _report(response.payload),
    );
    await _ensureAndroidChannels();
    _ready = true;
    // The tap that launched the app arrives here, not through the callback:
    // the process did not exist when it happened.
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch != null && launch.didNotificationLaunchApp) {
        _report(launch.notificationResponse?.payload);
      }
    } on Object catch (error) {
      debugPrint('reminders: launch details failed — $error');
    }
  }

  /// Creates [checkinChannel] explicitly, on Android only.
  ///
  /// Naming a channel in a notification's details does not do this job: the
  /// plugin creates a channel from details only when the id is missing, and its
  /// default `channelAction` never updates one (flutter_local_notifications
  /// 23.0.2, `FlutterLocalNotificationsPlugin.java`,
  /// `canCreateNotificationChannel`). An install that already holds the old
  /// words would keep them for ever. `channelAction: update` is no answer
  /// either: it skips a channel that does not exist, so a fresh install would
  /// lose the notification. `createNotificationChannel` through the Android
  /// plugin always runs, whatever the channel's state, and Android then
  /// updates only the name and description of an existing id. Same call
  /// `PushService.ensureAndroidChannels` makes for the push channels.
  ///
  /// A failure is logged and swallowed, like every other reminder step: the
  /// notification still posts, and the channel is created from its details if
  /// this did not.
  Future<void> _ensureAndroidChannels() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(checkinChannel);
    } on Object catch (error) {
      debugPrint('reminders: channel create failed — $error');
    }
  }

  @override
  /// Replaces the whole danger-hour schedule with [slots].
  ///
  /// Cancel-then-schedule rather than a diff: the plan is at most three
  /// entries, and a diff that goes wrong leaves a user with a notification
  /// they cannot explain and we cannot find. Only this schedule's own ids,
  /// though: a `cancelAll()` here used to take the trial-ending reminder down
  /// with it on every puff-tap resync.
  Future<void> apply(
    List<ReminderSlot> slots, {
    required String title,
    required String body,
  }) async {
    try {
      await _ensureReady();
      for (var hour = 0; hour < 24; hour++) {
        await _plugin.cancel(id: 1000 + hour);
      }
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
          payload: const ReminderTap(ReminderKind.danger).encode(),
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
  Future<bool> scheduleOnce(
    OneShotReminder reminder, {
    required ReminderTap tap,
    required String title,
    required String body,
  }) async {
    try {
      await _ensureReady();
      await _plugin.cancel(id: reminder.id);
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: title,
        body: body,
        // An absolute instant in the device's zone; the planner guarantees it
        // is in the future, which `zonedSchedule` insists on.
        scheduledDate: tz.TZDateTime.from(reminder.at, tz.local),
        notificationDetails: oneShotDetails(tap.kind, body),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: tap.encode(),
      );
      return true;
    } on Object catch (error) {
      debugPrint('reminders: one-shot schedule failed — $error');
      return false;
    }
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await _ensureReady();
      await _plugin.cancel(id: id);
    } on Object catch (error) {
      debugPrint('reminders: cancel failed — $error');
    }
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

  /// Channels are OS surface, not app copy, so these stay English like the
  /// two above them. A celebration gets its own channel so someone who wants
  /// the danger-hour nudge but not the confetti can say so in system settings.
  ///
  /// **Every kind is named.** This used to end in `_ =>` for the trial reminder,
  /// which would have filed any new kind under "Trial reminders" — and a channel
  /// is the user's own switch, so a message under the wrong one can only be
  /// silenced by silencing something else.
  ///
  /// A program message (docs/15 stage B) takes over the evening check-in's slot,
  /// and the plain morning on plan days 2 and 3 rides the check-in kind, so all
  /// three share one channel ([checkinChannel], id `evening_checkins`). **The
  /// id is permanent** (it is the user's own switch in system settings, and
  /// importance is immutable once created), but its words are not: they were
  /// widened from "Evening check-ins" to "Check-ins" when the mornings arrived,
  /// since the id says evening and the words do not.
  ///
  /// **The words reach an existing install through [_ensureAndroidChannels],
  /// not through these details.** A channel named only here is created if it is
  /// missing and never updated, so an upgraded install would keep the old name;
  /// the scheduler therefore creates [checkinChannel] explicitly when it
  /// initializes, and these details read the same constant so the two cannot
  /// drift. That the upgraded install ends up with the new words rests on
  /// Android's documented `createNotificationChannel` behaviour (an existing
  /// id has only its name and description updated). A unit test
  /// (`reminder_channel_test.dart`) proves the call is made, and the device
  /// suite `integration_test/t_channel_rename_test.dart` is what shows the OS
  /// honouring it, on a phone made to hold the old name first. Whether that
  /// suite has run, and what it showed, is recorded in docs/10 §59.7.
  ///
  /// [body] goes into a `BigTextStyleInformation` for both: Android collapses a
  /// plain body to one line, and a message, or the morning's "line is N puffs,
  /// log each one" sentence, is longer.
  @visibleForTesting
  static NotificationDetails oneShotDetails(ReminderKind kind, String body) =>
      switch (kind) {
        ReminderKind.checkin || ReminderKind.program => NotificationDetails(
          android: AndroidNotificationDetails(
            checkinChannel.id,
            checkinChannel.name,
            channelDescription: checkinChannel.description,
            importance: checkinChannel.importance,
            priority: Priority.defaultPriority,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        ReminderKind.milestone => const NotificationDetails(
          android: AndroidNotificationDetails(
            _milestoneChannelId,
            'Milestone celebrations',
            channelDescription: 'The morning after you hit a streak milestone.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // `danger` is scheduled through `apply`, not here; it is listed so the
        // switch stays exhaustive and a new kind cannot fall through to it.
        ReminderKind.danger || ReminderKind.trial => const NotificationDetails(
          android: AndroidNotificationDetails(
            _trialChannelId,
            'Trial reminders',
            channelDescription: 'The heads-up before a free trial ends.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      };
}
