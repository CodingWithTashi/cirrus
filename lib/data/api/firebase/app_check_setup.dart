import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// App Check wiring, and the diagnostic that makes a failure say its own name.
///
/// Every callable sets `enforceAppCheck: true`, so this is load-bearing: with a
/// token the backend will not accept, **every** callable fails — coach, panic,
/// community, user sync — and the app looks comprehensively broken rather than
/// misconfigured in one place.
///
/// ## Why the debug token is pinned
///
/// The Android debug provider mints a fresh secret **on every install**, and
/// `flutter test integration_test` uninstalls the app when it finishes. So a
/// token registered after a run is already stale, and the loop is: install,
/// read logcat, register, run, uninstall, repeat — with an unregistered build
/// in between that fails every call while looking like an outage. Pinning the
/// secret ends that: register it once and every future debug install on any
/// machine is already trusted.
///
/// Supply it with `--dart-define=LP_APPCHECK_DEBUG_TOKEN=<uuid>` and register
/// the same value once **per Firebase app** — the Android and iOS apps are
/// separate registrations, and a token known to only one of them makes the
/// other platform's build fail every callable:
///
/// ```
/// firebase appcheck:debugtokens:create <uuid> --project alastpuff \
///   --app 1:826701239342:android:6f8f39f49c52ee24e4bbbf --force
/// firebase appcheck:debugtokens:create <uuid> --project alastpuff \
///   --app 1:826701239342:ios:042418c48b5e6f38e4bbbf --force
/// ```
///
/// `tool/device.ps1` does both the define and the registration on Windows. On
/// macOS run the commands above by hand and launch with
/// `flutter run --dart-define-from-file=.dart_defines.json`.
///
/// It is a dart-define rather than a constant because a registered debug token
/// bypasses attestation for the whole project — it is a credential, and
/// credentials do not belong in git. With no define we fall back to the
/// rotating provider, which still works; it just costs you the dance above.
///
/// Release builds are untouched: Play Integrity on Android, App Attest on
/// Apple. `kDebugMode` gates the whole thing, so a debug secret cannot ship.
const appCheckDebugToken = String.fromEnvironment('LP_APPCHECK_DEBUG_TOKEN');

/// Activates App Check for the current build.
Future<void> activateAppCheck() async {
  const token = appCheckDebugToken;
  // The define was supplied, and this build cannot use it.
  //
  // This is the trap that keeps costing a session, because the command LOOKS
  // right: `flutter build apk --release --dart-define-from-file=.dart_defines.json`
  // passes the pinned token exactly the way `./tool/device.ps1` does — and
  // then `kDebugMode` is false, the token is read into a constant nothing
  // consults, and the build attests with Play Integrity instead.
  //
  // Play Integrity cannot vouch for an APK that Google has never seen. A
  // locally built, sideloaded release gets no valid token, the SDK sends
  // something that is not a JWT, and the backend answers every single
  // callable with `Decoding App Check token failed` — coach, panic,
  // community, testimonials, user sync, all at once, all looking like
  // unrelated bugs.
  //
  // Printed in EVERY build mode, because the mode is the thing being warned
  // about.
  if (!kDebugMode && token.isNotEmpty) {
    debugPrint(
      '========================================================\n'
      'app-check: LP_APPCHECK_DEBUG_TOKEN was passed to a NON-DEBUG build '
      'and is being IGNORED.\n'
      'This build attests with Play Integrity / App Attest, which cannot '
      'verify a sideloaded APK - so EVERY callable will be rejected.\n'
      'On-device testing: ./tool/device.ps1 (add -Analytics for the funnel).\n'
      'Testing a real release build: install from the Play internal testing '
      'track - sideloading cannot pass, whatever defines you add.\n'
      '========================================================',
    );
  }
  if (kDebugMode && token.isEmpty) {
    // The exact configuration that produces a comprehensively broken app, so
    // it says so BEFORE the first callable rather than one layer down wearing
    // an offline error. Forgetting the define is not a niche mistake: it is
    // what plain `flutter run` and every IDE run button do by default, and the
    // resulting token is unregistered by construction, so EVERY callable is
    // rejected with 403 and `users/{uid}` is never written.
    debugPrint(
      '========================================================\n'
      'app-check: NO PINNED DEBUG TOKEN.\n'
      'This build minted a throwaway token that is NOT registered, so'
      ' every callable will be rejected (403) and nothing will reach'
      ' Firestore.\n'
      'Launch with ./tool/device.ps1, or pass'
      ' --dart-define-from-file=.dart_defines.json.\n'
      '========================================================',
    );
  }
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? (token.isEmpty
              ? const AndroidDebugProvider()
              : const AndroidDebugProvider(debugToken: token))
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? (token.isEmpty
              ? const AppleDebugProvider()
              : const AppleDebugProvider(debugToken: token))
        : const AppleAppAttestProvider(),
  );
}

/// Logs whether this build can actually obtain an App Check token.
///
/// The failure this catches is silent by construction: an unregistered token is
/// rejected at the *server*, so the client sails on and every feature fails one
/// layer down wearing an offline error. Asking for a token at startup turns
/// that into one line in logcat, at launch, naming the fix — the same trick
/// `aiCoachChat` uses when it logs the live model catalogue on a 404.
///
/// Runs in **every** build mode, and that is the point.
///
/// It used to start with `if (!kDebugMode) return;`, which meant the one
/// diagnostic written to catch a missing App Check token was switched off in
/// exactly the build that fails most confusingly. A release APK built locally
/// and sideloaded cannot obtain a token at all, so it failed every callable in
/// total silence — no warning at launch, and four layers down an error that
/// reads like the network. Debug builds have `activateAppCheck`'s own loud
/// notice; release builds had nothing until here.
///
/// Best-effort: never delays a launch, never throws, one line either way. Safe
/// in a store build too — it is a log line, and a real user whose attestation
/// is failing is worth being able to diagnose.
Future<void> logAppCheckStatus() async {
  try {
    final token = await FirebaseAppCheck.instance.getToken();
    if (token == null || token.isEmpty) {
      debugPrint(
        'app-check: NO TOKEN — every callable will fail as `unauthenticated`. '
        '${kDebugMode ? 'Register this build: see lib/data/api/firebase/app_check_setup.dart' : 'This is a non-debug build: Play Integrity / App Attest could not '
              'vouch for it. A sideloaded release APK never can — install from '
              'the Play internal testing track, or use ./tool/device.ps1.'}',
      );
      return;
    }
    final how = !kDebugMode
        ? 'Play Integrity / App Attest'
        : appCheckDebugToken.isNotEmpty
        ? 'pinned debug secret'
        : 'rotating debug secret — pass --dart-define=LP_APPCHECK_DEBUG_TOKEN '
              'to stop the rotation';
    debugPrint('app-check: token acquired ($how).');
  } on Object catch (error) {
    debugPrint(
      'app-check: token request failed — $error. Every callable will be '
      'rejected; this is NOT an offline condition.',
    );
  }
}
