import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_selectables.dart';
import '../../domain/models/models.dart';

/// The one rule above the others, for anyone who has smoked (docs/15 QP-A4).
///
/// Every cessation guideline puts "do not go back to smoking" first, and the
/// app otherwise has no way to say it: 19% of British method-users quit
/// vaping by returning to cigarettes (ASH 2026). The wording says the vape is
/// the SAFER of two choices, never that it is safe, and it is shown only to
/// someone who is already vaping.
///
/// Renders nothing for [SmokingHistory.never]: a rule about cigarettes shown to
/// a person who never touched one is noise at best and a nudge at worst.
///
/// [source] is the door for the More help link's `help_viewed.source`. Pass
/// [onDone] where the card can be dismissed; leave it null where it is part of
/// a page (the onboarding step), and no Done button is drawn.
class SmokingRuleCard extends StatelessWidget {
  const SmokingRuleCard({
    super.key,
    required this.answer,
    required this.source,
    this.onDone,
  });

  final SmokingHistory answer;
  final String source;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    if (answer == SmokingHistory.never) return const SizedBox.shrink();
    final lp = context.lp;
    final l10n = context.l10n;
    return LpCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.smokingRuleBody, style: LpType.body14(lp.textPrimary)),
          if (answer == SmokingHistory.current) ...[
            const SizedBox(height: 10),
            Text(
              l10n.smokingRuleCurrent,
              style: LpType.body14(lp.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              LpChip(
                label: l10n.helpTitle,
                selected: false,
                fontSize: 14,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                onTap: () => context.push(Routes.helpFrom(source)),
              ),
              if (onDone != null)
                LpChip(
                  label: l10n.commonDone,
                  selected: false,
                  fontSize: 14,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  onTap: onDone!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
