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

  /// Call once, before runApp.
  static void install() {
    FlutterError.onError = FlutterError.presentError;
    ErrorWidget.builder = crashScreen;
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('LastPuff uncaught: $error\n$stack');
      _toastQuietly();
      return true; // handled — a Crashlytics forward slots in here later
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
