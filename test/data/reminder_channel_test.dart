import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/api/firebase/reminder_scheduler.dart';
import 'package:last_puff/domain/logic/quit_program.dart';
import 'package:last_puff/domain/logic/reminder_planner.dart';
import 'package:last_puff/domain/logic/reminder_tap.dart';

/// The check-in channel is created explicitly when the scheduler initializes,
/// not left to the notification's own details: the plugin creates a channel
/// from details only when it is missing and never renames one, so an install
/// that carried the old words would keep them. These tests run the real
/// scheduler and the real Android plugin over a recorded method channel; that
/// Android then updates an existing id's name and description is the OS's
/// documented behaviour, and is not something a unit test can show. The device
/// suite `integration_test/t_channel_rename_test.dart` is.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  Object? createFails;

  /// How many `initialize` calls fail before one succeeds.
  var initializeFails = 0;

  /// What the OS says about the tap that launched the app, or null for a
  /// launch that was not a tap.
  Map<String, Object?>? launchedBy;

  setUp(() {
    calls.clear();
    createFails = null;
    initializeFails = 0;
    launchedBy = null;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'createNotificationChannel' &&
              createFails != null) {
            throw PlatformException(code: 'denied', message: '$createFails');
          }
          if (call.method == 'initialize' && initializeFails > 0) {
            initializeFails--;
            throw PlatformException(code: 'init', message: 'not yet');
          }
          if (call.method == 'getNotificationAppLaunchDetails') {
            return launchedBy;
          }
          return call.method == 'initialize' ? true : null;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  List<String> methods() => [for (final c in calls) c.method];

  Future<bool> arm(ReminderScheduler scheduler) => scheduler.scheduleOnce(
    OneShotReminder(id: 5102, at: DateTime.now().add(const Duration(hours: 1))),
    tap: const ReminderTap(ReminderKind.checkin),
    title: 'Day 2',
    body: 'Today\'s line is 12 puffs.',
  );

  test('on Android the check-in channel is created, once, before anything is '
      'scheduled on it', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final scheduler = ReminderScheduler();

    expect(await arm(scheduler), isTrue);
    await arm(scheduler);

    expect(
      methods().where((m) => m == 'createNotificationChannel'),
      hasLength(1),
      reason: 'created again on every schedule: ${methods()}',
    );
    expect(
      methods().indexOf('createNotificationChannel'),
      lessThan(methods().indexOf('zonedSchedule')),
      reason: '${methods()}',
    );
    final sent = calls.singleWhere(
      (c) => c.method == 'createNotificationChannel',
    );
    final args = Map<String, Object?>.from(sent.arguments as Map);
    final shared = ReminderScheduler.checkinChannel;
    expect(args['id'], 'evening_checkins');
    expect(args['name'], shared.name);
    expect(args['description'], shared.description);
    // Immutable once the OS has it, so it must be what the channel was
    // created with: raising it here would be ignored on an upgrade.
    expect(args['importance'], Importance.defaultImportance.value);
  });

  test('a channel the OS refuses does not stop the notification being '
      'scheduled', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    createFails = 'no';

    expect(await arm(ReminderScheduler()), isTrue);
    expect(methods(), contains('zonedSchedule'));
  });

  // The app starts the scheduler from `ReminderCoordinator.sync`, which the
  // app fires on every journey, settings and entitlement change and does not
  // await or serialize: at a cold start two of them can be inside the first
  // `_ensureReady` at once. Each used to initialize the plugin and read the
  // tap that launched the app, so one tap became two `reminder_opened`.
  const launchTap = ReminderTap(
    ReminderKind.checkin,
    slot: ProgramSlot.morning,
    planDay: 2,
  );

  test('two calls racing to start the scheduler initialize it once, and a '
      'tap that launched the app is reported once', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    launchedBy = {
      'notificationLaunchedApp': true,
      'notificationResponse': {
        'notificationId': 5102,
        'actionId': null,
        'input': null,
        'notificationResponseType': 0,
        'payload': launchTap.encode(),
        'data': <String, Object?>{},
      },
    };
    final scheduler = ReminderScheduler();
    final taps = <ReminderTap>[];
    final sub = scheduler.opened.listen(taps.add);
    addTearDown(sub.cancel);

    await Future.wait([scheduler.cancel(1), scheduler.cancel(2)]);
    // A call after it has started must not read the launch again either.
    await scheduler.cancel(3);
    await Future<void>.delayed(Duration.zero);

    expect(
      methods().where((m) => m == 'initialize'),
      hasLength(1),
      reason: '${methods()}',
    );
    expect(
      methods().where((m) => m == 'createNotificationChannel'),
      hasLength(1),
      reason: '${methods()}',
    );
    expect(taps, [launchTap], reason: 'the launch tap was reported twice');
  });

  test('a start that fails is tried again by the next call, not remembered as '
      'a failure', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    initializeFails = 1;
    final scheduler = ReminderScheduler();

    await scheduler.cancel(1);
    expect(
      methods().where((m) => m == 'cancel'),
      isEmpty,
      reason: 'it cancelled on a plugin that never initialized',
    );
    await scheduler.cancel(2);

    expect(methods().where((m) => m == 'initialize'), hasLength(2));
    expect(methods().where((m) => m == 'cancel'), hasLength(1));
  });

  test('off Android no channel is created', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await ReminderScheduler().cancel(5102);

    expect(methods(), isNot(contains('createNotificationChannel')));
  });
}
