import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/widgets/lp_misc.dart';
import 'package:last_puff/core/widgets/progress_ring.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/repositories/repositories.dart';
import 'package:last_puff/features/auth/auth_screens.dart';
import 'package:last_puff/features/onboarding/onboarding_flow.dart';
import 'package:last_puff/features/onboarding/onboarding_view_model.dart';
import 'package:last_puff/features/onboarding/steps/payoff_steps.dart';
import 'package:last_puff/features/onboarding/steps/welcome_step.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// The quiz before the account (docs/10 §49).
///
/// An account used to be asked for before the first question, and nine of the
/// first thirty-two real people left on that screen. The order is now: quiz,
/// hold to commit, THEN the account — asked for by someone who has just seen
/// their plan, on a screen that was always titled "Let's keep your plan safe."
///
/// Three promises, each of which is a way this could quietly break:
///
/// - Nobody who already has a plan answers the quiz twice. The welcome screen
///   carries "Log in", and signing in to an account with a journey goes Home
///   from either door.
/// - Nobody reaches the notifications ask, the paywall or a created journey
///   without an account. The step after the commit is only ever entered with
///   a session.
/// - Nobody who signed in FIRST — the only order there was until now — is
///   asked a second time.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  String path(ProviderContainer c) => c.read(routerProvider).state.uri.path;

  ObStep step(ProviderContainer c) => c.read(onboardingProvider).step;

  /// A signed-out launch, pumped through the splash onto the quiz. Bounded
  /// pumps throughout this file: the welcome screen never settles.
  Future<ProviderContainer> launch(
    WidgetTester tester, {
    List<Override> extra = const [],
  }) async {
    final container = ProviderContainer(
      overrides: [...fastBackendOverrides(premium: false), ...extra],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    return container;
  }

  Future<void> beat(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Holds the commit ring out and drains what follows: the 1.4s advance
  /// timer, the 1.6s confetti, and whatever route the commit leads to.
  ///
  /// Stepped, never one long pump: a ticker's first frame only sets its start
  /// time, so a single three-second pump leaves the hold at zero.
  Future<void> hold(WidgetTester tester) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ProgressRing)),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await gesture.up();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// Answers the quiz up to the commit screen and holds the ring out.
  Future<void> holdToCommit(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    container.read(onboardingProvider.notifier).previewStep(ObStep.commit);
    await beat(tester);
    await hold(tester);
  }

  group('a new person', () {
    testWidgets('meets the quiz first, with a way in for an existing account', (
      tester,
    ) async {
      final container = await launch(tester);

      expect(path(container), Routes.onboarding);
      expect(find.byType(WelcomeStep), findsOneWidget);
      expect(find.byType(SignInScreen), findsNothing);

      await tester.tap(find.textContaining(l10n.obWelcomeHaveAccount));
      await beat(tester);
      expect(find.byType(SignInScreen), findsOneWidget);

      // Pushed, so it has somewhere to go back to — and going back is the
      // quiz, untouched.
      await tester.tap(
        find.descendant(
          of: find.byType(SignInScreen),
          matching: find.byType(BackChevron),
        ),
      );
      await beat(tester);
      expect(find.byType(SignInScreen), findsNothing);
      expect(find.byType(WelcomeStep), findsOneWidget);
      expect(step(container), ObStep.welcome);
    });

    testWidgets('is asked for an account after the commit, and carries on '
        'from there once they have one', (tester) async {
      final container = await launch(tester);

      await holdToCommit(tester, container);
      // The commit is held, and the plan has nowhere to live yet.
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(step(container), ObStep.commit);
      expect(container.read(quitStoreProvider), isNull);

      // The test platform reports android, so the identity button is Google;
      // the fake opens a fresh account with no journey.
      await tester.tap(find.text(l10n.authSignInWithGoogle));
      await beat(tester);

      // Not the top of the quiz again, and not the paywall with nobody
      // signed in: the step the commit was on its way to.
      expect(find.byType(SignInScreen), findsNothing);
      expect(path(container), Routes.onboarding);
      expect(step(container), ObStep.notifications);
      expect(find.byType(NotificationsStep), findsOneWidget);
      expect(
        await container.read(quitStoreProvider.notifier).hasSession(),
        isTrue,
      );
    });

    testWidgets('can register by email at that ask and lands in the same place', (
      tester,
    ) async {
      final container = await launch(tester);
      await holdToCommit(tester, container);

      await tester.tap(find.text(l10n.authContinueWithEmail));
      await beat(tester);
      await tester.enterText(find.byType(TextField).at(0), 'new@quitmail.com');
      await tester.enterText(find.byType(TextField).at(1), 'hunter22');
      await tester.tap(find.text(l10n.authCreateAccount));
      await beat(tester);

      expect(path(container), Routes.onboarding);
      expect(step(container), ObStep.notifications);
      // The address goes into the profile the plan is created with.
      expect(container.read(onboardingProvider).email, 'new@quitmail.com');
    });

    testWidgets('lands on the next step with the keyboard still up, and it '
        'does not overflow', (tester) async {
      // The path this exists for: registering opens the keyboard, and the
      // return to the quiz runs before the IME is dismissed — so the step
      // after the commit is laid out in what is left of the screen. It used
      // to be the welcome step that took that hit; now it is notifications.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      final container = await launch(tester);
      await holdToCommit(tester, container);

      await tester.tap(find.text(l10n.authContinueWithEmail));
      await beat(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 840);
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(0), 'new@quitmail.com');
      await tester.enterText(find.byType(TextField).at(1), 'hunter22');
      await tester.ensureVisible(find.text(l10n.authCreateAccount));
      await tester.tap(find.text(l10n.authCreateAccount));
      await beat(tester);

      expect(find.byType(NotificationsStep), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Both ways on are still reachable in a third of a screen.
      await tester.ensureVisible(find.text(l10n.commonMaybeLater));
      expect(find.text(l10n.commonMaybeLater).hitTestable(), findsOneWidget);
    });

    testWidgets('who backs out of the ask is left on a commit that can be '
        'held again, never on a later step', (tester) async {
      final container = await launch(tester);
      await holdToCommit(tester, container);
      expect(find.byType(SignInScreen), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(SignInScreen),
          matching: find.byType(BackChevron),
        ),
      );
      await beat(tester);

      expect(find.byType(SignInScreen), findsNothing);
      expect(step(container), ObStep.commit);
      expect(find.byType(CommitStep), findsOneWidget);

      // The ring is re-armed: holding it out asks again. A finished ring with
      // nothing left to press would be a dead end on a screen with no other
      // control.
      await hold(tester);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(step(container), ObStep.commit);
    });
  });

  group('someone who already has a plan', () {
    testWidgets('logs in from the welcome screen and never sees a question', (
      tester,
    ) async {
      final container = await launch(tester);

      await tester.tap(find.textContaining(l10n.obWelcomeHaveAccount));
      await beat(tester);
      // The email door: sign-in → email → "Already have one? Log in".
      await tester.tap(find.text(l10n.authContinueWithEmail));
      await beat(tester);
      await tester.tap(find.textContaining(l10n.authAlreadyHaveOne));
      await beat(tester);
      await tester.enterText(find.byType(TextField).at(1), 'hunter22');
      await tester.tap(find.text(l10n.authLogIn));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(path(container), Routes.home);
      expect(container.read(quitStoreProvider), isNotNull);
      expect(find.byType(OnboardingFlow), findsNothing);
    });

    testWidgets('who took the quiz again anyway goes Home with the plan they '
        'had, and the new answers are not kept', (tester) async {
      final container = await launch(tester);
      await holdToCommit(tester, container);
      expect(find.byType(SignInScreen), findsOneWidget);

      await tester.tap(find.text(l10n.authContinueWithEmail));
      await beat(tester);
      await tester.tap(find.textContaining(l10n.authAlreadyHaveOne));
      await beat(tester);
      await tester.enterText(find.byType(TextField).at(1), 'hunter22');
      await tester.tap(find.text(l10n.authLogIn));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(path(container), Routes.home);
      // The seeded account's own plan, not one built from the answers typed a
      // minute ago: the demo journey is twelve days in, and a plan made from
      // this quiz would be on day one.
      final journey = container.read(quitStoreProvider)!;
      expect(journey.plan.dayNumber(DateTime.now()), 12);
      // And nothing of the second quiz survives to be offered to the next
      // person who opens it on this phone.
      final draft = container.read(onboardingProvider);
      expect(draft.step, ObStep.welcome);
      expect(draft.committed, isFalse);
      expect(draft.puffsInput, isEmpty);
    });
  });

  group('someone who signed in first', () {
    testWidgets('is not asked a second time at the commit', (tester) async {
      final container = await launch(tester);
      // The only order there was until now: account, then quiz.
      await tester.tap(find.textContaining(l10n.obWelcomeHaveAccount));
      await beat(tester);
      await tester.tap(find.text(l10n.authSignInWithGoogle));
      await beat(tester);
      // A fresh account has no journey, so it is handed back to the quiz —
      // from the top, since nothing has been answered.
      expect(path(container), Routes.onboarding);
      expect(step(container), ObStep.welcome);

      await holdToCommit(tester, container);

      expect(find.byType(SignInScreen), findsNothing);
      expect(step(container), ObStep.notifications);
    });
  });

  group('whether anybody is signed in', () {
    test('follows sign-in and sign-out on the fake backend', () async {
      final container = ProviderContainer(overrides: fastBackendOverrides());
      addTearDown(container.dispose);
      final store = container.read(quitStoreProvider.notifier);

      expect(await store.hasSession(), isFalse);
      await store.signInWithApple();
      expect(await store.hasSession(), isTrue);
      store.signOut();
      expect(await store.hasSession(), isFalse);
    });

    test('counts an account that signed in on an earlier launch and never '
        'finished the quiz', () async {
      // `restoreSession` reports this one as signed out — it has no journey
      // to restore — so the store's own flag never learns about it. Asking it
      // to sign in again would be asking somebody for an account they are
      // already in.
      final container = ProviderContainer(
        overrides: [
          ...fastBackendOverrides(),
          authRepositoryProvider.overrideWithValue(_JourneylessSession()),
        ],
      );
      addTearDown(container.dispose);
      final store = container.read(quitStoreProvider.notifier);

      expect(await store.restoreSession(), isNot(isNull));
      expect(container.read(quitStoreProvider), isNull);
      expect(await store.hasSession(), isTrue);
    });
  });

  group('accountReady', () {
    test('moves a held commit on, and nothing else', () {
      final container = ProviderContainer(overrides: fastBackendOverrides());
      addTearDown(container.dispose);
      final vm = container.read(onboardingProvider.notifier);

      // Signing in before any answers: the quiz starts where it is.
      vm.accountReady();
      expect(container.read(onboardingProvider).step, ObStep.welcome);

      // On the commit screen but not yet held: an account must not skip the
      // one gesture the screen exists for.
      vm.previewStep(ObStep.commit);
      vm.accountReady();
      expect(container.read(onboardingProvider).step, ObStep.commit);

      vm.markCommitted();
      vm.accountReady();
      expect(container.read(onboardingProvider).step, ObStep.notifications);

      // And it is not a general "next": called again it stays put.
      vm.accountReady();
      expect(container.read(onboardingProvider).step, ObStep.notifications);
    });
  });
}

/// A real backend's answer for an account that registered, was signed in, and
/// closed the app before the paywall: a uid, and no journey.
class _JourneylessSession implements AuthRepository {
  @override
  Future<JourneyState?> restoreSession() async => null;

  @override
  Future<String?> currentUserId() async => 'uid-with-no-journey';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
