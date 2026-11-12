import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/enums.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// Signing out says how to get back in, and what leaving costs.
///
/// Seven people signed out in the 90 days to Nov 11 2026 and five of them made
/// a brand-new account straight afterwards. One was a paying subscriber: two
/// failed email logins, a password reset, then Apple — a different account,
/// on the free tier, inside a month they had paid for. Nothing on the way out
/// had told them which button they came in by, and nothing on the way back
/// in told them a wrong password might be the wrong DOOR.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  // The fallback test font is wider than the device's; real overflow is
  // caught on device (see `screen_layout_test.dart`).
  void ignoreFontWidthOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  Future<ProviderContainer> openSignOutDialog(
    WidgetTester tester, {
    required AccountProvider? method,
    bool premium = true,
  }) async {
    ignoreFontWidthOverflow();
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(premium: premium),
        accountProviderProvider.overrideWith((_) async => method),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    unawaited(container.read(routerProvider).push(Routes.settings));
    await tester.pumpAndSettle();
    final signOut = find.text(l10n.settingsSignOut, skipOffstage: false);
    await tester.scrollUntilVisible(
      signOut,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(signOut);
    await tester.pumpAndSettle();
    expect(find.text(l10n.settingsSignOutConfirmTitle), findsOneWidget);
    return container;
  }

  testWidgets('a subscriber who came in with Apple is told both things', (
    tester,
  ) async {
    await openSignOutDialog(tester, method: AccountProvider.apple);

    expect(find.text(l10n.settingsSignOutConfirmBody), findsOneWidget);
    expect(find.text(l10n.settingsSignOutMethodApple), findsOneWidget);
    expect(find.text(l10n.settingsSignOutPremium), findsOneWidget);
  });

  testWidgets('a free account is told the method and nothing about Premium', (
    tester,
  ) async {
    await openSignOutDialog(
      tester,
      method: AccountProvider.email,
      premium: false,
    );

    expect(find.text(l10n.settingsSignOutMethodEmail), findsOneWidget);
    expect(find.text(l10n.settingsSignOutPremium), findsNothing);
  });

  testWidgets('Google is named as Google', (tester) async {
    await openSignOutDialog(
      tester,
      method: AccountProvider.google,
      premium: false,
    );

    expect(find.text(l10n.settingsSignOutMethodGoogle), findsOneWidget);
    expect(find.text(l10n.settingsSignOutMethodApple), findsNothing);
  });

  testWidgets('with no method to name, the dialog says only what it knows', (
    tester,
  ) async {
    await openSignOutDialog(tester, method: null, premium: false);

    expect(find.text(l10n.settingsSignOutConfirmBody), findsOneWidget);
    expect(find.text(l10n.settingsSignOutMethodApple), findsNothing);
    expect(find.text(l10n.settingsSignOutMethodGoogle), findsNothing);
    expect(find.text(l10n.settingsSignOutMethodEmail), findsNothing);
  });

  group('getting back in by email', () {
    Future<ProviderContainer> openLogin(WidgetTester tester) async {
      ignoreFontWidthOverflow();
      final container = ProviderContainer(overrides: fastBackendOverrides());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const LastPuffApp(),
        ),
      );
      await parkOnSignIn(tester);
      unawaited(container.read(routerProvider).push(Routes.login));
      await tester.pumpAndSettle();
      return container;
    }

    Future<void> failLogin(WidgetTester tester) async {
      // The fake backend calls any password under six characters wrong.
      await tester.enterText(find.byType(TextField).last, 'abc');
      await tester.tap(find.text(l10n.authLogIn));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    Future<void> on(TargetPlatform platform, Future<void> Function() body) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await body();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    testWidgets('forgot-password opens on the email already typed', (
      tester,
    ) async {
      await openLogin(tester);
      await tester.enterText(find.byType(TextField).first, 'lena@example.com');

      await tester.tap(find.text(l10n.authForgotPassword));
      await tester.pumpAndSettle();

      expect(find.text(l10n.authForgotTitle), findsOneWidget);
      expect(find.widgetWithText(TextField, 'lena@example.com'), findsOneWidget);
    });

    testWidgets('one wrong password is just a wrong password', (tester) async {
      await on(TargetPlatform.iOS, () async {
        await openLogin(tester);
        await failLogin(tester);

        expect(find.text(l10n.authWrongPassword), findsOneWidget);
        expect(find.text(l10n.authLoginTryApple), findsNothing);
      });
    });

    testWidgets('a second one on an iPhone asks whether it was Apple', (
      tester,
    ) async {
      await on(TargetPlatform.iOS, () async {
        await openLogin(tester);
        await failLogin(tester);
        await failLogin(tester);

        expect(find.text(l10n.authLoginTryApple), findsOneWidget);
        expect(find.text(l10n.authLoginTryGoogle), findsNothing);
      });
    });

    testWidgets('and on Android, whether it was Google', (tester) async {
      await on(TargetPlatform.android, () async {
        await openLogin(tester);
        await failLogin(tester);
        await failLogin(tester);

        expect(find.text(l10n.authLoginTryGoogle), findsOneWidget);
        expect(find.text(l10n.authLoginTryApple), findsNothing);
      });
    });
  });
}
