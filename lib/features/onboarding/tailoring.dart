import 'package:flutter/widgets.dart';

import '../../core/utils/enum_labels.dart';
import '../../core/utils/l10n_ext.dart';
import '../../domain/logic/dependence_engine.dart';
import '../../domain/logic/spend_comparisons.dart';
import '../../domain/models/models.dart';
import 'onboarding_view_model.dart';
import 'steps/step_fact.dart';

/// Everything the funnel says differently because of what the user already
/// told us. One file, on purpose — the alternative is a conditional in each of
/// five step files and no single place to read the policy off.
///
/// ## The rule
///
/// Tailoring may use only a fact the user typed on purpose, and may say only
/// something they would recognise as their own. It never infers a preference
/// from a demographic. [SpendItem.audience] selects between items **equally
/// true for everyone** that differ in *price* — never in taste, role, or body.
/// If an item would embarrass us shown to the other two gender answers, it does
/// not belong in the catalogue at all. [Gender.nonBinary] is labelled
/// "Non-binary / prefer not to say", so it resolves to universal items only —
/// never to a guess, and never to a "neutral-ish" third bucket, which is a
/// guess wearing a hat. Today every item ships universal; see the note on
/// [SpendItem.audience] for why.
///
/// Copy never sees the raw age either — only the age bands the catalogue
/// filters on — so nothing can address someone by the number they gave for a
/// legal gate.
abstract final class ObTailoring {
  /// The micro-fact under [step], or null when that step has nothing sourced
  /// to say.
  ///
  /// Exhaustive over every [ObStep] on purpose, mirroring
  /// `OnboardingViewModel._completeStep`: adding a step forces a decision here
  /// rather than silently shipping an unconsidered screen.
  static (String, StepFactTone)? fact(
    BuildContext context,
    ObStep step,
    OnboardingState s,
  ) {
    final l10n = context.l10n;
    return switch (step) {
      // docs/02 §8, JAMA Network Open. Only for someone who has tried before —
      // telling a first-timer that quitting got harder is discouragement, not
      // information.
      ObStep.tried =>
        s.attempts != null && s.attempts != QuitAttempts.never
            ? (l10n.obFactTried, StepFactTone.science)
            : null,

      // Their own arithmetic, so it is honest by construction. Needs both
      // halves of the multiplication.
      ObStep.strength =>
        s.strength != null && s.puffsPerDay > 0
            ? (
                l10n.obFactStrength(
                  DependenceEngine.nicotineMg(
                    s.puffsPerDay,
                    s.strength!,
                  ).round(),
                ),
                StepFactTone.yourNumbers,
              )
            : null,

      // Answer the fear they actually named. Cravings first because it is the
      // one the panic button was built for; social second. Everything else has
      // no approved statistic behind it, so it gets silence.
      ObStep.worries => switch (s.worries) {
        final w when w.contains(WorryChip.cravings) => (
          l10n.obFactWorryCravings,
          StepFactTone.science,
        ),
        final w when w.contains(WorryChip.social) => (
          l10n.obFactWorrySocial,
          StepFactTone.science,
        ),
        _ => null,
      },

      // docs/02 §8, Truth Initiative. Unconditional: the question itself is
      // the Fagerström dependence item, so the finding always applies.
      ObStep.firstPuff => (l10n.obFirstPuffScience, StepFactTone.science),

      // Steps with nothing sourced to add. Listed rather than defaulted so a
      // new step cannot slip through unconsidered.
      ObStep.welcome ||
      ObStep.gender ||
      ObStep.birthYear ||
      ObStep.under18 ||
      ObStep.frequency ||
      ObStep.puffs ||
      ObStep.spend ||
      ObStep.why ||
      ObStep.method ||
      ObStep.pace ||
      ObStep.building ||
      ObStep.reveal ||
      ObStep.coachName ||
      // Deliberately nothing: the screen asks for the user's own sentence,
      // and putting one of our facts under it would answer the question for
      // them.
      ObStep.whyWords ||
      ObStep.commit ||
      ObStep.rating ||
      ObStep.notifications => null,
    };
  }

  /// B4's "what that actually buys you", or null when nothing in the catalogue
  /// divides into their yearly spend.
  ///
  /// The why chips are still unanswered here (that screen is two later), so
  /// this draws on the universal and age-banded items. [revealComparison] runs
  /// the full personalised catalogue against a different figure, so the two
  /// screens never repeat each other.
  static String? spendComparison(BuildContext context, OnboardingState s) =>
      _sentence(
        context,
        SpendComparisons.best(
          amount: s.yearlySpend,
          gender: s.gender,
          age: s.birthEntry.age,
          whys: s.whys,
        ),
        one: context.l10n.obSpendComparisonOne,
        two: context.l10n.obSpendComparisonTwo,
        many: context.l10n.obSpendComparisonMany,
      );

  /// D1's "and by Freedom Day", against the projected saving rather than the
  /// yearly spend — a different number, so a different item.
  static String? revealComparison(
    BuildContext context,
    OnboardingState s,
    double projectedSaved,
  ) => _sentence(
    context,
    SpendComparisons.best(
      amount: projectedSaved,
      gender: s.gender,
      age: s.birthEntry.age,
      whys: s.whys,
    ),
    one: context.l10n.obRevealComparisonOne,
    two: context.l10n.obRevealComparisonTwo,
    many: context.l10n.obRevealComparisonMany,
  );

  /// Three flat frames and a switch rather than one nested ICU plural: the
  /// one-item case differs in sentence *structure*, not in a number, and this
  /// repo has three simple plurals and no nesting anywhere.
  static String? _sentence(
    BuildContext context,
    SpendComparisonMatch? match, {
    required String Function(String) one,
    required String Function(String) two,
    required String Function(String, int) many,
  }) {
    if (match == null) return null;
    final item = match.item.label(context);
    return switch (match.multiple) {
      1 => one(item),
      2 => two(item),
      final n => many(item, n),
    };
  }
}
