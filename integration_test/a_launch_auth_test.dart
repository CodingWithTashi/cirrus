import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/data/stores/providers.dart';

import 'harness.dart';

/// Launch, the auth gate, and every sign-in path (docs/02 §1).
///
/// Run against the fake backend:
///   flutter test integration_test/a_launch_auth_test.dart \
///     -d emulator-5554 --dart-define=LP_BACKEND=fake
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cold start lands on sign-in with no session', (tester) async {
    final e2e = await E2E.boot(tester);
    await e2e.waitFor(const Duration(seconds: 2));
    await e2e.settle();

    expect(e2e.showing(e2e.l10n.authSignInTitle), isTrue,
        reason: 'on screen: ${e2e.texts()}');
    expect(e2e.container.read(quitStoreProvider), isNull);
  });

  testWidgets('the demo account restores a day-12 journey', (tester) async {
    final e2e = await E2E.boot(tester);
    await e2e.waitFor(const Duration(seconds: 2));

    await e2e.tapText(e2e.l10n.authContinueWithEmail);
    // Continue-with-email opens Register; Log in is a span on that screen.
    await e2e.tapSpan(e2e.l10n.authLogIn);
    await e2e.enterField(e2e.l10n.authEmailLabel, 'maya@quitmail.com');
    await e2e.enterField(e2e.l10n.authPasswordLabel, 'secret1');
    await e2e.tapText(e2e.l10n.authLogIn);
    await e2e.waitFor(const Duration(seconds: 2));

    final journey = e2e.container.read(quitStoreProvider);
    expect(journey, isNotNull, reason: 'on screen: ${e2e.texts()}');
    expect(journey!.plan.baselinePuffsPerDay, 200);
    expect(e2e.container.read(todayProvider)!.dayNumber, 12);
  });

  testWidgets('a short password is refused and never opens a session', (
    tester,
  ) async {
    final e2e = await E2E.boot(tester);
    await e2e.waitFor(const Duration(seconds: 2));

    await e2e.tapText(e2e.l10n.authContinueWithEmail);
    await e2e.tapSpan(e2e.l10n.authLogIn);
    await e2e.enterField(e2e.l10n.authEmailLabel, 'someone@example.com');
    await e2e.enterField(e2e.l10n.authPasswordLabel, '123');
    await e2e.tapText(e2e.l10n.authLogIn);
    await e2e.waitFor(const Duration(seconds: 2));

    expect(e2e.container.read(quitStoreProvider), isNull);
    // The inline "wrong password" line, not a dialog — a bad password is an
    // expected answer, not an error surface (docs/02 §1).
    expect(e2e.showing(e2e.l10n.authWrongPassword), isTrue,
        reason: 'on screen: ${e2e.texts()}');
  });

  testWidgets('offline sign-in shows the offline dialog, not a dead button', (
    tester,
  ) async {
    final e2e = await E2E.boot(tester, online: false);
    await e2e.waitFor(const Duration(seconds: 2));

    await e2e.tapText(e2e.l10n.authContinueWithEmail);
    await e2e.tapSpan(e2e.l10n.authLogIn);
    await e2e.enterField(e2e.l10n.authEmailLabel, 'maya@quitmail.com');
    await e2e.enterField(e2e.l10n.authPasswordLabel, 'secret1');
    await e2e.tapText(e2e.l10n.authLogIn);
    await e2e.waitFor(const Duration(seconds: 3));

    expect(e2e.visible(e2e.l10n.errorOfflineTitle), isTrue,
        reason: 'on screen: ${e2e.texts()}');
    expect(e2e.container.read(quitStoreProvider), isNull);
  });

  testWidgets('registering the demo email is refused as already in use', (
    tester,
  ) async {
    final e2e = await E2E.boot(tester);
    await e2e.waitFor(const Duration(seconds: 2));

    await e2e.tapText(e2e.l10n.authContinueWithEmail);
    await e2e.enterField(e2e.l10n.authEmailLabel, 'maya@quitmail.com');
    await e2e.enterField(e2e.l10n.authPasswordLabel, 'secret123');
    await e2e.tapText(e2e.l10n.authCreateAccount);

    // A snack, so it has to be caught while it is up rather than after a
    // fixed sleep.
    expect(await e2e.waitForText(e2e.l10n.authEmailInUse), isTrue,
        reason: 'on screen: ${e2e.texts()}');
    expect(e2e.container.read(quitStoreProvider), isNull);
  });
}
