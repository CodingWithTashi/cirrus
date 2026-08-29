import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

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

  /// Fires when FCM rotates the token, which it does on reinstall, restore,
  /// and occasionally on its own. Without this the server would keep pushing
  /// to a dead token and the user would silently stop hearing from us.
  static Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  static bool _granted(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;
}
