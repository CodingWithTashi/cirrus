import 'dart:async';

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/repositories/repositories.dart';
import 'package:last_puff/features/auth/apple_sign_in_button.dart';
import 'package:last_puff/features/onboarding/onboarding_flow.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// The three ways a native identity sign-in can end, each with its designated
/// surface (CLAUDE.md "Error handling"): a dismissed sheet shows nothing, a
/// wire failure gets the offline dialog with a working retry, and an
/// unexpected `Error` is left for `LpErrors` — but the button must come back
/// in every case. The busy flag used to be reset per branch, so anything that
/// was not an `Exception` left the spinner up forever.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  /// The Apple button only renders on Apple platforms. The override has to be
  /// undone inside the test body — the binding checks foundation debug
  /// variables before `tearDown` runs.
  Future<void> onIOS(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Future<void> pumpSignIn(WidgetTester tester, _ScriptedAuth auth) async {
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
    await tester.pump(const Duration(seconds: 2)); // splash beat
    await tester.pumpAndSettle();
    expect(find.text(l10n.authSignInWithApple), findsOneWidget);
  }

  /// Taps Apple and lets the awaited call and any dialog animate in. Bounded
  /// pumps, never pumpAndSettle: onboarding animates forever once reached.
  Future<void> tapApple(WidgetTester tester) async {
    await tester.tap(find.text(l10n.authSignInWithApple));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Finder appleSpinner() => find.descendant(
    of: find.byType(AppleSignInButton),
    matching: find.byType(CircularProgressIndicator),
  );

  testWidgets(
    'a dismissed sheet shows nothing and re-arms the button',
    (tester) => onIOS(() async {
      await pumpSignIn(
        tester,
        _ScriptedAuth(() async => throw const SignInCancelledException()),
      );
      await tapApple(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(appleSpinner(), findsNothing);
      expect(find.text(l10n.authSignInWithApple), findsOneWidget);
    }),
  );

  testWidgets(
    'offline gets the offline dialog; retry runs the flow again',
    (tester) => onIOS(() async {
      final auth = _ScriptedAuth(
        () async => throw const NoConnectionException(),
      );
      await pumpSignIn(tester, auth);
      await tapApple(tester);

      expect(find.text(l10n.errorOfflineTitle), findsOneWidget);
      expect(appleSpinner(), findsNothing);

      // Connection back: the retry is the same flow, not a dead button.
      auth.apple = () async => null;
      await tester.tap(find.text(l10n.errorRetry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AlertDialog), findsNothing);
      expect(auth.appleCalls, 2);
      expect(find.byType(OnboardingFlow), findsOneWidget);
    }),
  );

  testWidgets(
    'an unexpected Error is not swallowed, and the button comes back',
    (tester) => onIOS(() async {
      await pumpSignIn(
        tester,
        _ScriptedAuth(() async => throw StateError('boom')),
      );

      // The button drops the tap's Future, so the Error can only reach the
      // zone — in the app that is LpErrors' backstage snack. Catch it here to
      // prove it was neither swallowed nor turned into a dialog.
      Object? uncaught;
      await runZonedGuarded(
        () => tapApple(tester),
        (error, _) => uncaught = error,
      );

      expect(uncaught, isA<StateError>());
      expect(find.byType(AlertDialog), findsNothing);
      expect(appleSpinner(), findsNothing);
      expect(find.text(l10n.authSignInWithApple), findsOneWidget);
    }),
  );
}

/// An [AuthRepository] whose Apple sign-in does whatever the test scripts.
class _ScriptedAuth implements AuthRepository {
  _ScriptedAuth(this.apple);

  Future<JourneyState?> Function() apple;
  int appleCalls = 0;

  @override
  Future<JourneyState?> signInWithApple() {
    appleCalls++;
    return apple();
  }

  @override
  Future<JourneyState?> signInWithGoogle() async => null;

  @override
  Future<JourneyState?> signInWithEmail({
    required String email,
    required String password,
  }) async => null;

  @override
  Future<JourneyState?> restoreSession() async => null;

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
