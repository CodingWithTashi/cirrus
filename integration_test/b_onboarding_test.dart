import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/core/widgets/lp_selectables.dart';
import 'package:last_puff/core/widgets/numeric_keypad.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/features/onboarding/onboarding_view_model.dart';

import 'harness.dart';

/// The 19-step first session (docs/02 §2), the age gate, and the paywall it
/// ends on.
///
/// This is the funnel every acquisition number in docs/08 §2 divides through,
/// so the thing being proved is unglamorous: **every one of the 19 screens
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

  testWidgets('a guest walks all 19 steps to a created journey', (
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

    // pace → building → reveal → commit → rating → notifications
    await e2e.tapText(e2e.l10n.obPaceCta);
    await e2e.waitFor(const Duration(seconds: 4)); // building animation
    expect(e2e.showing(e2e.l10n.obRevealCta), isTrue,
        reason: 'reveal never arrived; on screen: ${e2e.texts()}');
    await e2e.tapText(e2e.l10n.obRevealCta);

    // The hold-to-commit gesture is a 3s press, not a tap.
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
    await e2e.tapText(e2e.l10n.commonContinue);
    await e2e.settle();

    expect(e2e.container.read(onboardingProvider).step, ObStep.under18,
        reason: 'age gate did not fire; on screen: ${e2e.texts()}');
    expect(e2e.container.read(quitStoreProvider), isNull);
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
