import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/lp_colors.dart';
import '../../../app/theme/lp_typography.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/widgets/lp_buttons.dart';
import '../../../core/widgets/lp_card.dart';
import '../../../core/widgets/lp_misc.dart';
import '../../../domain/logic/why_words.dart';
import '../../../domain/models/enums.dart';
import '../onboarding_view_model.dart';
import 'step_body.dart';

/// D1c — the one question in nineteen screens answered in the user's own
/// words.
///
/// Everything else in the funnel is a chip or an enum, which is why Ember's
/// long-term memory started empty for every account and stayed empty until
/// somebody happened to type something into the coach. Those chips already
/// reach the model exactly and for free through the deterministic user card;
/// what the vector layer is FOR is the half a person only ever says out loud
/// (`functions/src/lib/memories.ts`). This screen is where they get the
/// chance to say it.
///
/// Placed straight after naming the coach, so the sequence reads: name it,
/// tell it one thing, then commit. Like every Phase D screen it sits outside
/// the twelve-question progress bar, so adding it renumbers nothing.
///
/// **Genuinely optional.** The skip is a real skip — it stores null, not an
/// empty string, and nothing downstream pretends an answer was given.
class WhyWordsStep extends ConsumerStatefulWidget {
  const WhyWordsStep({super.key});

  @override
  ConsumerState<WhyWordsStep> createState() => _WhyWordsStepState();
}

class _WhyWordsStepState extends ConsumerState<WhyWordsStep> {
  late final TextEditingController _field = TextEditingController(
    text: ref.read(onboardingProvider).whyWordsInput,
  );

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final state = ref.watch(onboardingProvider);
    final vm = ref.read(onboardingProvider.notifier);
    final coachName = state.coachNameInput.trim().isEmpty
        ? l10n.coachName
        : state.coachNameInput.trim();
    final tooLong = WhyWords.validate(state.whyWordsInput) != null;
    final answered = vm.chosenWhyWords != null;
    // The placeholder echoes a why they picked two screens ago, so the
    // example reads as a continuation of their own answers (docs/09 issue 2).
    final hint = switch (WhyWords.hintFor(state.whys)) {
      WhyChip.health => l10n.obWhyWordsHintHealth,
      WhyChip.money => l10n.obWhyWordsHintMoney,
      WhyChip.freedom => l10n.obWhyWordsHintFreedom,
      WhyChip.family => l10n.obWhyWordsHintFamily,
      WhyChip.fitness => l10n.obWhyWordsHintFitness,
      WhyChip.appearance => l10n.obWhyWordsHintAppearance,
    };

    return StepBody(
      title: l10n.obWhyWordsTitle(coachName),
      subtitle: l10n.obWhyWordsSubtitle,
      children: [
        LpField(
          label: l10n.obWhyWordsFieldLabel,
          controller: _field,
          hint: hint,
          // Room for two sentences without a scrollbar appearing mid-thought.
          maxLines: 3,
          // The counter is the honest way to show a limit: a field that
          // silently stops accepting characters reads as a broken keyboard.
          maxLength: WhyWords.maxLength,
          onChanged: vm.typeWhyWords,
        ),
        SizedBox(
          height: 22,
          child: tooLong
              ? Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    l10n.obWhyWordsErrorLong,
                    style: LpType.caption(lp.cautionText),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 4),
        LpNoteCard(l10n.obWhyWordsNote(coachName)),
        const Spacer(),
        LpButton(
          l10n.obWhyWordsCta,
          // Nothing typed is not an error, it is a skip — so the primary CTA
          // stays live and simply carries no answer.
          onTap: tooLong ? null : vm.next,
        ),
        const SizedBox(height: 4),
        // Hidden once they have written something: offering to discard what
        // is on screen is a different, worse button. EXCEPT while the text is
        // over the limit — there the CTA above is disabled too, and a screen
        // whose every button is gone can only be escaped by deleting
        // characters, which nothing on it explains.
        SizedBox(
          height: 44,
          child: answered && !tooLong
              ? null
              : LpTextButton(l10n.obWhyWordsSkip, onTap: vm.next),
        ),
      ],
    );
  }
}
