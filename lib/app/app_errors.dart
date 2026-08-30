import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/utils/l10n_ext.dart';
import '../core/widgets/lp_crash_screen.dart';
import '../core/widgets/lp_misc.dart';
import 'router/app_router.dart';

/// App-level safety net. Three layers:
///  1. Framework errors (build/layout/paint) — logged as usual; the crashed
///     subtree renders [LpCrashScreen] instead of the red box.
///  2. Uncaught async errors — logged, swallowed (the app never hard-crashes
///     for a background hiccup), and surfaced as one gentle, throttled snack.
///  3. Expected data errors (offline, backend) — those never get here: stores
///     and views catch them and show the friendly surfaces in lp_error.dart.
abstract final class LpErrors {
  static DateTime? _lastToastAt;
  static bool _reportCrashes = false;

  /// Call once, before runApp.
  ///
  /// [reportCrashes] wires Crashlytics. Off for the fake backend, where
  /// Firebase is never initialized — and off in debug, because the crash-free
  /// rate is only meaningful over real sessions and dev noise would drown the
  /// >= 99.5% launch gate (docs/06 §9).
  static void install({bool reportCrashes = false}) {
    _reportCrashes = reportCrashes;
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (_reportCrashes) {
        FirebaseCrashlytics.instance.recordFlutterError(details);
      }
    };
    ErrorWidget.builder = crashScreen;
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('Cirrus uncaught: $error\n$stack');
      if (_reportCrashes) {
        // Non-fatal on purpose: the app deliberately survives a background
        // hiccup, so reporting it as fatal would misstate the crash-free rate.
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
      }
      _toastQuietly();
      return true; // handled — the app never hard-crashes for a background error
    };
  }

  static Widget crashScreen(FlutterErrorDetails details) =>
      LpCrashScreen(details: details);

  /// "something glitched backstage" — at most once per 20s, and only after
  /// the current frame so it can never fire mid-build.
  static void _toastQuietly() {
    final now = DateTime.now();
    final last = _lastToastAt;
    if (last != null && now.difference(last) < const Duration(seconds: 20)) {
      return;
    }
    _lastToastAt = now;
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      final context = lpRootNavigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      showLpSnack(context, context.l10n.errorBackstage);
    });
    binding.ensureVisualUpdate();
  }
}
