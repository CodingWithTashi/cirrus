import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/core/widgets/lp_buttons.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/features/onboarding/onboarding_flow.dart';
import 'package:last_puff/features/onboarding/onboarding_view_model.dart';
import 'package:last_puff/features/onboarding/steps/step_fact.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// What the funnel says differently because of what the user already told it.
///
/// The unit suites pin the engines; this pins that the words reach the screen —
/// which is the half that has silently broken before (a coach reply whose text
/// was decoded and then never rendered).
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  /// Mounts the flow with the draft already arranged by [arrange], so the very
  /// first build sees the state under test. That matters for [StepFact], which
  /// keeps its last words while fading out — asserting "no fact" only means
  /// anything on a screen that never had one.
  Future<ProviderContainer> pump(
    WidgetTester tester,
    void Function(OnboardingViewModel vm) arrange,
  ) async {
    final container = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(container.dispose);
    arrange(container.read(onboardingProvider.notifier));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: LpTheme.midnight(),
          home: const OnboardingFlow(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    return container;
  }

  group('the birth-year step explains itself', () {
    testWidgets('a mistyped future year says so and holds the CTA', (
      tester,
    ) async {
      await pump(tester, (vm) {
        vm.previewStep(ObStep.birthYear);
        vm.clearBirthYear();
        for (final d in [2, 8, 1, 2]) {
          vm.typeBirthDigit(d);
        }
      });

      expect(find.text(l10n.obBirthYearErrorFuture), findsOneWidget);
      final cta = tester.widget<LpButton>(
        find.widgetWithText(LpButton, l10n.commonContinue),
      );
      expect(cta.onTap, isNull, reason: 'a future year must not advance');
    });

    testWidgets('an age is read back as the year it implies', (tester) async {
      await pump(tester, (vm) {
        vm.previewStep(ObStep.birthYear);
        vm.clearBirthYear();
        for (final d in [2, 8]) {
          vm.typeBirthDigit(d);
        }
      });

      final year = DateTime.now().year - 28;
      expect(find.text(l10n.obBirthYearAgeOffer(28, year)), findsOneWidget);
      expect(find.text(l10n.obBirthYearAgeConfirm), findsOneWidget);
    });

    testWidgets('an under-18 answer costs a deliberate confirmation', (
      tester,
    ) async {
      final under = DateTime.now().year - 15;
      await pump(tester, (vm) {
        vm.previewStep(ObStep.birthYear);
        vm.clearBirthYear();
        for (final ch in under.toString().split('')) {
          vm.typeBirthDigit(int.parse(ch));
        }
      });

      // The gate ends the session with no way back, so plain "Continue" must
      // not be what reaches it.
      expect(find.text(l10n.obBirthYearUnderCta(15)), findsOneWidget);
      expect(find.text(l10n.obBirthYearFix), findsOneWidget);
      expect(find.text(l10n.commonContinue), findsNothing);
    });
  });

  group('the spend step names something real', () {
    testWidgets('shows a comparison drawn from their own answers', (
      tester,
    ) async {
      // The preview draft is $25/week and a fitness why, so $1,300 a year.
      await pump(tester, (vm) => vm.previewStep(ObStep.spend));

      expect(
        find.text(l10n.obSpendComparisonMany(l10n.obSpendItemRunningShoes, 8)),
        findsOneWidget,
        reason: 'the fitness why should pull in a fitness item at this amount',
      );
    });

    testWidgets('the retired one-size-fits-all kickers are gone', (
      tester,
    ) async {
      await pump(tester, (vm) => vm.previewStep(ObStep.spend));

      for (final dead in [
        "That's a new phone. Every year.",
        "That's a flight to Tokyo. Every year.",
        "That's rent money. Every single year.",
      ]) {
        expect(find.text(dead), findsNothing, reason: dead);
      }
    });
  });

  group('the rating ask is honest and tailored', () {
    testWidgets('falls back to the bundled quotes with nothing from the server',
        (tester) async {
      await pump(tester, (vm) => vm.previewStep(ObStep.rating));

      expect(find.text(l10n.obRatingQuote1), findsOneWidget);
      expect(find.text(l10n.obRatingQuote2), findsOneWidget);
    });

    testWidgets('shows the tailored pair when the server answered', (
      tester,
    ) async {
      await pump(tester, (vm) {
        vm.previewStep(ObStep.rating);
        vm.state = vm.state.copyWith(
          testimonials: const [
            Testimonial(id: 'a', text: 'Day 4 and the fog lifted.'),
            Testimonial(id: 'b', text: 'I stopped counting hours.'),
          ],
        );
      });

      expect(find.text('Day 4 and the fog lifted.'), findsOneWidget);
      expect(find.text(l10n.obRatingQuote1), findsNothing);
    });

    testWidgets('offers no rating control when no sheet is coming', (
      tester,
    ) async {
      // No Play Store on the device, desktop, or a test. (A sideloaded build
      // is no longer this case: it gets the listing instead of the sheet.)
      // A dead button is worse than none.
      await pump(tester, (vm) => vm.previewStep(ObStep.rating));

      expect(find.text(l10n.obRatingCta), findsNothing);
      expect(find.text(l10n.commonContinue), findsOneWidget);
    });

    testWidgets('asks once, plainly, when the OS will show its sheet', (
      tester,
    ) async {
      await pump(tester, (vm) {
        vm.previewStep(ObStep.rating);
        vm.state = vm.state.copyWith(reviewAvailable: true);
      });

      expect(find.text(l10n.obRatingCta), findsOneWidget);
      // Review gating is prohibited on both stores, so there is no star
      // picker: the only stars on this screen belong to the quotes, and the
      // retired card copy must not come back with one.
      expect(find.text(l10n.commonNotNow), findsOneWidget);
    });
  });

  group('naming the coach', () {
    testWidgets('offers the default without forcing a choice', (tester) async {
      await pump(tester, (vm) => vm.previewStep(ObStep.coachName));

      expect(find.text(l10n.obCoachNameTitle), findsOneWidget);
      expect(find.text(l10n.obCoachNameKeep('Ember')), findsOneWidget);
      // Four borrowable names, as ARB keys so a locale can swap an
      // unfortunate word.
      expect(find.text(l10n.obCoachNameSuggestion1), findsOneWidget);
      expect(find.text(l10n.obCoachNameSuggestion4), findsOneWidget);
    });

    testWidgets('a typed name changes the CTA and clears no error', (
      tester,
    ) async {
      final c = await pump(tester, (vm) => vm.previewStep(ObStep.coachName));
      c.read(onboardingProvider.notifier).typeCoachName('Wren');
      await tester.pump();

      expect(find.text(l10n.obCoachNameCta), findsOneWidget);
      expect(find.text(l10n.obCoachNameErrorChars), findsNothing);
    });

    testWidgets('an unusable name is explained and holds the CTA', (
      tester,
    ) async {
      final c = await pump(tester, (vm) => vm.previewStep(ObStep.coachName));
      // The chat header cannot lay out an emoji.
      c.read(onboardingProvider.notifier).typeCoachName('🔥🔥');
      await tester.pump();

      expect(find.text(l10n.obCoachNameErrorChars), findsOneWidget);
      final cta = tester.widget<LpButton>(
        find.widgetWithText(LpButton, l10n.obCoachNameCta),
      );
      expect(cta.onTap, isNull);
    });

    testWidgets('keeping the default leaves the profile name null', (
      tester,
    ) async {
      final c = await pump(tester, (vm) => vm.previewStep(ObStep.coachName));
      final vm = c.read(onboardingProvider.notifier);

      // Null, never the literal word: the default is an ARB string, so an
      // untouched profile is identical to every profile that predates this
      // screen and needs no migration.
      expect(vm.chosenCoachName, isNull);

      vm.typeCoachName('  Wren  ');
      expect(vm.chosenCoachName, 'Wren');
    });
  });

  group('the why-words placeholder is theirs', () {
    testWidgets('echoes a why they picked', (tester) async {
      // The preview draft picked health, money and fitness; fitness is the
      // most personal of those, so the running line is the one that shows.
      await pump(tester, (vm) => vm.previewStep(ObStep.whyWords));

      expect(find.text(l10n.obWhyWordsHintFitness), findsOneWidget);
      expect(find.text(l10n.obWhyWordsHintHealth), findsNothing);
      expect(find.text(l10n.obWhyWordsHintMoney), findsNothing);
    });

    testWidgets('a more personal why takes over when it is added', (
      tester,
    ) async {
      await pump(tester, (vm) {
        vm.previewStep(ObStep.whyWords);
        vm.toggleWhy(WhyChip.family);
      });

      expect(find.text(l10n.obWhyWordsHintFamily), findsOneWidget);
      expect(find.text(l10n.obWhyWordsHintFitness), findsNothing);
    });
  });

  group('facts appear only where one is sourced', () {
    testWidgets('the fear they named gets the finding that answers it', (
      tester,
    ) async {
      // The preview draft worries about cravings.
      await pump(tester, (vm) => vm.previewStep(ObStep.worries));

      expect(find.text(l10n.obFactWorryCravings), findsOneWidget);
    });

    testWidgets('a worry with no approved statistic behind it stays quiet', (
      tester,
    ) async {
      await pump(tester, (vm) {
        vm.previewStep(ObStep.worries);
        // Leave only the worry docs/02 §8 has nothing to say about. Inventing
        // a statistic here is the one thing §8 bans outright.
        for (final w in [
          WorryChip.cravings,
          WorryChip.stress,
          WorryChip.failing,
        ]) {
          vm.toggleWorry(w);
        }
        vm.toggleWorry(WorryChip.weight);
      });

      expect(find.byType(StepFact), findsOneWidget);
      expect(find.text(l10n.obFactWorryCravings), findsNothing);
      expect(find.text(l10n.obFactWorrySocial), findsNothing);
    });

    testWidgets('the strength step does the user\'s own multiplication', (
      tester,
    ) async {
      // 200 puffs at 50 mg/mL — the preview draft's numbers.
      await pump(tester, (vm) => vm.previewStep(ObStep.strength));

      expect(find.text(l10n.obFactLabelYourNumbers), findsOneWidget);
      expect(find.text(l10n.obFactStrength(140)), findsOneWidget);
    });
  });
}
