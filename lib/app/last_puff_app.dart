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
          _ReminderSync(child: child ?? const SizedBox.shrink()),
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
