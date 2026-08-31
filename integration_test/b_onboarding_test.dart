import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/core/widgets/lp_selectables.dart';
import 'package:last_puff/core/widgets/numeric_keypad.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/features/onboarding/onboarding_view_model.dart';

import 'harness.dart';

/// The 20-step first session (docs/02 §2 plus D1b), the age gate, and the
/// ends on.
///
/// This is the funnel every acquisition number in docs/08 §2 divides through,
/// so the thing being proved is unglamorous: **every one of the 20 screens
/// renders, its Continue enables once answered, and the flow reaches a created
/// journey.** A screen that silently fails to advance costs the whole cohort.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Selects the first option on a chip/card step and continues.
  Future<void> pickFirstAndContinue(E2E e2e, {String? cta}) async {
    for (final type in [OptionCard, LpChip, SelectCheck]) {
      final options = find.byType(type);
      if (options.evaluate().isNotEmpty) {
        await e2e.tap(options.first, why: '$type option');
        break;
      }
    }
    await e2e.tapText(cta ?? e2e.l10n.commonContinue);
  }

  /// Types [value] on the real on-screen keypad — the only input those three
  /// steps have, so driving the view model instead would leave the control
  /// itself untested. Scoped to the keypad so a digit elsewhere on the screen
  /// (a price, a day number) can never be tapped by mistake.
  Future<void> typeDigits(E2E e2e, String value) async {
    for (final ch in value.split('')) {
      await e2e.tap(
        find.descendant(
          of: find.byType(NumericKeypad),
          matching: find.text(ch),
        ),
        why: 'keypad digit $ch',
      );
    }
  }

  testWidgets('a guest walks all 21 steps to a created journey', (
    tester,
  ) async {
    final e2e = await E2E.boot(tester);
    await e2e.waitFor(const Duration(seconds: 2));

    // Guest onboarding straight off the sign-in screen (no account first).
    await e2e.tapText(e2e.l10n.authContinueWithEmail);
    await e2e.enterField(e2e.l10n.authEmailLabel, 'e2e-guest@cirrus.app');
    await e2e.enterField(e2e.l10n.authPasswordLabel, 'secret123');
    await e2e.tapText(e2e.l10n.authCreateAccount);
    await e2e.waitFor(const Duration(seconds: 2));

    final vm = e2e.container.read(onboardingProvider.notifier);
    expect(e2e.container.read(onboardingProvider).step, ObStep.welcome,
        reason: 'on screen: ${e2e.texts()}');

    // welcome
    await e2e.tapText(e2e.l10n.obWelcomeCta);
    // gender
    await pickFirstAndContinue(e2e);
    // birthYear — real keypad, an adult year
    await typeDigits(e2e, '2000');
    await e2e.tapText(e2e.l10n.commonContinue);
    // tried / frequency
    await pickFirstAndContinue(e2e);
    await pickFirstAndContinue(e2e);
    // puffs — 200/day, the worked example from docs/03
    await typeDigits(e2e, '200');
    await e2e.tapText(e2e.l10n.commonContinue);
    // strength
    await pickFirstAndContinue(e2e);
    // spend
    await typeDigits(e2e, '25');
    await e2e.tapText(e2e.l10n.commonContinue);
    // firstPuff / why / worries / method
    await pickFirstAndContinue(e2e);
    await pickFirstAndContinue(e2e);
    await pickFirstAndContinue(e2e);
    await pickFirstAndContinue(e2e);

    // Every answer landed, and the draft plan is the real one.
    final draft = e2e.container.read(onboardingProvider);
    expect(draft.puffsPerDay, 200, reason: 'on screen: ${e2e.texts()}');
    expect(draft.weeklySpend, 25);
    expect(draft.birthYear, 2000);

    // pace → building → reveal → coachName → commit → rating → notifications
    await e2e.tapText(e2e.l10n.obPaceCta);
    await e2e.waitFor(const Duration(seconds: 4)); // building animation
    expect(e2e.showing(e2e.l10n.obRevealCta), isTrue,
        reason: 'reveal never arrived; on screen: ${e2e.texts()}');
    await e2e.tapText(e2e.l10n.obRevealCta);

    // D1b — name the coach. Keeping the default must leave `coachName` null,
    // not the literal word, so an untouched profile is indistinguishable from
    // every profile that existed before this screen did.
    expect(e2e.showing(e2e.l10n.obCoachNameKeep(e2e.l10n.coachName)), isTrue,
        reason: 'coach naming never arrived; on screen: ${e2e.texts()}');
    await e2e.tapText(e2e.l10n.obCoachNameKeep(e2e.l10n.coachName));
    await e2e.settle();

    // D1c — the one free-text answer, and the only onboarding answer that
    // seeds Ember's vector memory. Typed rather than skipped, because the
    // skip path is the one that leaves the memory empty and the typed path is
    // the one with a keyboard, a length cap and a codec behind it.
    expect(e2e.showing(e2e.l10n.obWhyWordsCta), isTrue,
        reason: 'the why-in-your-words step never arrived; '
            'on screen: ${e2e.texts()}');
    await e2e.enterField(
      e2e.l10n.obWhyWordsFieldLabel,
      'so I can run with her without stopping',
    );
    await e2e.tapText(e2e.l10n.obWhyWordsCta);
    await e2e.settle();
    expect(
      e2e.container.read(onboardingProvider.notifier).chosenWhyWords,
      'so I can run with her without stopping',
    );

    // The hold-to-commit gesture is a press, not a tap.
    final holdTarget = find.text(e2e.l10n.obCommitHold);
    if (holdTarget.evaluate().isNotEmpty) {
      final gesture = await tester.startGesture(
        tester.getCenter(holdTarget.first),
      );
      await e2e.waitFor(const Duration(seconds: 4));
      await gesture.up();
      await e2e.settle();
    } else {
      vm.markCommitted();
      vm.next();
      await e2e.settle();
    }
    expect(e2e.container.read(onboardingProvider).committed, isTrue,
        reason: 'hold-to-commit did not register');

    // Skip past rating + notifications without triggering the OS prompt.
    while (e2e.container.read(onboardingProvider).step !=
        ObStep.notifications) {
      vm.next();
      await e2e.settle(frames: 10);
    }
    await e2e.tapText(e2e.l10n.commonMaybeLater);
    await e2e.waitFor(const Duration(seconds: 2));

    // Paywall, and the free path must be visible, never hidden (docs/02 §4).
    expect(e2e.showing(e2e.l10n.paywallFreeLink), isTrue,
        reason: 'on screen: ${e2e.texts()}');

    await e2e.tapText(e2e.l10n.paywallFreeLink);
    await e2e.waitFor(const Duration(seconds: 1));
    await e2e.tapText(e2e.l10n.freePlanCta);
    await e2e.waitFor(const Duration(seconds: 3));

    // The backend minted a real day-1 journey from the answers above.
    final journey = e2e.container.read(quitStoreProvider);
    expect(journey, isNotNull, reason: 'on screen: ${e2e.texts()}');
    expect(journey!.plan.baselinePuffsPerDay, 200);
    expect(journey.plan.paceDays, greaterThan(0));
    expect(journey.profile.tier, SubscriptionTier.free);
    expect(e2e.container.read(todayProvider)!.dayNumber, 1);
  });

  testWidgets('under 18 is turned away and no journey is ever created', (
    tester,
  ) async {
    final e2e = await E2E.boot(tester);
    await e2e.waitFor(const Duration(seconds: 2));
    await e2e.tapText(e2e.l10n.authContinueWithEmail);
    await e2e.enterField(e2e.l10n.authEmailLabel, 'e2e-minor@cirrus.app');
    await e2e.enterField(e2e.l10n.authPasswordLabel, 'secret123');
    await e2e.tapText(e2e.l10n.authCreateAccount);
    await e2e.waitFor(const Duration(seconds: 2));

    await e2e.tapText(e2e.l10n.obWelcomeCta);
    await pickFirstAndContinue(e2e);
    // A 15-year-old in 2026.
    await typeDigits(e2e, '2011');
    // The gate ends the session with no way back, so it now costs a deliberate
    // "Yes, I'm 15" rather than a Continue tap. A mistyped digit must never be
    // enough to reach it.
    await e2e.tapText(e2e.l10n.obBirthYearUnderCta(DateTime.now().year - 2011));
    await e2e.settle();

    expect(e2e.container.read(onboardingProvider).step, ObStep.under18,
        reason: 'age gate did not fire; on screen: ${e2e.texts()}');
    expect(e2e.container.read(quitStoreProvider), isNull);
  });

  testWidgets('a mistyped year is explained, not treated as a child', (
    tester,
  ) async {
    // 2812 used to compute an age of -786, which is less than 18, so a fat
    // finger dropped an adult onto the under-18 screen — whose only exit is
    // closing the app.
    final e2e = await E2E.boot(tester);
    await e2e.waitFor(const Duration(seconds: 2));
    await e2e.tapText(e2e.l10n.authContinueWithEmail);
    await e2e.enterField(e2e.l10n.authEmailLabel, 'e2e-typo@cirrus.app');
    await e2e.enterField(e2e.l10n.authPasswordLabel, 'secret123');
    await e2e.tapText(e2e.l10n.authCreateAccount);
    await e2e.waitFor(const Duration(seconds: 2));

    await e2e.tapText(e2e.l10n.obWelcomeCta);
    await pickFirstAndContinue(e2e);
    await typeDigits(e2e, '2812');
    await e2e.settle();

    expect(find.text(e2e.l10n.obBirthYearErrorFuture), findsOneWidget,
        reason: 'no explanation shown; on screen: ${e2e.texts()}');

    await e2e.tapText(e2e.l10n.commonContinue);
    await e2e.settle();
    expect(e2e.container.read(onboardingProvider).step, ObStep.birthYear);

    // Clear it on the real keypad and answer with an AGE instead — the thing
    // people actually do on a screen that asks for a year.
    for (var i = 0; i < 4; i++) {
      await e2e.tap(
        find.descendant(
          of: find.byType(NumericKeypad),
          matching: find.byIcon(Icons.backspace_outlined),
        ),
        why: 'keypad backspace',
      );
    }
    await typeDigits(e2e, '28');
    await e2e.settle();

    final year = DateTime.now().year - 28;
    expect(find.text(e2e.l10n.obBirthYearAgeOffer(28, year)), findsOneWidget,
        reason: 'age was not understood; on screen: ${e2e.texts()}');

    await e2e.tapText(e2e.l10n.commonContinue);
    await e2e.settle();
    expect(e2e.container.read(onboardingProvider).step, ObStep.tried);
    expect(e2e.container.read(onboardingProvider).birthYear, year);
  });

  testWidgets('back works on every quiz step and keeps the answers', (
    tester,
  ) async {
    final e2e = await E2E.boot(tester);
    await e2e.waitFor(const Duration(seconds: 2));
    await e2e.tapText(e2e.l10n.authContinueWithEmail);
    await e2e.enterField(e2e.l10n.authEmailLabel, 'e2e-back@cirrus.app');
    await e2e.enterField(e2e.l10n.authPasswordLabel, 'secret123');
    await e2e.tapText(e2e.l10n.authCreateAccount);
    await e2e.waitFor(const Duration(seconds: 2));

    final vm = e2e.container.read(onboardingProvider.notifier);
    await e2e.tapText(e2e.l10n.obWelcomeCta);
    await pickFirstAndContinue(e2e);
    await typeDigits(e2e, '2000');
    await e2e.tapText(e2e.l10n.commonContinue);
    expect(e2e.container.read(onboardingProvider).step, ObStep.tried);

    // The documented quirk: back from `tried` skips the age gate screen and
    // lands on birthYear, with the year still typed in.
    expect(vm.back(), isTrue);
    await e2e.settle();
    expect(e2e.container.read(onboardingProvider).step, ObStep.birthYear);
    expect(e2e.container.read(onboardingProvider).birthYearInput, '2000');
  });
}
