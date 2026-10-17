import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/repositories/repositories.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// Oct 16 2026: since the quiz moved in front of the account (docs/10 §49),
/// the account is asked for after the hold-to-commit and nothing goes on
/// without one. The first funnel read after that held thirteen Apple
/// failures — and each one ended on a dialog whose only way forward was to
/// tap the sheet that had just failed.
///
/// A failed identity sheet now offers email beside the retry, and Apple's
/// "no answer" (1000) has copy that says so instead of "that one's on us".
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<void> pumpSignIn(WidgetTester tester, AuthRepository auth) async {
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        authRepositoryProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    await parkOnSignIn(tester);
  }

  testWidgets(
    'Apple 1000 names itself and leads to email',
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    (tester) async {
      await pumpSignIn(
        tester,
        const _FailingAuth(apple: SignInUnavailableException('unknown/1000')),
      );

      await tester.tap(find.text(l10n.authSignInWithApple));
      await tester.pumpAndSettle();

      expect(find.text(l10n.errorSignInUnavailableTitle), findsOneWidget);
      expect(find.text(l10n.errorGenericTitle), findsNothing);
      final dialog = find.byType(AlertDialog);
      final email = find.descendant(
        of: dialog,
        matching: find.text(l10n.authContinueWithEmail),
      );
      expect(email, findsOneWidget);
      expect(
        find.descendant(of: dialog, matching: find.text(l10n.errorRetry)),
        findsOneWidget,
      );
      // No dead end beside the two ways through.
      expect(
        find.descendant(of: dialog, matching: find.text(l10n.errorGotIt)),
        findsNothing,
      );

      await tester.tap(email);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(l10n.authRegisterTitle), findsOneWidget);
    },
  );

  testWidgets('any other sheet failure keeps the generic copy, and email', (
    tester,
  ) async {
    // The test platform is android: Google is the identity button there.
    await pumpSignIn(
      tester,
      const _FailingAuth(google: AuthProviderException('google/unknown_error')),
    );

    await tester.tap(find.text(l10n.authSignInWithGoogle));
    await tester.pumpAndSettle();

    expect(find.text(l10n.errorGenericTitle), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l10n.authContinueWithEmail),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.authRegisterTitle), findsOneWidget);
  });

  testWidgets('a dismissed sheet is still nothing at all', (tester) async {
    await pumpSignIn(
      tester,
      const _FailingAuth(google: SignInCancelledException()),
    );

    await tester.tap(find.text(l10n.authSignInWithGoogle));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });
}

class _FailingAuth implements AuthRepository {
  const _FailingAuth({this.apple, this.google});

  final Exception? apple;
  final Exception? google;

  @override
  Future<JourneyState?> signInWithApple() async => throw apple!;

  @override
  Future<JourneyState?> signInWithGoogle() async => throw google!;

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
