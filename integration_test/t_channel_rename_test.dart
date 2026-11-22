import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/data/api/firebase/reminder_scheduler.dart';

/// The check-in channel's words reach a phone that already holds the old ones
/// (docs/10 §59.7).
///
/// Release 1.0.36 created `evening_checkins` as "Evening check-ins" on every
/// phone it reached. The morning widened the words to "Check-ins", and naming
/// a channel only in a notification's details cannot rename one that exists:
/// the plugin creates a channel from details when the id is missing and never
/// updates it. So `ReminderScheduler._ensureReady` creates the channel
/// explicitly, and Android then updates only the name and description of an
/// existing id. `test/data/reminder_channel_test.dart` proves the call is
/// made; this is the only place that shows what the OS does with it, and the
/// only way to see an UPGRADED install on a device that was never upgraded:
/// the test plays 1.0.36 itself.
///
/// Needs nothing of the app and nothing from a person: no sign-in, no backend,
/// no notification permission (creating a channel does not need
/// `POST_NOTIFICATIONS`), no hand on the shade. Android only: notification
/// channels do not exist on iOS.
///
/// ```
/// flutter test integration_test/t_channel_rename_test.dart -d <pixel> \
///   --dart-define=LP_BACKEND=fake
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Notification channels are an Android 8+ surface; there is nothing to
  // rename on an iPhone, so the case is skipped there rather than passing
  // vacuously.
  final onAndroid = defaultTargetPlatform == TargetPlatform.android;

  testWidgets(
    'an existing "Evening check-ins" channel is renamed in place when the '
    'scheduler starts',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text('channel rename probe'))),
        ),
      );

      final android = FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      expect(android, isNotNull, reason: 'no Android notifications plugin');

      Future<AndroidNotificationChannel> held() async {
        final channels = await android!.getNotificationChannels();
        expect(channels, isNotNull);
        return channels!.singleWhere(
          (c) => c.id == ReminderScheduler.checkinChannel.id,
          orElse: () => fail(
            'the device holds no ${ReminderScheduler.checkinChannel.id} '
            'channel: ${[for (final c in channels) c.id]}',
          ),
        );
      }

      // 1.0.36's channel, exactly as it left one on a phone. The plugin is
      // initialized the way the scheduler does it, before anything touches the
      // scheduler. Creating a channel that already exists updates only its
      // name and description, so this holds on a phone that has run any
      // earlier build of this suite too.
      await android!.initialize(
        settings: const AndroidInitializationSettings(
          '@drawable/ic_stat_cirrus',
        ),
      );
      const old = AndroidNotificationChannel(
        'evening_checkins',
        'Evening check-ins',
        description: 'One nudge an evening to log how the day went.',
        importance: Importance.defaultImportance,
      );
      await android.createNotificationChannel(old);

      // The precondition, so a pass is a rename and not a channel that was
      // already right.
      final before = await held();
      expect(before.name, old.name, reason: 'the old channel never landed');
      expect(before.description, old.description);
      expect(
        ReminderScheduler.checkinChannel.name,
        isNot(old.name),
        reason: 'the shared channel still carries the old words, so this '
            'case proves nothing',
      );

      // A fresh scheduler runs `_ensureReady` on its first public call, and
      // `cancel` is the lightest one that does: it schedules nothing, so no
      // notification is armed and nothing needs the OS permission. The id is
      // one nothing arms (the planner's ids are 1000-1023, 2000, 3000+,
      // 4000-4006, 5000-5002 and 5102-5103), and cancelling an id that was
      // never scheduled is a no-op.
      await ReminderScheduler().cancel(5198);

      final after = await held();
      final shared = ReminderScheduler.checkinChannel;
      expect(
        after.name,
        shared.name,
        reason: 'the scheduler started and the channel kept the old name',
      );
      expect(after.description, shared.description);
      // Immutable once the OS has it: the rename must not have moved it.
      expect(after.importance, before.importance);
      debugPrint('E2E-MARKER: channel-renamed name=${after.name}');
    },
    skip: !onAndroid,
  );
}
