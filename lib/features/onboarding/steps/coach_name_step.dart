import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/lp_colors.dart';
import '../../../app/theme/lp_typography.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/widgets/lp_buttons.dart';
import '../../../core/widgets/lp_card.dart';
import '../../../core/widgets/lp_misc.dart';
import '../../../core/widgets/lp_selectables.dart';
import '../../../data/stores/providers.dart';
import '../../../domain/logic/coach_name.dart';
import '../onboarding_view_model.dart';
import 'step_body.dart';

/// D1b — meet the coach, and name it yourself if you'd rather.
///
/// Sits between the plan reveal and the commitment: here is your plan, here is
/// who is coming with you, now commit. It is deliberately NOT counted by the
/// progress bar — that bar counts the twelve quiz questions, and every Phase D
/// screen is already outside it, so adding this one would renumber all twelve
/// for no gain.
class CoachNameStep extends ConsumerStatefulWidget {
  const CoachNameStep({super.key});

  @override
  ConsumerState<CoachNameStep> createState() => _CoachNameStepState();
}

class _CoachNameStepState extends ConsumerState<CoachNameStep> {
  late final TextEditingController _field = TextEditingController(
    text: ref.read(onboardingProvider).coachNameInput,
  );

  /// Set only by a server refusal. The client validator explains itself; the
  /// server one deliberately does not.
  bool _rejected = false;
  bool _busy = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  String _errorFor(String raw, AppLocalizations l10n) => switch (CoachName
      .validate(raw)) {
    CoachNameError.empty => l10n.obCoachNameErrorEmpty,
    CoachNameError.tooLong => l10n.obCoachNameErrorLong,
    CoachNameError.badCharacters => l10n.obCoachNameErrorChars,
    null => _rejected ? l10n.obCoachNameErrorRejected : '',
  };

  Future<void> _continue() async {
    final vm = ref.read(onboardingProvider.notifier);
    final name = vm.chosenCoachName;
    // Kept the default: nothing to validate, nothing to send.
    if (name == null) {
      vm.next();
      return;
    }
    setState(() {
      _busy = true;
      _rejected = false;
    });
    // Blocks only on a definite no. A timeout or no connection accepts it
    // locally and moves on: this is the user's own private word, and losing
    // the funnel to a moderation round-trip is the worse failure.
    final accepted = await ref
        .read(quitStoreProvider.notifier)
        .reserveCoachName(name);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _rejected = !accepted;
    });
    if (accepted) vm.next();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final state = ref.watch(onboardingProvider);
    final vm = ref.read(onboardingProvider.notifier);
    final typed = state.coachNameInput;
    final defaultName = l10n.coachName;
    final error = typed.trim().isEmpty ? '' : _errorFor(typed, l10n);
    final blocked = typed.trim().isNotEmpty && error.isNotEmpty;

    return StepBody(
      title: l10n.obCoachNameTitle(defaultName),
      subtitle: l10n.obCoachNameSubtitle,
      children: [
        LpNoteCard(l10n.obCoachNameAsk(defaultName)),
        const SizedBox(height: 20),
        LpField(
          label: l10n.obCoachNameFieldLabel,
          controller: _field,
          hint: defaultName,
          onChanged: (v) {
            if (_rejected) setState(() => _rejected = false);
            vm.typeCoachName(v);
          },
        ),
        SizedBox(
          height: 22,
          child: error.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    error,
                    style: LpType.caption(lp.cautionText),
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.obCoachNameSuggestions,
          style: LpType.caption(lp.textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in [
              l10n.obCoachNameSuggestion1,
              l10n.obCoachNameSuggestion2,
              l10n.obCoachNameSuggestion3,
              l10n.obCoachNameSuggestion4,
            ])
              LpChip(
                label: name,
                selected: state.coachNameInput.trim() == name,
                onTap: () {
                  _field.text = name;
                  setState(() => _rejected = false);
                  vm.typeCoachName(name);
                },
              ),
          ],
        ),
        const Spacer(),
        Text(
          l10n.obCoachNameLater,
          textAlign: TextAlign.center,
          style: LpType.caption(lp.textFaint),
        ),
        const SizedBox(height: 12),
        LpButton(
          typed.trim().isEmpty
              ? l10n.obCoachNameKeep(defaultName)
              : l10n.obCoachNameCta,
          busy: _busy,
          onTap: blocked ? null : _continue,
        ),
      ],
    );
  }
}
