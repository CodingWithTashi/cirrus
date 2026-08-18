import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/widgets/confetti_burst.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_misc.dart';
import '../../data/stores/providers.dart';
import '../../domain/logic/streak_engine.dart';
import '../../domain/models/models.dart';

/// Badge catalog: id → (emoji, ember-family). Names resolve via l10n.
const _badgeDefs = <(String, String, bool)>[
  ('firstLog', '🐣', false),
  ('firstCraving', '⚡', false),
  ('spark', '✨', true),
  ('weekFlame', '🔥', true),
  ('hundredSaved', '💰', false),
  ('cleanWeekend', '🌙', false),
  ('helpedSos', '🤝', false),
  ('firstPost', '📣', false),
  ('moodWeek', '🙂', false),
  ('tenCravings', '🛡️', false),
  ('quarterCurve', '📉', false),
  ('twoWeekFlame', '🔥', true),
  ('halfNicotine', '🫁', false),
  ('fiveHundredSaved', '💎', false),
  ('buddyBond', '👊', false),
  ('comeback', '🌅', false),
  ('inferno', '👑', true),
  ('freedomDay', '🏆', true),
];

String badgeName(BuildContext context, String id) {
  final l10n = context.l10n;
  return switch (id) {
    'firstLog' => l10n.mFirstLog,
    'firstCraving' => l10n.mFirstCraving,
    'spark' => l10n.mSpark,
    'weekFlame' => l10n.mWeekFlame,
    'hundredSaved' => l10n.mHundredSaved,
    'cleanWeekend' => l10n.mCleanWeekend,
    'helpedSos' => l10n.mHelpedSos,
    'firstPost' => l10n.mFirstPost,
    'moodWeek' => l10n.mMoodWeek,
    'tenCravings' => l10n.mTenCravings,
    'quarterCurve' => l10n.mQuarterCurve,
    'twoWeekFlame' => l10n.mTwoWeekFlame,
    'halfNicotine' => l10n.mHalfNicotine,
    'fiveHundredSaved' => l10n.mFiveHundredSaved,
    'buddyBond' => l10n.mBuddyBond,
    'comeback' => l10n.mComeback,
    'inferno' => l10n.mInferno,
    'freedomDay' => l10n.mFreedomDay,
    _ => id,
  };
}

/// Frame 47 — milestones grid: earned glow, locked grayscale, next-badge
/// progress pinned on top, confetti when a badge unlocks while watching.
/// Personal bests only, never a leaderboard.
class MilestonesScreen extends ConsumerWidget {
  const MilestonesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final journey = ref.watch(quitStoreProvider);
    final snap = ref.watch(todayProvider);
    if (journey == null || snap == null) return const SizedBox.shrink();
    final earned = journey.earnedBadges;

    // Next streak-flame badge as the pinned progress card.
    final nextFlameDays = StreakEngine.daysToNextFlame(snap.streak);
    final nextFlame = FlameState.forStreak(snap.streak + (nextFlameDays ?? 0));
    final nextName = switch (nextFlame) {
      FlameState.flicker => l10n.mSpark,
      FlameState.flame => l10n.mWeekFlame,
      FlameState.blaze => l10n.mTwoWeekFlame,
      _ => l10n.mInferno,
    };
    final target = nextFlame.minDays;

    return Scaffold(
      appBar: AppBar(
        leading: BackChevron(onTap: () => context.pop()),
        title: Text(l10n.milestonesTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Text(
                l10n.milestonesEarned(earned.length, _badgeDefs.length),
                style: LpType.caption(lp.textSecondary),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Next-badge card pinned above the scrolling grid (frame 47).
            if (nextFlameDays != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: LpCard(
                  borderColor: lp.ember.withValues(alpha: 0.45),
                  glowColor: lp.ember,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: lp.emberSoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: lp.ember.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: const Text('🔥', style: TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.milestonesNext(nextName),
                              style: LpType.body14(
                                lp.textPrimary,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GlowProgressBar(
                              value: snap.streak / target,
                              height: 6,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.milestonesNextProgress(snap.streak, target),
                              style: LpType.caption11(lp.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    children: [
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        children: [
                          for (final (id, emoji, ember) in _badgeDefs)
                            _BadgeCell(
                              id: id,
                              emoji: emoji,
                              emberFamily: ember,
                              earned: earned.contains(id),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LpNoteCard(l10n.milestonesNotLeaderboard),
                    ],
                  ),
                  // A badge earned while the grid is open = true milestone.
                  Positioned.fill(child: NewIdConfetti(ids: earned)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeCell extends StatelessWidget {
  const _BadgeCell({
    required this.id,
    required this.emoji,
    required this.emberFamily,
    required this.earned,
  });

  final String id;
  final String emoji;
  final bool emberFamily;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final accent = emberFamily ? lp.ember : lp.volt;
    return AnimatedOpacity(
      duration: LpMotion.fast,
      opacity: earned ? 1 : 0.55,
      child: Container(
        decoration: BoxDecoration(
          color: earned ? lp.surface : lp.surfaceSubtle,
          borderRadius: BorderRadius.circular(LpDimens.rCardLg),
          border: Border.all(
            color: earned ? accent.withValues(alpha: 0.5) : lp.borderSubtle,
            width: 1.5,
          ),
          boxShadow: earned
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.12),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            earned
                ? Text(emoji, style: const TextStyle(fontSize: 26))
                : ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      0.2126,
                      0.7152,
                      0.0722,
                      0,
                      0,
                      0.2126,
                      0.7152,
                      0.0722,
                      0,
                      0,
                      0.2126,
                      0.7152,
                      0.0722,
                      0,
                      0,
                      0,
                      0,
                      0,
                      1,
                      0,
                    ]),
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
            const SizedBox(height: 6),
            Text(
              badgeName(context, id),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: LpType.micro(
                earned ? lp.textPrimary : lp.textFaint,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
