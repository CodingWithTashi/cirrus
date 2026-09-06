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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
