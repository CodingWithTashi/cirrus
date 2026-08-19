import 'package:flutter/foundation.dart';

/// Which backend answers the repository contracts (the seam documented in
/// `stores/providers.dart`).
enum BackendMode { fake, firebase }

/// `--dart-define=LP_BACKEND=fake|firebase` overrides the platform default:
/// mobile devices get the real Firebase backend; everything else (desktop
/// dev, web previews, widget tests) stays on the in-memory fake so the demo
/// model and Frame Map keep working without any console setup.
BackendMode resolveBackendMode() {
  const override = String.fromEnvironment('LP_BACKEND');
  switch (override) {
    case 'fake':
      return BackendMode.fake;
    case 'firebase':
      return BackendMode.firebase;
  }
  if (kIsWeb) return BackendMode.fake;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => BackendMode.firebase,
    _ => BackendMode.fake,
  };
}
