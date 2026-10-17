import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/repositories/repositories.dart';

import 'harness.dart';

/// A failed identity sheet, on a real font (docs/10 §51).
///
/// The account is required to go on, so a Google or Apple failure offers
/// "Continue with email" beside the retry — three actions in one dialog,
/// which is exactly what a fixed-width test font cannot tell you fits. The
/// provider is made to fail here; nothing leaves the device.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a failed Google sheet offers email, and email is one tap '
      'away', (tester) async {
    final e2e = await E2E.boot(
      tester,
      overrides: [authRepositoryProvider.overrideWithValue(_FailingGoogle())],
    );
    await e2e.waitFor(const Duration(seconds: 2));
    await e2e.tapSpan(e2e.l10n.authLogIn);
    await e2e.tapText(e2e.l10n.authSignInWithGoogle);
    await e2e.waitFor(const Duration(seconds: 1));

    expect(e2e.showing(e2e.l10n.errorGenericTitle), isTrue);
    final dialog = find.byType(AlertDialog);
    for (final label in [
      e2e.l10n.authContinueWithEmail,
      e2e.l10n.errorRetry,
    ]) {
      expect(
        find.descendant(of: dialog, matching: find.text(label)).hitTestable(),
        findsOneWidget,
        reason: '"$label" is not reachable in the dialog',
      );
    }
    // Two ways through and no dead end: "Got it" is dropped when there is
    // a second way, so the pair fits one row instead of stacking.
    expect(
      find.descendant(of: dialog, matching: find.text(e2e.l10n.errorGotIt)),
      findsNothing,
    );
    final email = tester.getCenter(
      find.descendant(
        of: dialog,
        matching: find.text(e2e.l10n.authContinueWithEmail),
      ),
    );
    final retry = tester.getCenter(
      find.descendant(of: dialog, matching: find.text(e2e.l10n.errorRetry)),
    );
    expect(
      (email.dy - retry.dy).abs(),
      lessThan(8),
      reason: 'the two actions stacked instead of sharing a row',
    );
    debugPrint('E2E-MARKER: signin-dialog');
    await e2e.waitFor(const Duration(seconds: 6));

    await e2e.tap(
      find.descendant(
        of: dialog,
        matching: find.text(e2e.l10n.authContinueWithEmail),
      ),
      why: 'Continue with email',
    );
    await e2e.waitFor(const Duration(seconds: 1));
    expect(e2e.showing(e2e.l10n.authRegisterTitle), isTrue);
    debugPrint('E2E-MARKER: register');
    await e2e.waitFor(const Duration(seconds: 4));
  });
}

class _FailingGoogle implements AuthRepository {
  @override
  Future<JourneyState?> signInWithGoogle() async =>
      throw const AuthProviderException('google/unknown_error');

  @override
  Future<JourneyState?> signInWithApple() async =>
      throw const AuthProviderException('unknown');

  @override
  Future<JourneyState?> restoreSession() async => null;

  @override
  Future<JourneyState?> signInWithEmail({
    required String email,
    required String password,
  }) async => null;

  @override
  Future<void> register({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<String?> currentUserId() async => null;

  @override
  Future<String?> ensureSessionId() async => null;
}
