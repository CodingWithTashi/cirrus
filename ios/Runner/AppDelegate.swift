import FirebaseMessaging
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Before super, and before anything Flutter: iOS launches the app in the
    // background to deliver a watch tap, and a WCSession with no delegate hears
    // none of them. Costs nothing on a phone with no watch paired.
    CirrusWatchLink.shared.start()
    let started = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // **The APNs round trip has to be started by somebody, and nothing was
    // starting it.** This is the fix for push being completely dead on iOS
    // while Android worked: no APNs token means `FIRMessagingTokenManager`
    // refuses to mint an FCM token at all, so `PushService.tokenOrNull()`
    // returned null, `syncUserContext` sent no `fcmToken`, no
    // `users/{uid}/devices` row was ever written, and every server send found
    // an empty token list and returned without so much as a log line
    // (`functions/src/lib/push.ts`, the one silent exit in `sendToUser`).
    //
    // The trap is that it looks like it is already handled, twice over:
    //
    // * `Messaging#requestPermission` — the call behind every permission CTA,
    //   and the reason iOS Settings says "Allow" — only calls
    //   `UNUserNotificationCenter.requestAuthorization`. It does NOT register
    //   for remote notifications. So "the user granted notifications" and
    //   "this device has an APNs token" are independent facts, and the app
    //   was in the state where the first was true and the second was not.
    // * The messaging plugin does call it, from exactly one reachable place:
    //   `setupNotificationHandlingWithRemoteNotification:`. That runs off
    //   `UIApplicationDidFinishLaunchingNotification` or the scene-delegate
    //   connection — and this app registers its plugins from
    //   `didInitializeImplicitFlutterEngine`, which the implicit engine
    //   fires when the storyboard builds its `FlutterViewController`. By
    //   then the launch notification has been and gone.
    //
    // Calling it here needs no plugin internals to hold. It is idempotent,
    // iOS ignores repeat calls, and — importantly — it does NOT prompt: the
    // permission sheet is `requestAuthorization`'s, so the pre-permission
    // screen (docs/02 D4) still owns the only dialog the user ever sees.
    // Registering before a grant is correct and is what the plugin itself
    // does; APNs answers either way and the token is useless until the user
    // says yes.
    application.registerForRemoteNotifications()
    return started
  }

  /// Hands APNs' device token to FCM.
  ///
  /// Deliberately not left to the plugin's `GULAppDelegateSwizzler`: that
  /// interception is installed by the same `setupNotificationHandling…` pass
  /// that was never running, so relying on it would fix the registration
  /// call above and still drop the answer to it on the floor.
  ///
  /// `Messaging.apnsToken` auto-detects the APNs environment from the
  /// provisioning profile, which is strictly better than the plugin's
  /// `#ifdef DEBUG` split: a profile or release build installed by
  /// `flutter run` rather than exported keeps `aps-environment: development`
  /// while compiling without `DEBUG`, and the plugin would then register a
  /// Production token against a Sandbox registration — every push silently
  /// dropped by APNs, which is the trap `Runner.entitlements` documents.
  ///
  /// `super` still runs so the plugin (and anything else registered through
  /// `addApplicationDelegate:`) sees the token too. Setting it twice is
  /// harmless; not setting it at all is the bug.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
  }

  /// Says out loud that push is dead on this build.
  ///
  /// The plugin's own handler only `NSLog`s, and the failure downstream is
  /// indistinguishable from "the user declined" — `tokenOrNull()` catches the
  /// FCM refusal into the same `null`. This is the one place the real reason
  /// exists, so it is worth naming.
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog(
      "push: APNs registration FAILED — %@. No FCM token can be minted, so no "
        + "device row is written and every server push goes nowhere.",
      error.localizedDescription
    )
    super.application(
      application,
      didFailToRegisterForRemoteNotificationsWithError: error
    )
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    CirrusWatchLink.shared.attach(
      messenger: engineBridge.pluginRegistry
        .registrar(forPlugin: "CirrusWatchLink")?
        .messenger()
    )
  }
}
