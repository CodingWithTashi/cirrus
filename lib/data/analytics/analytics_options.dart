import 'package:flutter/foundation.dart';

import '../backend_mode.dart';

/// Analytics configuration, in source rather than behind a `--dart-define`.
///
/// The Amplitude key below is a **write-only client key**: it can send events
/// and read nothing, and it ships inside the binary either way — exactly the
/// class of value `lib/firebase_options.dart` already commits for Firebase.
/// A define instead would mean every `flutter build appbundle` has to remember
/// it, and a release that forgot produces an empty launch funnel nobody
/// notices for weeks. It is deliberately not `.appcheck_token`: that one is a
/// credential because a registered debug token bypasses attestation
/// project-wide. This one grants nothing.
abstract final class AnalyticsOptions {
  static const String amplitudeApiKey = '1b2fcc0196cb08f6e2898f0ea599bd0c';

  /// `--dart-define=LP_ANALYTICS=on|off`, mirroring `LP_BACKEND`.
  static const String _override = String.fromEnvironment('LP_ANALYTICS');
}

/// Whether events are sent at all.
///
/// Only the **release** app, and only where there is a project to report to.
///
/// `kReleaseMode`, not `!kDebugMode`: the launch gates and the >15% drop-off
/// alert are read straight off this funnel, so a profile build measuring
/// jank — and every `flutter test` — must not appear in it as a user. The
/// consequence worth knowing is that no vendor SDK is even constructed
/// outside a release build, so the API key never leaves a dev machine and
/// tests never reach a MethodChannel that is not there.
///
/// `LP_ANALYTICS=on` exists because without it the integration is
/// unverifiable — `./tool/device.ps1` builds debug, so every on-device run
/// would be silent.
bool analyticsEnabled(BackendMode backend) {
  if (AnalyticsOptions.amplitudeApiKey.isEmpty) return false;
  return switch (AnalyticsOptions._override) {
    'on' => true,
    'off' => false,
    _ => backend == BackendMode.firebase && kReleaseMode,
  };
}
