import 'package:flutter/material.dart';

import '../../../app/theme/lp_colors.dart';
import '../../../app/theme/lp_dimens.dart';
import '../../../app/theme/lp_typography.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/widgets/lp_card.dart';

/// Where a fact comes from — published research, or the user's own arithmetic.
enum StepFactTone { science, yourNumbers }

/// A one-card fact under an onboarding answer: something true, sourced, and
/// worth a small laugh.
///
/// It occupies no space at all until it has something to say, and that is the
/// feature. docs/02 §8 is the whole approved-statistics pool and its last row
/// lists any uncited number as banned forever, so most steps have nothing
/// honest to add and stay quiet rather than inventing something. Anything put
/// here must land a row in §8 naming its source in the same change.
class StepFact extends StatefulWidget {
  const StepFact({
    super.key,
    required this.text,
    this.tone = StepFactTone.science,
  });

  /// Null whenever the current answers have nothing sourced to say.
  final String? text;
  final StepFactTone tone;

  @override
  State<StepFact> createState() => _StepFactState();
}

class _StepFactState extends State<StepFact> {
  /// The last thing we had to say, kept so the card can fade OUT with its
  /// words still in it rather than collapsing to an empty box mid-transition.
  String? _last;

  @override
  void initState() {
    super.initState();
    _last = widget.text;
  }

  @override
  void didUpdateWidget(StepFact old) {
    super.didUpdateWidget(old);
    if (widget.text != null) _last = widget.text;
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final body = _last;
    // Nothing has ever been worth saying here, so take no room.
    if (body == null) return const SizedBox.shrink();

    final showing = widget.text != null;
    final (label, accent) = switch (widget.tone) {
      StepFactTone.science => (l10n.obFactLabelScience, lp.voltText),
      StepFactTone.yourNumbers => (l10n.obFactLabelYourNumbers, lp.oxygenText),
    };

    // Fade and slide over an always-laid-out child — never an animated resize.
    // This sits inside StepScrollView's IntrinsicHeight, and a child whose
    // intrinsic height animates there is what took the Health screen down for
    // every user past day 1.
    return AnimatedOpacity(
      duration: LpMotion.fast,
      opacity: showing ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 250),
        curve: LpMotion.ease,
        offset: showing ? Offset.zero : const Offset(0, 0.25),
        child: LpCard(
          radius: LpDimens.rInput,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: LpType.caption11(
                  accent,
                  weight: FontWeight.w600,
                ).copyWith(letterSpacing: 0.5),
              ),
              const SizedBox(height: 5),
              Text(body, style: LpType.body13(lp.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
