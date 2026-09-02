import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/widgets/lp_misc.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/repositories/repositories.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// QA M4 (Aug 31 2026, production): Create account with the password `123`
/// showed "Well, that glitched — that one's on us". Firebase had answered
/// `weak-password` ("at least 6 characters"); the taxonomy had no case for
/// it, so the user was told the app broke and offered a retry that could
/// only fail the same way.
///
/// Two layers now, like the duplicate-email case: the backend's refusal maps
/// to its own exception with real copy, and the form declines a too-short
/// password before spending a round trip on it.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<ProviderContainer> pumpRegister(
    WidgetTester tester, {
    AuthRepository? auth,
  }) async {
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        if (auth != null) authRepositoryProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    container.read(routerProvider).go(Routes.register);
    await tester.pumpAndSettle();
    expect(find.text(l10n.authRegisterTitle), findsOneWidget);
    return container;
  }

  Future<void> submit(WidgetTester tester, String password) async {
    final fields = find.descendant(
      of: find.byType(LpField),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.first, 'new@cirrus.app');
    await tester.enterText(fields.last, password);
    await tester.tap(find.text(l10n.authCreateAccount));
    await tester.pumpAndSettle();
  }

  testWidgets('a too-short password is declined kindly, before the wire', (
    tester,
  ) async {
    final container = await pumpRegister(tester);

    await submit(tester, '123');

    expect(find.text(l10n.authPasswordTooShort), findsOneWidget);
    expect(find.text(l10n.errorGenericTitle), findsNothing);
    expect(
      find.text(l10n.authRegisterTitle),
      findsOneWidget,
      reason: 'stays put',
    );
    expect(container.read(quitStoreProvider), isNull);
    // Let the snack's force-close fallback timer expire.
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets("the backend's weak-password refusal gets the same copy", (
    tester,
  ) async {
    // A backend with a stricter rule than the form's: the taxonomy, not the
    // pre-check, is what keeps the glitch dialog away.
    await pumpRegister(tester, auth: _RefusingAuth());

    await submit(tester, 'longenough');

    expect(find.text(l10n.authPasswordTooShort), findsOneWidget);
    expect(find.text(l10n.errorGenericTitle), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });
}

class _RefusingAuth implements AuthRepository {
  @override
  Future<void> register({
    required String email,
    required String password,
  }) async => throw const WeakPasswordException();

  @override
  Future<String?> currentUserId() async => null;

  @override
  Future<String?> ensureSessionId() async => null;

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<JourneyState?> restoreSession() async => null;

  @override
  Future<JourneyState?> signInWithApple() async => null;

  @override
  Future<JourneyState?> signInWithEmail({
    required String email,
    required String password,
  }) async => null;

  @override
  Future<JourneyState?> signInWithGoogle() async => null;

  @override
  Future<void> signOut() async {}
}
