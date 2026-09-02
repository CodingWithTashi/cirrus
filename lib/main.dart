import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_errors.dart';
import 'app/last_puff_app.dart';
import 'data/api/firebase/app_check_setup.dart';
import 'data/backend_mode.dart';
import 'data/repositories/revenuecat_billing_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait only. The design is 52 portrait frames and there is no landscape
  // layout for any of them, so a rotated phone renders the app into a
  // viewport nothing was drawn for. The Android manifest locks this too; this
  // is the half that will still be true on iOS.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  if (resolveBackendMode() == BackendMode.firebase) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Every callable sets enforceAppCheck: true, so without this the backend
    // rejects the app outright — see app_check_setup.dart for why the debug
    // secret is pinned rather than left to rotate per install.
    await activateAppCheck();
    // Deliberately not awaited: a diagnostic must not sit in front of the
    // first frame. It only ever prints.
    unawaited(logAppCheckStatus());
    // Inside the Firebase guard for the same reason everything else is: the
    // fake backend, desktop and every widget test must never touch a store
    // SDK's platform channel. Never throws — see `configure`.
    await RevenueCatBillingRepository.configure();
  }
  LpErrors.install(
    // Crash reporting only where there is a Firebase project to report to,
    // and never from debug builds — see LpErrors.install.
    reportCrashes: resolveBackendMode() == BackendMode.firebase && !kDebugMode,
  );
  runApp(const ProviderScope(child: LastPuffApp()));
}
