import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/features/onboarding/onboarding_view_model.dart';

import '../helpers.dart';

/// The 19-step funnel every acquisition number in docs/08 divides through.
///
/// It had no unit coverage at all — only an on-device pass — which left the
/// two things most worth pinning untested: the age gate, which is a legal
/// requirement rather than a preference, and whether the answers a user gives
/// actually reach the journey. The second one has already gone wrong once, on
/// the server side: gender, attempts and frequency were decoded by the app and
/// dropped before they reached Ember.
void main() {
  ProviderContainer container() {
    final c = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(c.dispose);
    return c;
  }

  /// Answers every question with something valid, leaving [step] current.
  OnboardingViewModel filled(ProviderContainer c) {
    final vm = c.read(onboardingProvider.notifier)
      ..selectGender(Gender.woman)
      ..selectAttempts(QuitAttempts.twoToFive)
      ..selectFrequency(VapeFrequency.always)
      ..selectStrength(NicStrength.mg50)
      ..selectFirstPuff(FirstPuffWindow.withinFive)
      ..toggleWhy(WhyChip.health)
      ..toggleWorry(WorryChip.cravings)
      ..selectMethod(QuitMethod.taper)
      ..selectPace(30);
    for (final d in [2, 0, 0]) {
      vm.typePuffDigit(d);
    }
    for (final d in [4, 5]) {
      vm.typeSpendDigit(d);
    }
    return vm;
  }

  group('the age gate', () {
    void typeYear(OnboardingViewModel vm, int year) {
      for (final ch in year.toString().split('')) {
        vm.typeBirthDigit(int.parse(ch));
      }
    }

    test('sends an under-18 to the resource screen, never into the funnel', () {
      final c = container();
      final vm = c.read(onboardingProvider.notifier);
      vm.state = vm.state.copyWith(step: ObStep.birthYear);
      typeYear(vm, DateTime.now().year - 15);

      vm.next();

      expect(c.read(onboardingProvider).step, ObStep.under18);
    });

    test('lets an adult straight through to the next question', () {
      final c = container();
      final vm = c.read(onboardingProvider.notifier);
      vm.state = vm.state.copyWith(step: ObStep.birthYear);
      typeYear(vm, DateTime.now().year - 30);

      vm.next();

      expect(c.read(onboardingProvider).step, ObStep.tried);
    });

    test('blocks exactly at the boundary, not around it', () {
      // 18 is the line docs/02 sets. An off-by-one here is a compliance
      // problem, not a UX one.
      for (final (age, expected) in [
        (17, ObStep.under18),
        (18, ObStep.tried),
      ]) {
        final c = container();
        final vm = c.read(onboardingProvider.notifier);
        vm.state = vm.state.copyWith(step: ObStep.birthYear);
        typeYear(vm, DateTime.now().year - age);
        vm.next();
        expect(
          c.read(onboardingProvider).step,
          expected,
          reason: 'age $age',
        );
      }
    });

    test('going back from `tried` returns to the year, not the gate', () {
      final c = container();
      final vm = c.read(onboardingProvider.notifier);
      vm.state = vm.state.copyWith(step: ObStep.tried);

      expect(vm.back(), isTrue);
      expect(c.read(onboardingProvider).step, ObStep.birthYear);
    });
  });

  group('the continue gate', () {
    test('holds until each question is answered', () {
      final c = container();
      final vm = c.read(onboardingProvider.notifier);

      for (final (step, answer) in <(ObStep, void Function())>[
        (ObStep.gender, () => vm.selectGender(Gender.man)),
        (ObStep.tried, () => vm.selectAttempts(QuitAttempts.never)),
        (ObStep.frequency, () => vm.selectFrequency(VapeFrequency.daily)),
        (ObStep.strength, () => vm.selectStrength(NicStrength.mg20)),
        (ObStep.firstPuff, () => vm.selectFirstPuff(FirstPuffWindow.hourPlus)),
        (ObStep.why, () => vm.toggleWhy(WhyChip.money)),
        (ObStep.worries, () => vm.toggleWorry(WorryChip.stress)),
      ]) {
        vm.state = vm.state.copyWith(step: step);
        expect(vm.state.canContinue, isFalse, reason: '$step before answering');
        answer();
        expect(vm.state.canContinue, isTrue, reason: '$step after answering');
      }
    });

    test('a puff count of zero is not an answer', () {
      // Zero baseline would divide the whole taper curve by nothing.
      final c = container();
      final vm = c.read(onboardingProvider.notifier);
      vm.state = vm.state.copyWith(step: ObStep.puffs);
      expect(vm.state.canContinue, isFalse);

      vm.typePuffDigit(0);
      expect(vm.state.canContinue, isFalse);
      vm.typePuffDigit(5);
      expect(vm.state.canContinue, isTrue);
    });

    test('deselecting the last why closes the gate again', () {
      final c = container();
      final vm = c.read(onboardingProvider.notifier);
      vm.state = vm.state.copyWith(step: ObStep.why);

      vm.toggleWhy(WhyChip.health);
      expect(vm.state.canContinue, isTrue);
      vm.toggleWhy(WhyChip.health);
      expect(vm.state.canContinue, isFalse);
    });

    test('backspace can empty a numeric answer', () {
      final c = container();
      final vm = c.read(onboardingProvider.notifier)
        ..typePuffDigit(1)
        ..typePuffDigit(2);
      vm.state = vm.state.copyWith(step: ObStep.puffs);
      expect(vm.state.canContinue, isTrue);

      vm
        ..backspacePuffs()
        ..backspacePuffs();
      expect(vm.state.canContinue, isFalse);
    });
  });

  group('the answers reach the journey', () {
    test('every quiz answer lands on the profile and the plan', () async {
      // The server reads the journey document itself to build Ember's user
      // card, so anything dropped here is a fact the coach can never know.
      final c = container();
      filled(c);
      await c
          .read(onboardingProvider.notifier)
          .completeWithTier(SubscriptionTier.trial);

      final journey = c.read(quitStoreProvider)!;
      expect(journey.profile.gender, Gender.woman);
      expect(journey.profile.attempts, QuitAttempts.twoToFive);
      expect(journey.profile.frequency, VapeFrequency.always);
      expect(journey.profile.firstPuff, FirstPuffWindow.withinFive);
      expect(journey.profile.whys, contains(WhyChip.health));
      expect(journey.profile.worries, contains(WorryChip.cravings));
      expect(journey.profile.tier, SubscriptionTier.trial);

      expect(journey.plan.baselinePuffsPerDay, 200);
      expect(journey.plan.weeklySpend, 45);
      expect(journey.plan.strength, NicStrength.mg50);
      expect(journey.plan.method, QuitMethod.taper);
      expect(journey.plan.paceDays, 30);
    });

    test('the journey starts today, on day one', () async {
      final c = container();
      filled(c);
      await c
          .read(onboardingProvider.notifier)
          .completeWithTier(SubscriptionTier.trial);

      final journey = c.read(quitStoreProvider)!;
      expect(journey.plan.dayNumber(DateTime.now()), 1);
      // Day one exists with its limit already set and nothing logged against
      // it: the curve has to be readable before the first puff, or Home has
      // no line to draw on the very screen that decides whether they stay.
      expect(journey.days, hasLength(1));
      final today = journey.logFor(DateTime.now())!;
      expect(today.puffs, 0);
      // The engine's number, not the raw baseline — day one is already a step
      // down the curve. Asserting the exact figure here would just duplicate
      // `taper_engine_test.dart`; what matters is that the stored day agrees
      // with the engine the Home screen renders from.
      expect(today.limit, journey.limitOn(DateTime.now()));
      expect(today.limit, lessThan(journey.plan.baselinePuffsPerDay));
    });

    test('a new account is minted with nothing invented in it', () async {
      // `InitialJourney` used to mint a savings goal ("Tokyo flight") and a
      // buddy for every real account, and the Money screen then showed
      // progress toward a stranger's holiday.
      final c = container();
      filled(c);
      await c
          .read(onboardingProvider.notifier)
          .completeWithTier(SubscriptionTier.free);

      final journey = c.read(quitStoreProvider)!;
      expect(journey.goals, isEmpty);
      expect(journey.earnedBadges, isEmpty);
      expect(journey.cravingsSurvivedTotal, 0);
      expect(journey.day1TasksDone, isEmpty);
    });

    test('the draft is cleared so a second run starts clean', () async {
      final c = container();
      filled(c);
      await c
          .read(onboardingProvider.notifier)
          .completeWithTier(SubscriptionTier.trial);

      expect(c.read(onboardingProvider).step, ObStep.welcome);
      expect(c.read(onboardingProvider).gender, isNull);
    });
  });
}
