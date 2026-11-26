import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/press_scale.dart';
import '../../data/stores/providers.dart';
import '../../domain/logic/exercises/exercise.dart';
import 'exercise_catalog.dart';

/// One tappable card that opens an exercise: a tinted icon, what it is, one
/// line about it, and a chevron. The look of the panic flow's loop options,
/// so an exercise reads the same wherever it is offered.
///
/// It is handed an id and nothing else; the words, the icon and the route
/// are the catalog's. And it shows what a tap will OPEN: a Premium exercise
/// on a free account is drawn as the free one of the same kind, never as a
/// lock, because a card that names one thing and opens another is a small
/// lie told to somebody mid-craving.
class ExerciseLauncherCard extends ConsumerWidget {
  const ExerciseLauncherCard({
    super.key,
    required this.id,
    required this.source,
  });

  final ExerciseId id;
  final ExerciseSource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    // Watched, so a subscription that lands or lapses while the card is on
    // screen renames it. `launch` asks the same question again at tap time.
    final shown = Exercises.resolveFor(
      id,
      premium: ref.watch(isPremiumProvider),
    );
    final entry = ExerciseCatalog.of(shown);
    final (tint, ink) = switch (Exercises.of(shown).kind) {
      ExerciseKind.calm => (lp.oxygen, lp.oxygenText),
      ExerciseKind.focus => (lp.volt, lp.voltText),
      ExerciseKind.people => (lp.ember, lp.emberText),
    };
    // One node for a screen reader: "Orbs, 60 seconds…, button", not a
    // button and two loose sentences beside it.
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: PressScale(
          onTap: () => ExerciseCatalog.launch(context, id, source: source),
          child: LpCard(
            radius: LpDimens.rCardLg,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: tint.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(entry.icon, size: 24, color: ink),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title(l10n),
                        style: LpType.emphasis(lp.textPrimary),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        entry.subtitle(l10n),
                        style: LpType.caption(lp.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: lp.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
