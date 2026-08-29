import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_errors.dart';
import 'app/last_puff_app.dart';
import 'data/api/firebase/lp_analytics.dart';
import 'data/backend_mode.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (resolveBackendMode() == BackendMode.firebase) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Every callable sets enforceAppCheck: true, so without this the backend
    // rejects the app outright. Debug builds use the debug provider, whose
    // token is printed to logcat and registered once per machine; release
    // builds attest through Play Integrity.
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? AndroidDebugProvider()
          : AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? AppleDebugProvider()
          : AppleAppAttestProvider(),
    );
  }
  LpAnalytics.configure(
    enabled: resolveBackendMode() == BackendMode.firebase && !kDebugMode,
  );
  LpErrors.install(
    // Crash reporting only where there is a Firebase project to report to,
    // and never from debug builds — see LpErrors.install.
    reportCrashes: resolveBackendMode() == BackendMode.firebase && !kDebugMode,
  );
  runApp(const ProviderScope(child: LastPuffApp()));
}
