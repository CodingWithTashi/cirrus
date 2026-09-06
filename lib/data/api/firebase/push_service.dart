import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Where the OS stands on notifications for this app.
enum PushPermission {
  /// Never asked, so the system sheet will actually appear.
  notAsked,

  /// Refused. Asking again does nothing on Android — it is a system-settings
  /// trip from here, which is a lot to ask for a nudge, so we do not.
  denied,

  granted,
}

/// FCM registration.
///
/// `firebase_messaging` has been a declared dependency that no Dart file ever
/// imported, so no token was ever registered and no push could ever arrive.
///
/// Two rules shape this class:
///
/// * **Asking is the view's job, reading is this class's.** [requestPermission]
///   is called from the onboarding notifications step, right after the
///   pre-permission screen has explained the value (docs/02 D4). Nothing else
///   triggers the OS prompt — a permission dialog with no context is how apps
///   get denied permanently.
/// * **A token is only fetched when permission already exists.** Calling
///   `getToken()` before that would prompt implicitly on iOS, which would
///   bypass the pre-permission screen entirely.
abstract final class PushService {
  /// Triggers the OS prompt. Returns whether we ended up authorized —
  /// including the provisional grant iOS may give without a dialog.
  static Future<bool> requestPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      return _granted(settings.authorizationStatus);
    } on Object catch (error) {
      debugPrint('push: permission request failed — $error');
      return false;
    }
  }

  /// The device token, or null when permission is absent or FCM is unhappy.
  ///
  /// Null is an ordinary outcome, not an error: a user who declined
  /// notifications still gets a fully working app, just without the
  /// danger-hour nudge.
  static Future<String?> tokenOrNull() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();
      if (!_granted(settings.authorizationStatus)) return null;
      return await messaging.getToken();
    } on Object catch (error) {
      debugPrint('push: token lookup failed — $error');
      return null;
    }
  }

  /// Forgets this device's token, so FCM stops delivering to it.
  ///
  /// The load-bearing half of sign-out. Releasing the server-side row needs a
  /// network round trip and a live session and can fail for either reason;
  /// this cannot fail for either, and on its own it is what guarantees the
  /// next person on a shared phone hears nothing meant for the last one.
  ///
  /// A new token is minted on the next `getToken()`, so a sign-in afterwards
  /// registers cleanly.
  static Future<void> deleteToken() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
    } on Object catch (error) {
      // Nothing to do about it, and nothing worth showing: the account is
      // being signed out either way.
      debugPrint('push: token delete failed — $error');
    }
  }

  /// The channels a background push can land in on Android.
  ///
  /// `messages` is named in the manifest
  /// (`com.google.firebase.messaging.default_notification_channel_id`), and a
  /// manifest can only NAME a channel — something still has to create it, or
  /// Android quietly files every server push under the plugin's
  /// "Miscellaneous" fallback, where the user cannot find the toggle for it.
  ///
  /// The rest are per-category, so somebody can mute replies in system
  /// settings without losing their weekly report. Each has a QUIET TWIN,
  /// because from Android 8 the channel decides sound, vibration and
  /// heads-up: the per-message priority FCM will happily accept is ignored,
  /// so delivering something silently during quiet hours is a channel swap
  /// and cannot be anything else.
  ///
  /// **These ids are permanent.** A channel's importance is fixed when it is
  /// created — `createNotificationChannel` on an existing id updates only its
  /// name and description, because the user owns that setting once they have
  /// seen it. So none of these can be made quieter later, none can be reused
  /// for different behaviour, and `messages` can never be deleted without
  /// discarding whatever its users configured. Mirrors
  /// `functions/src/lib/pushKinds.ts`.
  ///
  /// English on purpose, like the danger-hours channel: channel names render
  /// in SYSTEM settings, and this runs at app init where there is no
  /// localization context yet.
  static Future<void> ensureAndroidChannels() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final android = FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return;
      for (final channel in _channels) {
        await android.createNotificationChannel(channel);
      }
    } on Object catch (error) {
      debugPrint('push: channel create failed — $error');
    }
  }

  static const _channels = <AndroidNotificationChannel>[
    AndroidNotificationChannel(
      'messages',
      'Messages',
      description: 'Anything that does not fit the categories below.',
      importance: Importance.defaultImportance,
    ),
    AndroidNotificationChannel(
      'community_replies',
      'Replies and mentions',
      description: 'When someone answers your post or tags you.',
      importance: Importance.defaultImportance,
    ),
    AndroidNotificationChannel(
      'community_replies_quiet',
      'Replies during quiet hours',
      description: 'The same, delivered without a sound overnight.',
      importance: Importance.low,
    ),
    AndroidNotificationChannel(
      'insights',
      'Weekly report',
      description: 'When your week is ready to read back.',
      importance: Importance.defaultImportance,
    ),
    AndroidNotificationChannel(
      'insights_quiet',
      'Weekly report during quiet hours',
      description: 'The same, delivered without a sound overnight.',
      importance: Importance.low,
    ),
  ];

  /// Whether we have been granted permission, refused it, or never asked.
  ///
  /// Reads without ever prompting, which is what a second, contextual ask
  /// depends on: Android auto-denies `requestPermission()` after two
  /// dismissals without showing anything, so re-asking a refused user is a
  /// no-op that looks like a broken button.
  static Future<PushPermission> permissionStatus() async {
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => PushPermission.granted,
        AuthorizationStatus.denied => PushPermission.denied,
        _ => PushPermission.notAsked,
      };
    } on Object catch (error) {
      debugPrint('push: permission read failed — $error');
      return PushPermission.notAsked;
    }
  }

  /// What the server records alongside the token, for debugging a delivery
  /// problem that only affects one platform. Anything unrecognised becomes
  /// 'other' server-side, so this never has to be exhaustive.
  static String get platformName => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => 'other',
  };

  /// Fires when FCM rotates the token, which it does on reinstall, restore,
  /// and occasionally on its own. Without this the server would keep pushing
  /// to a dead token and the user would silently stop hearing from us.
  ///
  /// This getter existed with **zero subscribers**, so that is exactly what
  /// happened: every reinstall orphaned the device and nobody found out,
  /// because the failure of a push is silence and silence looks like nothing.
  static Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  /// A push arriving while the app is open and in front of the user.
  ///
  /// Android does not draw a system notification in this state, so without
  /// handling it the message simply never appears.
  static Stream<RemoteMessage> get onForeground =>
      FirebaseMessaging.onMessage;

  /// The user tapped a push and the app was already running in the background.
  static Stream<RemoteMessage> get onOpened =>
      FirebaseMessaging.onMessageOpenedApp;

  /// The push that cold-started the app, if any. Consumed once — asking twice
  /// returns it again, which would re-navigate on every restart.
  static Future<RemoteMessage?> initialMessage() async {
    try {
      return await FirebaseMessaging.instance.getInitialMessage();
    } on Object catch (error) {
      debugPrint('push: initial message lookup failed — $error');
      return null;
    }
  }

  /// The in-app destination a push asks for, or null when it names none or
  /// names one we do not recognise.
  ///
  /// Allow-listed rather than passed through: a route is an instruction, and
  /// an instruction taken from a payload should only ever be one we chose to
  /// accept. Today the sender is ours, which is the best possible time to
  /// decide it does not get to say anything it likes.
  static String? routeFor(RemoteMessage message, Set<String> allowed) {
    final route = message.data['route'];
    if (route is! String || route.isEmpty) return null;
    final path = Uri.tryParse(route)?.path;
    if (path == null) return null;
    return allowed.any((a) => path == a || path.startsWith('$a/'))
        ? route
        : null;
  }

  static bool _granted(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;
}
