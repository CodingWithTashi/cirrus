import 'package:flutter/material.dart';

import '../../../app/theme/lp_colors.dart';
import '../../../app/theme/lp_typography.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/widgets/lp_buttons.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../domain/logic/games/game_session.dart';
import '../panic_screens.dart';
import 'game_outcome.dart';
import 'game_result_line.dart';
import 'intensity_row.dart';

/// The check-in between rounds: what happened, the dose ring, an optional
/// re-rating, and the why step's two choices. The primary is sixty more
/// seconds — "it passed" is theirs to say. After the fifth round the primary
/// becomes the other ways out.
class RoundPanel extends StatelessWidget {
  const RoundPanel({
    super.key,
    required this.outcome,
    required this.best,
    required this.rounds,
    required this.canContinue,
    required this.intensity,
    required this.onIntensity,
    required this.onKeepPlaying,
    required this.onTryElse,
    required this.onPassed,
  });

  final GameOutcome outcome;

  /// The journey's best for the game right now.
  final int? best;

  /// Rounds played to the end this session.
  final int rounds;
  final bool canContinue;

  /// Their answer to "how bad is it now?", if any.
  final int? intensity;
  final ValueChanged<int> onIntensity;
  final VoidCallback onKeepPlaying;
  final VoidCallback onTryElse;
  final VoidCallback onPassed;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final dose = (rounds / GameSession.targetRounds).clamp(0.0, 1.0);
    // The choices stay pinned; the content centres when it fits and scrolls
    // when it does not. No Spacer/IntrinsicHeight over the animating timer.
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      rounds == GameSession.targetRounds
                          ? l10n.gameDoseDone
                          : l10n.gameMinutesDone(rounds),
                      textAlign: TextAlign.center,
                      style: LpType.title(lp.textPrimary, size: 28),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: GameResultLine(outcome: outcome, best: best),
                    ),
                    const SizedBox(height: 18),
                    IntensityRow(
                      label: l10n.gameIntensityNow,
                      value: intensity,
                      onChanged: onIntensity,
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: ProgressRing(
                        progress: dose,
                        size: 72,
                        strokeWidth: 7,
                        color: lp.oxygen,
                        glow: false,
                        child: Text(
                          '$rounds/${GameSession.targetRounds}',
                          style: LpType.number(lp.textPrimary, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.gameResearchNote,
                      textAlign: TextAlign.center,
                      style: LpType.caption11(lp.textFaint),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: CravingTimer(late: true)),
          const SizedBox(height: 14),
          if (canContinue)
            LpButton(
              l10n.gameAnotherRound,
              style: LpButtonStyle.oxygen,
              onTap: onKeepPlaying,
            )
          else ...[
            Text(
              l10n.gameCapLine,
              textAlign: TextAlign.center,
              style: LpType.body13(lp.textSecondary),
            ),
            const SizedBox(height: 10),
            LpButton(
              l10n.gameCapTryElse,
              style: LpButtonStyle.surface,
              onTap: onTryElse,
            ),
          ],
          const SizedBox(height: 6),
          LpTextButton(l10n.panicItPassed, onTap: onPassed),
        ],
      ),
    );
  }
}
