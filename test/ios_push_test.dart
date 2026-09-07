import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The iOS half of push, pinned the way `android_manifest_test.dart` pins the
/// Android half: as string tests over the native files, because `flutter test`
/// never opens the Xcode project and CI never signs a build.
///
/// Push on iOS is the most silent feature in the app. Every failure below
/// leaves an app that installs, launches, shows the permission sheet, reports
/// `granted`, and never receives anything — while the identical server send
/// arrives on Android. There is no error anywhere in the chain: the plugin's
/// `didFailToRegisterForRemoteNotificationsWithError` only NSLogs, and
/// `PushService.tokenOrNull()` turns the FCM refusal that follows into the
/// same `null` it uses for "the user declined".
void main() {
  String read(String path) => File(path).readAsStringSync();

  /// Comments stripped, so prose that names the thing an assertion forbids
  /// does not fail it. Same helper, same reason, as `ios_widget_test.dart`.
  String code(String source) => source
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//.*'), '');

  final entitlements = read('ios/Runner/Runner.entitlements');
  final infoPlist = read('ios/Runner/Info.plist');
  final pbxproj = read('ios/Runner.xcodeproj/project.pbxproj');
  final service = read('lib/data/api/firebase/push_service.dart');

  /// The `<string>` immediately following [key] in a plist.
  String? valueOf(String plist, String key) => RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<string>([^<]*)</string>',
  ).firstMatch(plist)?.group(1);

  group('Runner.entitlements', () {
    test('declares aps-environment, without which push cannot exist', () {
      // No entitlement means `registerForRemoteNotifications` fails, so APNs
      // hands back no device token, so `FIRMessagingTokenManager` refuses to
      // mint an FCM token at all, so no device row is ever written and every
      // server push goes nowhere. It was absent until Sep 6 2026 while the
      // whole Dart and server side was complete and correct.
      expect(
        code(entitlements),
        contains('<key>aps-environment</key>'),
        reason: 'iOS push is dead without it, silently and at every stage',
      );
    });

    test('names the development environment, which is what ships', () {
      // Xcode rewrites this to `production` when it exports an archive — the
      // step `flutter build ipa` drives — and the plugin picks the APNs
      // environment from the DEBUG macro on the same seam. Hardcoding
      // `production` here would break push on every debug build on the desk
      // while looking more correct than the value that works.
      expect(valueOf(code(entitlements), 'aps-environment'), 'development');
    });

    test('keeps the app group and Apple sign-in it already had', () {
      // A hand-edited entitlements file is one bad merge from dropping a key
      // that fails at code-sign time (the group) or at first callable (App
      // Attest) rather than here.
      expect(code(entitlements), contains('group.com.quitvape.lastPuff'));
      expect(
        code(entitlements),
        contains('com.apple.developer.applesignin'),
      );
      expect(
        code(entitlements),
        contains('com.apple.developer.devicecheck.appattest-environment'),
      );
    });

    test('is signed into all three Runner configurations', () {
      // Debug, Profile and Release. Dropped from one of them, push (and the
      // app group, and Sign in with Apple) breaks in that configuration only
      // — which is the hardest shape of this bug to see, because the build
      // you happen to be running still works.
      final refs = RegExp(
        r'CODE_SIGN_ENTITLEMENTS = Runner/Runner\.entitlements;',
      ).allMatches(pbxproj);
      expect(refs.length, 3);
    });
  });

  group('Info.plist', () {
    test('declares no remote-notification background mode', () {
      // Nothing needs it: every push carries a `notification` block and the
      // app registers no `onBackgroundMessage` handler, so iOS draws the
      // alert itself and no isolate has to wake. It is here as a pin in the
      // other direction — the day somebody sends a `content-available` data
      // push, this test is what tells them the mode and the handler are both
      // missing, instead of the push silently doing nothing.
      expect(code(infoPlist).contains('remote-notification'), isFalse);
      expect(code(infoPlist).contains('UIBackgroundModes'), isFalse);
    });

    test('leaves the Firebase app delegate proxy enabled', () {
      // Disabling the proxy hands us `didRegisterForRemoteNotifications-
      // WithDeviceToken` and `setAPNSToken` to wire by hand, and the app
      // delegate does neither. An absent key means enabled.
      expect(
        code(infoPlist).contains('FirebaseAppDelegateProxyEnabled'),
        isFalse,
      );
    });
  });

  group('PushService', () {
    test('waits for the APNs token before asking FCM for one', () {
      // iOS cannot mint an FCM token until APNs has answered, and says so by
      // throwing — which `tokenOrNull` catches into the null it uses for "not
      // granted". Both permission CTAs call `sync()` the instant the OS sheet
      // returns, which is exactly when the round-trip is still in flight, so
      // without this guard a grant registered nothing and the device stayed
      // unreachable until the next resume.
      final body = code(service);
      expect(body, contains('_apnsReady'));
      expect(
        body.indexOf('_apnsReady'),
        lessThan(body.indexOf('messaging.getToken()')),
        reason: 'the guard has to run before the call it protects',
      );
    });

    test('does not hand foreground presentation back to iOS', () {
      // `_PushSync` draws its own snack for a foreground message, on both
      // platforms, because neither OS draws one by default. Calling
      // `setForegroundNotificationPresentationOptions` would make iOS draw a
      // system banner too, and the user would get the same message twice.
      expect(
        code(service).contains('setForegroundNotificationPresentationOptions'),
        isFalse,
      );
    });

    test('creates Android channels on Android only', () {
      // The channel list is Android's whole quiet-hours mechanism and is
      // meaningless on iOS, which does it per message with
      // `interruption-level`. Reaching for the plugin off-platform is a
      // channel call into something that is not there.
      expect(
        code(service),
        contains('if (defaultTargetPlatform != TargetPlatform.android) return;'),
      );
    });
  });
}
