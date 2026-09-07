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
  final appDelegate = read('ios/Runner/AppDelegate.swift');
  final store = read('lib/data/stores/journey_store.dart');
  final registrar = read('lib/data/stores/push_token_registrar.dart');

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

    test('is valid XML — no double hyphen inside a comment', () {
      // XML forbids `--` inside a comment, and Xcode reads this file as a
      // plist. One "`--release`" written in the prose therefore makes the
      // WHOLE entitlements file unparseable, and an unparseable entitlements
      // file is not a warning: the app builds carrying none of these keys, so
      // push dies, App Attest dies, and the App Group takes code-signing down
      // with it. It shipped exactly that way and nothing here caught it,
      // because every other assertion in this group runs against `code()`,
      // which strips the comments before looking.
      for (final match in RegExp(r'<!--([\s\S]*?)-->').allMatches(
        entitlements,
      )) {
        final body = match.group(1)!;
        final firstLine = body.trim().split('\n').first;
        expect(
          body.contains('--'),
          isFalse,
          reason:
              'this comment makes Runner.entitlements invalid XML — spell the '
              'flag out instead: $firstLine',
        );
      }
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

  group('AppDelegate', () {
    test('starts the APNs round trip itself', () {
      // The bug this pins: push was completely dead on iOS while Android
      // worked, because NOTHING called `registerForRemoteNotifications`.
      //
      // It looks handled twice over and is not. `Messaging#requestPermission`
      // — the call behind every permission CTA, and the reason iOS Settings
      // says "Allow" — only calls `UNUserNotificationCenter
      // .requestAuthorization`; it never registers for remote notifications.
      // And the plugin's own call sits in
      // `setupNotificationHandlingWithRemoteNotification:`, which runs off
      // `UIApplicationDidFinishLaunchingNotification` or the scene-delegate
      // connection — while this app registers its plugins from
      // `didInitializeImplicitFlutterEngine`, by which time the launch
      // notification has already been posted.
      //
      // Without it: no APNs token, so no FCM token, so no
      // `users/{uid}/devices` row, so every server send finds an empty token
      // list and returns without a log line. Silent at every stage.
      expect(
        code(appDelegate),
        contains('registerForRemoteNotifications()'),
        reason: 'nothing else in the app starts the APNs round trip',
      );
    });

    test('hands the APNs token to FCM itself', () {
      // Registering is only half of it. The plugin's `GULAppDelegateSwizzler`
      // interception is installed by the same setup pass that was never
      // running, so leaving the answer to it would fix the call above and
      // still drop the token on the floor.
      expect(code(appDelegate), contains('Messaging.messaging().apnsToken'));
      expect(
        code(appDelegate),
        contains('didRegisterForRemoteNotificationsWithDeviceToken'),
      );
    });

    test('says so when APNs registration fails', () {
      // The plugin's handler only NSLogs, and downstream the failure is
      // indistinguishable from "the user declined" — `tokenOrNull()` catches
      // the FCM refusal into the same null.
      expect(
        code(appDelegate),
        contains('didFailToRegisterForRemoteNotificationsWithError'),
      );
    });
  });

  group('PushTokenRegistrar', () {
    test('holds a token that arrives before the session does', () {
      // `onTokenRefresh` fires within milliseconds of launch, while
      // `restoreSession()` is still in flight — so `if (state == null)
      // return;` caught the ordinary cold start as well as the signed-out
      // case it was written for. The token it discarded is the one a
      // REINSTALL mints, which is exactly when the server is holding a stale
      // one, so the device went unreachable until something else happened to
      // call `sync()`. Behaviour is proved in
      // `test/data/push_token_registrar_test.dart`; this pins that the store
      // no longer owns it, because a second owner is how it drifts back.
      expect(code(registrar), contains('_pending'));
      expect(
        code(store),
        isNot(contains('userContextRepositoryProvider).sync(fcmToken:')),
        reason: 'the token belongs to the registrar, which retries',
      );
    });

    test('retries rather than giving up', () {
      // The whole point. Seven fire-and-forget call sites each `.ignore()`d
      // their own failure, so a token that could not be read or sent at the
      // instant one of them ran was never sent at all.
      expect(code(registrar), contains('_scheduleRetry()'));
      expect(code(registrar), contains('retryDelays'));
    });

    test('tells a refusal apart from an APNs token that is merely late', () {
      // Retrying a decline is pointless and, on Android, actively harmful.
      // Not retrying a late APNs token is the iOS bug itself.
      expect(code(registrar), contains('PushPermission.granted'));
    });
  });
}
