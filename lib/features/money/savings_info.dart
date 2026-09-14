import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_format.dart';
import '../../core/utils/lp_haptics.dart';
import '../../core/widgets/lp_buttons.dart';
import '../../core/widgets/lp_card.dart';
import '../../data/stores/providers.dart';
import '../../domain/logic/savings_breakdown.dart';

/// The (i) beside every savings figure — Home's "saved so far" and the Money
/// hero — and the one sheet both open (docs/10 §40).
///
/// One widget on purpose: the explanation of a number has to say the same
/// thing wherever the number appears, and every figure it shows comes from
/// [SavingsBreakdown], which takes them from the money engine.
class SavingsInfoButton extends StatelessWidget {
  const SavingsInfoButton({
    super.key,
    this.extent = 40,
    this.alignment = Alignment.center,
  });

  /// The square the tap lands in. The glyph stays small so the figure stays
  /// the loudest thing near it; the target does not.
  final double extent;

  /// Where the glyph sits inside [extent] — top-right when the button covers
  /// a card's corner.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return Semantics(
      button: true,
      label: context.l10n.savingsInfoLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          LpHaptics.light();
          showSavingsInfo(context);
        },
        child: SizedBox.square(
          dimension: extent,
          child: Align(
            alignment: alignment,
            child: Icon(
              Icons.info_outline_rounded,
              size: 17,
              color: lp.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Explains "saved so far" over whatever screen asked.
Future<void> showSavingsInfo(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _SavingsInfoSheet(),
    );

class _SavingsInfoSheet extends ConsumerWidget {
  const _SavingsInfoSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journey = ref.watch(quitStoreProvider);
    final snap = ref.watch(todayProvider);
    if (journey == null || snap == null) return const SizedBox.shrink();
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final b = SavingsBreakdown.of(journey, snap);
    String money(double amount) => LpFormat.money(amount, locale, cents: true);

    final today = switch (b.today) {
      TodaySavings.notCounted => l10n.savingsInfoTodayNotCounted,
      _ => l10n.savingsInfoTodayValue(b.todayPuffs, money(b.todaySaved)),
    };
    final why = switch (b.today) {
      TodaySavings.notCounted => l10n.savingsInfoWhyNotCounted,
      // Per ten puffs once one puff rounds to a few cents: "about $0.04" × 88
      // is $3.52 beside a line reading $3.77, and a reader who checks the sum
      // stops trusting the sheet (docs/10 §41).
      TodaySavings.kept when b.costPerPuff < 0.10 =>
        l10n.savingsInfoWhyKeptPerTen(
          b.usualPuffs,
          money(b.costPerPuff * 10),
          b.todayNotTaken,
        ),
      TodaySavings.kept => l10n.savingsInfoWhyKept(
        b.usualPuffs,
        money(b.costPerPuff),
        b.todayNotTaken,
      ),
      TodaySavings.nothingKept => l10n.savingsInfoWhyNothingKept(b.usualPuffs),
      TodaySavings.unpriced => l10n.savingsInfoWhyUnpriced,
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.savingsInfoTitle,
              style: LpType.heading(lp.textPrimary, size: 20),
            ),
            const SizedBox(height: 14),
            LpCard(
              subtle: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Column(
                children: [
                  _Line(
                    icon: Icons.history_rounded,
                    label: l10n.savingsInfoUsualDay,
                    value: l10n.savingsInfoUsualDayValue(
                      b.usualPuffs,
                      money(b.usualDaySpend),
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: lp.border),
                  _Line(
                    icon: Icons.today_rounded,
                    label: l10n.savingsInfoToday,
                    value: today,
                  ),
                  Divider(height: 1, thickness: 1, color: lp.border),
                  _Line(
                    icon: Icons.savings_outlined,
                    label: l10n.savingsInfoTotal,
                    value: money(b.total),
                    emphasis: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(why, style: LpType.body13(lp.textSecondary)),
            const SizedBox(height: 18),
            LpButton(
              l10n.errorGotIt,
              style: LpButtonStyle.surface,
              height: 48,
              fontSize: 15,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// One labelled figure in the sheet's card.
class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// The total: drawn the way the figure it explains is drawn.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: lp.textSecondary),
          const SizedBox(width: 10),
          Text(label, style: LpType.body14(lp.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: emphasis
                  ? LpType.number(lp.voltText, size: 18)
                  : LpType.body14(lp.textPrimary, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
