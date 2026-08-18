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
          ?child,
          const Align(alignment: Alignment.topCenter, child: OfflineBanner()),
        ],
      ),
    );
  }
}
