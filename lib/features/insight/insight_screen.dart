import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_format.dart';
import '../../core/widgets/lp_charts.dart';
import '../../core/widgets/press_scale.dart';
import '../../data/stores/providers.dart';

/// Frame 42 — the weekly AI report as swipeable story cards:
/// one insight + one concrete move per card, ends on next week's plan.
class InsightScreen extends ConsumerStatefulWidget {
  const InsightScreen({super.key});

  @override
  ConsumerState<InsightScreen> createState() => _InsightScreenState();
}

class _InsightScreenState extends ConsumerState<InsightScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final snap = ref.watch(todayProvider);
    final week = ((snap?.dayNumber ?? 7) / 7).ceil();
    final now = DateTime.now();
    final range =
        '${LpFormat.shortDate(now.subtract(const Duration(days: 6)), locale)}–${LpFormat.shortDate(now, locale)}';

    final cards = [
      (
        l10n.insight1Headline,
        l10n.insight1Body,
        l10n.insight1ChartLabel,
        l10n.insight1Action,
        const [18, 12, 20, 26, 34, 42, 88, 100, 72],
        {6, 7, 8},
      ),
      (
        l10n.insight2Headline,
        l10n.insight2Body,
        l10n.insight2ChartLabel,
        l10n.insight2Action,
        const [0, 0, 0, 14, 30, 44, 52, 40, 28],
        <int>{},
      ),
      (
        l10n.insight3Headline,
        l10n.insight3Body,
        l10n.insight3ChartLabel,
        l10n.insight3Action,
        const [82, 18],
        {1},
      ),
      (
        l10n.insight4Headline,
        l10n.insight4Body,
        l10n.insight4ChartLabel,
        l10n.insight4Action,
        const [100, 90, 78, 66, 52, 40, 30],
        <int>{},
      ),
    ];

    return Scaffold(
      backgroundColor: lp.panicBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.insightTitle(week, range),
                    style: LpType.body13(lp.textSecondary),
                  ),
                  PressScale(
                    onTap: () => context.pop(),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: lp.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: cards.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final (headline, body, chartLabel, action, values, hot) =
                      cards[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(26),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [lp.surface, lp.surfaceSubtle],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: lp.border, width: 1.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.insightCounter(i + 1, cards.length),
                                  style: LpType.caption11(
                                    lp.voltText,
                                    weight: FontWeight.w700,
                                  ).copyWith(letterSpacing: 1.5),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  headline,
                                  style: LpType.title(lp.textPrimary),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  body,
                                  style: LpType.body14(lp.textSecondary),
                                ),
                                const Spacer(),
                                Text(
                                  chartLabel,
                                  style: LpType.caption11(
                                    lp.textSecondary,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                BarChart(
                                  values: values,
                                  height: 70,
                                  gap: 4,
                                  radius: 3,
                                  highlight: hot,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: lp.oxygenSoft,
                            borderRadius: BorderRadius.circular(
                              LpDimens.rInput,
                            ),
                            border: Border.all(
                              color: lp.oxygen.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '→',
                                style: LpType.body13(
                                  lp.oxygenText,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  action,
                                  style: LpType.body13(lp.textBody),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 7),
                    AnimatedContainer(
                      duration: LpMotion.fast,
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? lp.volt : lp.textFaint,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
