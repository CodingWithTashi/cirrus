import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/enum_labels.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_format.dart';
import '../../core/widgets/lp_buttons.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_misc.dart';
import '../../core/widgets/lp_selectables.dart';
import '../../core/widgets/press_scale.dart';
import '../../core/widgets/rolling_number.dart';
import '../../data/stores/providers.dart';

/// Frame 49 — profile: countdown hero, Your Why, lifetime stats.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final journey = ref.watch(quitStoreProvider);
    final snap = ref.watch(todayProvider);
    if (journey == null || snap == null) return const SizedBox.shrink();

    Widget statCard(Widget value, String label) => LpCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          value,
          const SizedBox(height: 3),
          Text(label, style: LpType.caption11(lp.textSecondary)),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(leading: BackChevron(onTap: () => context.pop())),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Row(
              children: [
                EmojiAvatar(journey.profile.avatarEmoji, size: 64),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        journey.profile.alias,
                        style: LpType.titleSm(lp.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.profileQuittingSince(
                          LpFormat.shortDate(journey.plan.startDate, locale),
                          journey.plan.method.label(context).toLowerCase(),
                          snap.dayNumber,
                        ),
                        style: LpType.caption(lp.textSecondary),
                      ),
                    ],
                  ),
                ),
                PressScale(
                  onTap: () => _showEditSheet(context, ref),
                  child: Text(
                    l10n.commonEdit,
                    style: LpType.caption(lp.voltText, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LpCard(
              radius: LpDimens.rCardLg,
              borderColor: lp.ember.withValues(alpha: 0.45),
              glowColor: lp.ember,
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Text(
                    l10n.profileCountdownLabel,
                    style: LpType.caption11(
                      lp.emberText,
                      weight: FontWeight.w700,
                    ).copyWith(letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 8),
                  RollingNumber(
                    snap.daysToFreedom,
                    style: LpType.numberHero(lp.emberText, size: 54).copyWith(
                      shadows: [
                        Shadow(
                          color: lp.ember.withValues(alpha: 0.4),
                          blurRadius: 32,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.profileDaysTo(
                      LpFormat.shortDate(snap.freedomDate, locale),
                    ),
                    style: LpType.caption(lp.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Frame 49: the Why card links back into the panic reframe.
            PressScale(
              onTap: () => context.push(Routes.panic),
              child: LpCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel(l10n.obWhyCardLabel),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final why in journey.profile.whys)
                          StaticChip(why.label(context), small: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: statCard(
                    Text(
                      LpFormat.money(snap.savedLifetime, locale),
                      style: LpType.number(lp.voltText, size: 24),
                    ),
                    l10n.profileLifetimeSaved,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: statCard(
                    Text(
                      LpFormat.integer(snap.puffsNotTaken, locale),
                      style: LpType.number(lp.voltText, size: 24),
                    ),
                    l10n.profilePuffsNotTaken,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: statCard(
                    Text(
                      '${snap.cravingsSurvivedTotal}',
                      style: LpType.number(lp.textPrimary, size: 24),
                    ),
                    l10n.homeCravingsBeaten,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: statCard(
                    Text(
                      '${journey.earnedBadges.length}',
                      style: LpType.number(lp.textPrimary, size: 24),
                    ),
                    l10n.profileBadgesEarned,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _linkRow(
              context,
              '🏆',
              l10n.milestonesTitle,
              () => context.push(Routes.milestones),
            ),
            _linkRow(
              context,
              '📊',
              l10n.insightLinkTitle,
              () => context.push(Routes.insight),
            ),
            const SizedBox(height: 10),
            LpButton(
              l10n.profileSettings,
              style: LpButtonStyle.surface,
              height: 50,
              onTap: () => context.push(Routes.settings),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkRow(
    BuildContext context,
    String emoji,
    String label,
    VoidCallback onTap,
  ) {
    final lp = context.lp;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PressScale(
        onTap: onTap,
        child: LpCard(
          radius: LpDimens.rInput,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: LpType.body14(lp.textPrimary, weight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: lp.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    final journey = ref.read(quitStoreProvider);
    if (journey == null) return;
    final alias = TextEditingController(text: journey.profile.alias);
    var emoji = journey.profile.avatarEmoji;
    const options = ['🦊', '🦦', '🦅', '🐺', '🐢', '🐝', '🦉', '🦋'];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) {
          final lp = context.lp;
          final l10n = context.l10n;
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.profileEditAlias,
                  style: LpType.titleSm(lp.textPrimary),
                ),
                const SizedBox(height: 16),
                LpField(
                  label: l10n.profileEditAlias,
                  controller: alias,
                  hint: l10n.profileAliasHint,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.profileEditAvatar,
                  style: LpType.body13(lp.textSecondary),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final option in options)
                      PressScale(
                        onTap: () => setState(() => emoji = option),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: emoji == option
                                  ? context.lp.voltFocus
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: EmojiAvatar(option, size: 44),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                LpButton(
                  l10n.commonSave,
                  onTap: () {
                    final text = alias.text.trim();
                    ref
                        .read(quitStoreProvider.notifier)
                        .updateAlias(
                          text.startsWith('@') ? text : '@$text',
                          emoji,
                        );
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(alias.dispose);
  }
}
