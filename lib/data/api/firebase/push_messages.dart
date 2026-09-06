import 'package:firebase_messaging/firebase_messaging.dart';

import 'push_service.dart';

/// The three ways a push reaches a running app, behind one seam.
///
/// It exists so the tap path can be TESTED. `_PushSync` used to reach for
/// `PushService`'s static members directly and bail out unless the backend
/// was Firebase — and `fastBackendOverrides()` pins every widget test to the
/// fake backend, so no widget test could reach the push handling at all.
/// Including the cold-start deep link, which is simultaneously the hardest
/// path to check by hand and the one that was broken.
///
/// This is the same arrangement the local-notification half already uses:
/// `ReminderCoordinator` takes a `ReminderSink`, its provider supplies the
/// real one only on Firebase, and `reminder_tap_test.dart` injects a fake to
/// drive taps through the real router.
abstract interface class PushMessages {
  /// Tapped while the app was running in the background.
  Stream<RemoteMessage> get onOpened;

  /// Arrived while the app was open and in front of the user. Android draws
  /// nothing itself in this state.
  Stream<RemoteMessage> get onForeground;

  /// The push that cold-started the app, if any. Consumed once.
  Future<RemoteMessage?> initialMessage();

  /// FCM rotating this device's token, which it does on reinstall and
  /// restore. Without a subscriber, every reinstall silently orphans the
  /// device and the failure is indistinguishable from having nothing to say.
  Stream<String> get onTokenRefresh;

  /// Creates the Android channels a background push lands in.
  ///
  /// On the seam rather than called statically so a test double no-ops:
  /// `FlutterLocalNotificationsPlugin` is not initialised under `flutter
  /// test`, and reaching for it there throws a `LateInitializationError` into
  /// a fire-and-forget future — swallowed, but noisy, and one more thing
  /// between a test and the behaviour it is about.
  Future<void> ensureChannels();
}

/// [PushMessages] over the real FCM plugin.
class FirebasePushMessages implements PushMessages {
  const FirebasePushMessages();

  @override
  Stream<RemoteMessage> get onOpened => PushService.onOpened;

  @override
  Stream<RemoteMessage> get onForeground => PushService.onForeground;

  @override
  Future<RemoteMessage?> initialMessage() => PushService.initialMessage();

  @override
  Stream<String> get onTokenRefresh => PushService.onTokenRefresh;

  @override
  Future<void> ensureChannels() => PushService.ensureAndroidChannels();
}
