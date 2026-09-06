import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/data/api/firebase/app_check_setup.dart';
import 'package:last_puff/data/backend_mode.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/firebase_options.dart';

import 'harness.dart';

/// Leaves a signed-in, day-1 journey on THIS device — or takes it away again.
///
/// The home-screen widget cannot be tested from inside the app: adding it,
/// tapping it and killing the app in between all happen on the launcher, and
/// on iOS the launcher is driven by `ios/RunnerUITests`. That UI test needs
/// an account to already be signed in, and typing one through the sign-in
/// screen from XCTest is slow and brittle. This entrypoint signs one in the
/// way `f_firebase_backend_test.dart` does — through the store, past the
/// twenty onboarding screens — and, unlike a test run, leaves the session in
/// place for the next launch to restore.
///
/// Run it with `flutter run`, NOT `flutter test`: a test run tears the app
/// down when it finishes, and the whole point is what it leaves behind.
///
/// ```
/// flutter run -d UDID -t integration_test/j_widget_session_test.dart \
///   --dart-define=LP_BACKEND=firebase --dart-define-from-file=.dart_defines.json \
///   --dart-define=E2E_EMAIL=e2e-widget-TIMESTAMP@cirrus-test.app --no-resident
/// ```
///
/// Then reinstall the normal build (`flutter build ios --simulator …` →
/// `xcrun simctl install`), which restores the session on launch. When the
/// widget pass is done, the same command with `--dart-define=E2E_STEP=teardown`
/// deletes the account through `deleteUserData`, the way Settings does.
///
/// **Writes to production `alastpuff`.** One throwaway account per email.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const email = String.fromEnvironment(
    'E2E_EMAIL',
    defaultValue: 'e2e-widget@cirrus-test.app',
  );
  const step = String.fromEnvironment('E2E_STEP', defaultValue: 'setup');
  const password = 'e2e-secret-123';

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await activateAppCheck();
  });

  Future<E2E> boot(WidgetTester tester) async {
    final e2e = await E2E.boot(tester);
    expect(
      e2e.backend,
      BackendMode.firebase,
      reason: 'run this with --dart-define=LP_BACKEND=firebase',
    );
    await e2e.waitFor(const Duration(seconds: 3));
    return e2e;
  }

  testWidgets('widget session: $step for $email', (tester) async {
    final e2e = await boot(tester);
    final store = e2e.container.read(quitStoreProvider.notifier);

    if (step == 'teardown') {
      await store.logIn(email: email, password: password);
      await e2e.waitFor(const Duration(seconds: 5));
      expect(FirebaseAuth.instance.currentUser, isNotNull);
      // The app never awaits this (optimistic sign-out); a test can, so the
      // assertion below reads the settled state rather than a race.
      await store.deleteAccount();
      await e2e.waitFor(const Duration(seconds: 5));
      expect(
        FirebaseAuth.instance.currentUser,
        isNull,
        reason: 'the account was not deleted',
      );
      return;
    }

    await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await store.logIn(email: email, password: password);
    await e2e.waitFor(const Duration(seconds: 5));
    final uid = FirebaseAuth.instance.currentUser?.uid;
    expect(
      uid,
      isNotNull,
      reason: 'no auth session; on screen: ${e2e.texts()}',
    );

    // Straight past onboarding, the way f_firebase_backend_test does.
    await store.startJourney(
      profile: const UserProfile(alias: '@e2ewidget', avatarEmoji: '🧩'),
      plan: QuitPlan(
        method: QuitMethod.taper,
        paceDays: 30,
        startDate: DateTime.now(),
        baselinePuffsPerDay: 200,
        weeklySpend: 25,
        strength: NicStrength.mg50,
      ),
    );
    await e2e.waitFor(const Duration(seconds: 5));
    expect(e2e.container.read(quitStoreProvider), isNotNull);
    // Home should be up and the mirror pushed; the session persists in the
    // device keychain for the next launch.
    await e2e.waitFor(const Duration(seconds: 3));
  });
}
