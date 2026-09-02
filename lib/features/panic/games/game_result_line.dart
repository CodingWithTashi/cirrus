import 'package:flutter/material.dart';

import '../../../app/theme/lp_colors.dart';
import '../../../app/theme/lp_typography.dart';
import '../../../core/utils/enum_labels.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/widgets/lp_selectables.dart';
import 'game_outcome.dart';

/// "🎹 112 tiles · NEW BEST" as a volt chip, "🧱 6 lines · best 9" in
/// secondary text, or just the count when there is no best to name. Shared
/// by the round panel and the survived screen.
class GameResultLine extends StatelessWidget {
  const GameResultLine({super.key, required this.outcome, required this.best});

  final GameOutcome outcome;

  /// The journey's best for the game right now.
  final int? best;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final game = outcome.game;
    final count = '${game.emoji} ${game.unit(context, outcome.score)}';
    if (outcome.newBest) {
      return StaticChip('$count · ${l10n.survivedGameNewBest}', small: true);
    }
    final b = best;
    return Text(
      b == null ? count : '$count · ${l10n.survivedGameBest(b)}',
      textAlign: TextAlign.center,
      style: LpType.body13(lp.textSecondary),
    );
  }
}
