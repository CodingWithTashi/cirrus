import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_haptics.dart';
import '../../core/utils/lp_pricing.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_misc.dart';
import '../../core/widgets/press_scale.dart';
import '../../data/stores/community_store.dart' show CommunityStore;
import '../../data/stores/providers.dart';

/// Frame 46 — buddy pairing: side-by-side flames, nudge, privacy contract.
class BuddyScreen extends ConsumerWidget {
  const BuddyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final journey = ref.watch(quitStoreProvider);
    final snap = ref.watch(todayProvider);
    if (journey == null || snap == null) return const SizedBox.shrink();
    final buddy = journey.buddy;

    Widget person(
      String emoji,
      String alias,
      String sub,
      int streak,
      Color tint,
    ) {
      // Frame 46: the flame chip grows with each streak.
      final flameSize = (11 + streak / 5).clamp(11, 17).toDouble();
      return Column(
        children: [
          EmojiAvatar(emoji, size: 56, tint: tint),
          const SizedBox(height: 8),
          Text(
            alias,
            style: LpType.body13(lp.textPrimary, weight: FontWeight.w600),
          ),
          Text(sub, style: LpType.caption11(lp.textSecondary)),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: lp.emberSoft,
              borderRadius: BorderRadius.circular(LpDimens.rChip),
              border: Border.all(color: lp.ember.withValues(alpha: 0.4)),
            ),
            child: Text(
              '🔥 $streak',
              style: LpType.displaySmall(lp.emberText, size: flameSize),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackChevron(onTap: () => context.pop()),
        title: Text(l10n.buddyTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LpCard(
                radius: LpDimens.rBento,
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        person(
                          journey.profile.avatarEmoji,
                          journey.profile.alias,
                          l10n.commonYou,
                          snap.streak,
                          lp.volt,
                        ),
                        Text(
                          '×',
                          style: LpType.heading(lp.textFaint, size: 18),
                        ),
                        person(
                          buddy.avatarEmoji,
                          buddy.alias,
                          buddy.name,
                          buddy.streakDays,
                          lp.oxygen,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: lp.surfaceInset,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: lp.border),
                      ),
                      child: Text.rich(
                        TextSpan(
                          text: '${l10n.buddyCombinedStreak} ',
                          style: LpType.body13(lp.textSecondary),
                          children: [
                            TextSpan(
                              text: l10n.commonStreakDays(
                                snap.streak + buddy.streakDays,
                              ),
                              style: LpType.displaySmall(
                                lp.emberText,
                                size: 15,
                              ),
                            ),
                            TextSpan(
                              text: ' · ${l10n.buddyNeitherCaves}',
                              style: LpType.body13(lp.textSecondary),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PressScale(
                      onTap: () {
                        final store = ref.read(communityStoreProvider.notifier);
                        // Frame 46: pre-written supportive push, 2/day cap.
                        if (store.nudgesLeftToday == 0) {
                          showLpSnack(context, l10n.buddyNudgeCap);
                          return;
                        }
                        LpHaptics.medium();
                        store.nudgeBuddy();
                        showLpSnack(context, l10n.buddyNudged(buddy.name));
                      },
                      child: Opacity(
                        opacity:
                            ref.watch(
                                  communityStoreProvider.select(
                                    (s) => s.nudgesToday,
                                  ),
                                ) >=
                                CommunityStore.nudgeDailyCap
                            ? 0.55
                            : 1,
                        child: Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: lp.surface,
                            borderRadius: BorderRadius.circular(
                              LpDimens.rInput,
                            ),
                            border: Border.all(color: lp.border, width: 1.5),
                          ),
                          child: Text(
                            l10n.buddyNudge(buddy.name),
                            style: LpType.body14(
                              lp.textPrimary,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PressScale(
                      onTap: () =>
                          showLpSnack(context, context.l10n.commonComingSoon),
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: lp.surface,
                          borderRadius: BorderRadius.circular(LpDimens.rInput),
                          border: Border.all(color: lp.border, width: 1.5),
                        ),
                        child: Text(
                          l10n.buddyMessage,
                          style: LpType.body14(
                            lp.textPrimary,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LpCard(
                subtle: true,
                radius: 12,
                padding: const EdgeInsets.all(14),
                child: Text(
                  l10n.buddyPrivacyNote(buddy.name),
                  style: LpType.caption(lp.textSecondary),
                ),
              ),
              const Spacer(),
              SectionLabel(l10n.buddyPairsLabel),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: lp.surface,
                  borderRadius: BorderRadius.circular(LpDimens.rCard),
                  border: Border.all(color: lp.voltFocus, width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.buddyInviteTitle,
                            style: LpType.body14(
                              lp.textPrimary,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            LpLinks.invite(journey.profile.alias),
                            style: LpType.caption(lp.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    PressScale(
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: LpLinks.inviteUrl(journey.profile.alias),
                          ),
                        );
                        if (context.mounted) {
                          showLpSnack(context, l10n.buddyLinkCopied);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: lp.volt,
                          borderRadius: BorderRadius.circular(LpDimens.rChip),
                        ),
                        child: Text(
                          l10n.buddyCopyLink,
                          style: LpType.displaySmall(lp.onVolt, size: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
