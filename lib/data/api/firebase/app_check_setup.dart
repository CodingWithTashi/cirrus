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
/// the same value once:
///
/// ```
/// firebase appcheck:debugtokens:create <uuid> --project alastpuff \
///   --app 1:826701239342:android:6f8f39f49c52ee24e4bbbf --force
/// ```
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
/// Debug-only and best-effort: it must never delay or break a launch.
Future<void> logAppCheckStatus() async {
  if (!kDebugMode) return;
  try {
    final token = await FirebaseAppCheck.instance.getToken();
    if (token == null || token.isEmpty) {
      debugPrint(
        'app-check: NO TOKEN — every callable will fail as `unauthenticated`. '
        'Register this build: see lib/data/api/firebase/app_check_setup.dart',
      );
      return;
    }
    final pinned = appCheckDebugToken.isNotEmpty;
    debugPrint(
      'app-check: token acquired (${pinned ? 'pinned debug secret' : 'rotating debug secret — '
                  'pass --dart-define=LP_APPCHECK_DEBUG_TOKEN to stop the rotation'}).',
    );
  } on Object catch (error) {
    debugPrint(
      'app-check: token request failed — $error. Every callable will be '
      'rejected; this is NOT an offline condition.',
    );
  }
}
