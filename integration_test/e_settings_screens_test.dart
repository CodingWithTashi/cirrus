import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/games/game_id.dart';

import 'package:last_puff/l10n/gen/app_localizations.dart';

import 'harness.dart';

/// Settings, the destructive paths, and a sweep of every route.
///
/// The sweep is the cheap half and the valuable half: a screen that throws on
/// build is invisible until someone opens it, and half these routes are one
/// tap deep from Home.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<E2E> signedIn(WidgetTester tester) async {
    final e2e = await E2E.boot(tester);
    await e2e.waitFor(const Duration(seconds: 2));
    await e2e.tapText(e2e.l10n.authContinueWithEmail);
    await e2e.tapSpan(e2e.l10n.authLogIn);
    await e2e.enterField(e2e.l10n.authEmailLabel, 'maya@quitmail.com');
    await e2e.enterField(e2e.l10n.authPasswordLabel, 'secret1');
    await e2e.tapText(e2e.l10n.authLogIn);
    await e2e.waitFor(const Duration(seconds: 3));
    expect(e2e.container.read(quitStoreProvider), isNotNull,
        reason: 'sign-in failed; on screen: ${e2e.texts()}');
    return e2e;
  }

  /// Every route reachable with a live journey. The shell tabs are driven
  /// separately below because they are a StatefulShellRoute, not a push.
  final routes = [
    Routes.plan,
    Routes.money,
    Routes.health,
    Routes.milestones,
    Routes.insight,
    Routes.profile,
    Routes.settings,
    Routes.slip,
    Routes.day1,
    Routes.panic,
    Routes.game,
    Routes.gameFor(GameId.blocks),
    Routes.gameFor(GameId.orbs),
    Routes.survived,
    Routes.compose,
    Routes.paywall,
    Routes.paywallFree,
    Routes.winback,
    Routes.trialEnding,
    Routes.moderation,
  ];

  testWidgets('every route builds without throwing', (tester) async {
    final e2e = await signedIn(tester);
    final router = e2e.container.read(routerProvider);

    final broke = <String, Object>{};
    for (final route in routes) {
      try {
        router.go(route);
        await e2e.settle(frames: 40);
        final error = tester.takeException();
        if (error != null) broke[route] = error;
      } on Object catch (error) {
        broke[route] = error;
      }
      // Back to a known-good screen so one bad route cannot cascade.
      router.go(Routes.home);
      await e2e.settle(frames: 20);
      tester.takeException();
    }

    expect(broke, isEmpty, reason: 'routes that threw on build: $broke');
  });

  testWidgets('all four shell tabs render', (tester) async {
    final e2e = await signedIn(tester);
    for (final label in [
      e2e.l10n.navStats,
      e2e.l10n.navCommunity,
      e2e.l10n.navCoach,
      e2e.l10n.navHome,
    ]) {
      await e2e.tapText(label);
      await e2e.waitFor(const Duration(seconds: 2));
      expect(tester.takeException(), isNull, reason: 'tab "$label" threw');
    }
  });

  testWidgets('an unknown route lands on the friendly dead end', (
    tester,
  ) async {
    final e2e = await signedIn(tester);
    e2e.container.read(routerProvider).go('/does-not-exist');
    await e2e.settle();

    expect(e2e.visible(e2e.l10n.errorRouteTitle), isTrue,
        reason: 'on screen: ${e2e.texts()}');
  });

  testWidgets('theme and locale changes apply live', (tester) async {
    final e2e = await signedIn(tester);
    final settings = e2e.container.read(settingsStoreProvider.notifier);

    settings.setThemeMode(ThemeMode.light);
    await e2e.settle();
    expect(tester.takeException(), isNull);
    expect(e2e.container.read(settingsStoreProvider).themeMode, ThemeMode.light);

    settings.setLocale(const Locale('fr'));
    await e2e.settle();
    expect(tester.takeException(), isNull);
    // The whole UI is localized, so a locale switch must actually change what
    // is rendered — not just the stored preference.
    final fr = await AppLocalizations.delegate.load(const Locale('fr'));
    expect(fr.commonContinue, isNot(e2e.l10n.commonContinue));
    expect(
      e2e.texts().any((t) => t.contains(fr.settingsTitle)) ||
          e2e.showing(fr.commonContinue) ||
          e2e.showing(fr.navHome),
      isTrue,
      reason: 'French copy never rendered; on screen: ${e2e.texts()}',
    );

    settings.setLocale(null);
    settings.setThemeMode(ThemeMode.dark);
    await e2e.settle();
  });

  testWidgets('the moderation row is hidden for a non-admin', (tester) async {
    final e2e = await signedIn(tester);
    e2e.container.read(routerProvider).go(Routes.settings);
    await e2e.waitFor(const Duration(seconds: 2));

    // The fake backend reports "not a moderator", and the row must not exist
    // at all — not merely be disabled.
    expect(e2e.showing(e2e.l10n.moderationTitle), isFalse,
        reason: 'on screen: ${e2e.texts()}');
  });

  testWidgets('sign-out clears the session and returns to auth', (
    tester,
  ) async {
    final e2e = await signedIn(tester);
    e2e.container.read(routerProvider).go(Routes.settings);
    await e2e.waitFor(const Duration(seconds: 2));

    await e2e.scrollTo(find.text(e2e.l10n.settingsSignOut));
    await e2e.tapText(e2e.l10n.settingsSignOut);
    await e2e.waitFor(const Duration(seconds: 1));
    // The row and the dialog's confirm button carry the same label; the
    // dialog's is the one added last.
    await e2e.tap(find.text(e2e.l10n.settingsSignOut).last, why: 'confirm');
    await e2e.waitFor(const Duration(seconds: 3));

    expect(e2e.container.read(quitStoreProvider), isNull);
    expect(e2e.visible(e2e.l10n.authSignInTitle), isTrue,
        reason: 'on screen: ${e2e.texts()}');
  });

  testWidgets('deleting the account waits for the backend before leaving', (
    tester,
  ) async {
    final e2e = await signedIn(tester);
    e2e.container.read(routerProvider).go(Routes.settings);
    await e2e.waitFor(const Duration(seconds: 2));

    await e2e.scrollTo(find.text(e2e.l10n.settingsDeleteEverything));
    await e2e.tapText(e2e.l10n.settingsDeleteEverything);
    await e2e.waitFor(const Duration(seconds: 1));
    await e2e.tapText(e2e.l10n.settingsDeleteConfirmCta);
    await e2e.waitFor(const Duration(seconds: 4));

    expect(e2e.container.read(quitStoreProvider), isNull,
        reason: 'on screen: ${e2e.texts()}');
    expect(e2e.visible(e2e.l10n.authSignInTitle), isTrue);
  });
}
