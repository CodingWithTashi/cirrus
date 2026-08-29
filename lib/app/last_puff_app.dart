import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/lp_error.dart';
import '../data/stores/providers.dart';
import '../l10n/gen/app_localizations.dart';
import 'router/app_router.dart';
import 'theme/lp_theme.dart';

class LastPuffApp extends ConsumerWidget {
  const LastPuffApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsStoreProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: LpTheme.daylight(),
      darkTheme: LpTheme.midnight(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // App-level chrome: the offline strip floats above every screen.
      builder: (context, child) => Stack(
        children: [
          // Wraps the tree so it sits under a Localizations scope — the
          // reminder copy has to be in the user's language.
          _ServerStateSync(
            child: _ReminderSync(child: child ?? const SizedBox.shrink()),
          ),
          const Align(alignment: Alignment.topCenter, child: OfflineBanner()),
        ],
      ),
    );
  }
}

/// Keeps the device notification schedule in step with the journey and the
/// user's settings.
///
/// Renders nothing. It exists because the schedule depends on three things
/// that live in different places — the journey, the settings, and the
/// localized copy — and something has to sit where all three are in scope.
///
/// Syncing happens after the frame so a rebuild triggered by logging a puff
/// never blocks on a platform channel; [ReminderCoordinator] then drops the
/// call entirely when the plan has not actually changed.
class _ReminderSync extends ConsumerWidget {
  const _ReminderSync({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coordinator = ref.watch(reminderCoordinatorProvider);
    if (coordinator != null) {
      final journey = ref.watch(quitStoreProvider);
      final settings = ref.watch(settingsStoreProvider);
      final l10n = AppLocalizations.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        coordinator
            .sync(
              journey: journey,
              settings: settings,
              title: l10n.dangerReminderTitle,
              body: l10n.dangerReminderBody,
            )
            .ignore();
      });
    }
    return child;
  }
}

/// Re-reads the server-owned nightly advice when the app comes back to the
/// foreground.
///
/// `taperRecalc` writes just after the user's local midnight. Sessions are
/// long-lived — a phone left open overnight never re-runs the sign-in path —
/// so without this the advice would only ever be picked up on a cold start,
/// and the user would spend the day on yesterday's curve.
///
/// Renders nothing, and is a no-op on the fake backend, where the repository
/// answers null.
class _ServerStateSync extends ConsumerStatefulWidget {
  const _ServerStateSync({required this.child});

  final Widget child;

  @override
  ConsumerState<_ServerStateSync> createState() => _ServerStateSyncState();
}

class _ServerStateSyncState extends ConsumerState<_ServerStateSync> {
  AppLifecycleListener? _listener;

  @override
  void initState() {
    super.initState();
    // Constructed here rather than as a field initializer: the listener
    // registers itself with the binding on construction, so it must not be
    // built lazily on first access.
    _listener = AppLifecycleListener(
      onResume: () => ref.read(quitStoreProvider.notifier).pullPlanAdvice(),
    );
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
