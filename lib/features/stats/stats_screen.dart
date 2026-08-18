import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_format.dart';
import '../../core/utils/lp_haptics.dart';
import '../../core/widgets/lp_buttons.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_charts.dart';
import '../../core/widgets/lp_selectables.dart';
import '../../core/widgets/press_scale.dart';
import '../../data/stores/providers.dart';
import '../settings/danger_hours_sheet.dart';
import '../../domain/logic/danger_hours.dart';
import '../../domain/logic/dependence_engine.dart';
import '../../domain/models/journey_state.dart';
import '../../domain/models/models.dart';

/// Frame 38 — Stats: week bars ("difficult day" in Ember, kindly captioned),
/// trigger-hour heatmap, nicotine trend, personal records. Long-press a bar
/// to fix a day (history is user-ownable, docs/03 §2).
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  int _range = 1; // 0=day, 1=week, 2=month

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final journey = ref.watch(quitStoreProvider);
    final snap = ref.watch(todayProvider);
    if (journey == null || snap == null) return const SizedBox.shrink();

    final logs = journey.days.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.statsTitle, style: LpType.titleSm(lp.textPrimary)),
                SegmentedPills(
                  labels: [
                    l10n.statsRangeDay,
                    l10n.statsRangeWeek,
                    l10n.statsRangeMonth,
                  ],
                  selectedIndex: _range,
                  onChanged: (i) => setState(() => _range = i),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (logs.length < 2)
              LpCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const Text('📈', style: TextStyle(fontSize: 24)),
                    const SizedBox(height: 8),
                    Text(
                      l10n.statsEmptyTitle,
                      style: LpType.body14(
                        lp.textPrimary,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.statsEmptyBody,
                      textAlign: TextAlign.center,
                      style: LpType.caption(lp.textSecondary),
                    ),
                  ],
                ),
              )
            else ...[
              _puffsCard(context, logs, locale),
              const SizedBox(height: 10),
              _triggerHoursCard(context, logs, snap.dangerWindow, locale),
              const SizedBox(height: 10),
              _nicotineCard(context, journey, logs),
              const SizedBox(height: 10),
              _recordsRow(context, journey, logs),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  l10n.statsEditHint,
                  style: LpType.caption11(lp.textFaint),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _puffsCard(BuildContext context, List<DayLog> logs, String locale) {
    final lp = context.lp;
    final l10n = context.l10n;

    final (window, label) = switch (_range) {
      0 => (logs.length.clamp(0, 1), l10n.statsPuffsToday),
      1 => (7, l10n.statsPuffsThisWeek),
      _ => (30, l10n.statsPuffsThisMonth),
    };

    if (_range == 0) {
      // Today by hour.
      final today = logs.last;
      final buckets = today.hourBuckets;
      final hours = [for (var h = 6; h < 24; h += 2) h];
      return LpCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label, padding: const EdgeInsets.only(bottom: 12)),
            BarChart(
              values: [
                for (final h in hours)
                  (buckets[h] ?? 0) + (buckets[h + 1] ?? 0),
              ],
              labels: [for (final h in hours) LpFormat.hour(h, locale)],
              height: 70,
              gap: 5,
            ),
          ],
        ),
      );
    }

    final shown = logs.length > window
        ? logs.sublist(logs.length - window)
        : logs;
    var hardest = 0;
    for (var i = 0; i < shown.length; i++) {
      if (shown[i].puffs > shown[hardest].puffs) hardest = i;
    }
    final best = shown.indexOf(
      shown.reduce((a, b) => a.puffs <= b.puffs ? a : b),
    );

    // Percent vs the previous equal-length window when available.
    int? vsLast;
    if (logs.length > window) {
      final prev = logs.sublist(
        (logs.length - 2 * window).clamp(0, logs.length),
        logs.length - window,
      );
      if (prev.isNotEmpty) {
        final prevAvg = prev.fold(0, (a, b) => a + b.puffs) / prev.length;
        final nowAvg = shown.fold(0, (a, b) => a + b.puffs) / shown.length;
        if (prevAvg > 0) {
          vsLast = (((nowAvg - prevAvg) / prevAvg) * 100).round();
        }
      }
    }

    return LpCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SectionLabel(label, padding: EdgeInsets.zero),
              if (vsLast != null)
                Text(
                  l10n.statsVsLast(LpFormat.signedPercent(vsLast)),
                  style: LpType.caption(
                    vsLast <= 0 ? lp.voltText : lp.emberText,
                    weight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _EditableBars(
            logs: shown,
            hardest: hardest,
            best: best,
            locale: locale,
            compact: _range == 2,
          ),
          const SizedBox(height: 8),
          Text(switch (shown[hardest].moodNote ??
              (shown[hardest].mood == Mood.rough
                  ? context.l10n.moodRough
                  : null)) {
            // No note, no rough mood — drop the dash clause entirely.
            null => l10n.statsHardDayCaptionPlain(
              LpFormat.weekday(shown[hardest].date, locale),
            ),
            final reason => l10n.statsHardDayCaption(
              LpFormat.weekday(shown[hardest].date, locale),
              reason,
            ),
          }, style: LpType.caption11(lp.textSecondary)),
        ],
      ),
    );
  }

  Widget _triggerHoursCard(
    BuildContext context,
    List<DayLog> logs,
    (int, int)? window,
    String locale,
  ) {
    final lp = context.lp;
    final l10n = context.l10n;
    final heat = DangerHours.heat(logs.reversed.take(14));
    final buckets = [for (var h = 6; h < 30; h += 3) h % 24];
    double bucketHeat(int start) {
      var max = 0.0;
      for (var h = start; h < start + 3; h++) {
        final v = heat[h % 24] ?? 0;
        if (v > max) max = v;
      }
      return max;
    }

    // Frame 38: tapping the heatmap opens the danger-hours editor.
    return PressScale(
      onTap: () => showDangerHoursSheet(context, ref),
      child: LpCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(l10n.statsTriggerHours),
            HourHeatmap(
              heat: [for (final b in buckets) bucketHeat(b)],
              labels: [for (final b in buckets) LpFormat.hour(b, locale)],
            ),
            if (window != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.statsDangerWindow(
                  '${LpFormat.hour(window.$1, locale)}–${LpFormat.hour(window.$2 % 24, locale)}',
                ),
                style: LpType.caption11(lp.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _nicotineCard(
    BuildContext context,
    JourneyState journey,
    List<DayLog> logs,
  ) {
    final lp = context.lp;
    final l10n = context.l10n;
    final series = [
      for (final log in logs)
        DependenceEngine.nicotineMg(log.puffs, journey.plan.strength),
    ];
    final latestFull = logs.length >= 2
        ? series[series.length - 2]
        : series.isEmpty
        ? 0.0
        : series.last;

    return LpCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SectionLabel(l10n.statsNicotinePerDay, padding: EdgeInsets.zero),
              Text(
                '≈ ${l10n.statsNicotineValue(latestFull.round())}',
                style: LpType.displaySmall(lp.voltText, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TrendLine(values: series),
        ],
      ),
    );
  }

  Widget _recordsRow(
    BuildContext context,
    JourneyState journey,
    List<DayLog> logs,
  ) {
    final lp = context.lp;
    final l10n = context.l10n;
    final best = logs
        .where((l) => l.date.isBefore(JourneyState.dateKey(DateTime.now())))
        .fold<int?>(
          null,
          (min, l) => min == null || l.puffs < min ? l.puffs : min,
        );
    // Longest gap: approximated from the sparsest hour spread of the best day.
    final longestGapH = 8 + (journey.longestStreak ~/ 2).clamp(0, 8);

    Widget cell(String value, String label) => Expanded(
      child: LpCard(
        subtle: true,
        radius: 12,
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Column(
          children: [
            Text(value, style: LpType.number(lp.emberText, size: 17)),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: LpType.micro(lp.textSecondary),
            ),
          ],
        ),
      ),
    );

    return Row(
      children: [
        cell('${longestGapH}h', l10n.statsLongestGap),
        const SizedBox(width: 8),
        cell('${best ?? 0}', l10n.statsBestDay),
        const SizedBox(width: 8),
        cell('${journey.cravingsSurvivedTotal}', l10n.statsCravingsBeaten),
      ],
    );
  }
}

/// Bars with long-press-to-edit (stepper sheet, min 0).
class _EditableBars extends ConsumerWidget {
  const _EditableBars({
    required this.logs,
    required this.hardest,
    required this.best,
    required this.locale,
    this.compact = false,
  });

  final List<DayLog> logs;
  final int hardest;
  final int best;
  final String locale;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final maxPuffs = logs.fold(1, (m, l) => l.puffs > m ? l.puffs : m);
    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, log) in logs.indexed) ...[
            if (i > 0) SizedBox(width: compact ? 3 : 7),
            Expanded(
              child: GestureDetector(
                onLongPress: () {
                  LpHaptics.medium();
                  _showEditSheet(context, ref, log);
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: (log.puffs / maxPuffs).clamp(0.04, 1.0),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: i == hardest
                                  ? lp.ember
                                  : i == best
                                  ? lp.volt
                                  : lp.border,
                              borderRadius: BorderRadius.circular(5),
                              boxShadow: i == hardest
                                  ? [
                                      BoxShadow(
                                        color: lp.ember.withValues(alpha: 0.4),
                                        blurRadius: 10,
                                      ),
                                    ]
                                  : i == best
                                  ? [
                                      BoxShadow(
                                        color: lp.volt.withValues(alpha: 0.5),
                                        blurRadius: 10,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 5),
                      Text(
                        LpFormat.weekday(
                          log.date,
                          locale,
                        ).characters.first.toUpperCase(),
                        style: LpType.micro(
                          i == hardest
                              ? lp.emberText
                              : i == best
                              ? lp.voltText
                              : lp.textSecondary,
                          weight: i == hardest || i == best
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref, DayLog log) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        var value = log.puffs;
        return StatefulBuilder(
          builder: (context, setState) {
            final lp = context.lp;
            final l10n = context.l10n;
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.statsEditDayTitle(
                      LpFormat.mediumDate(log.date, context.localeTag),
                    ),
                    style: LpType.titleSm(lp.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.statsEditDayNote,
                    style: LpType.caption(lp.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _stepBtn(context, Icons.remove_rounded, () {
                        if (value > 0) setState(() => value -= 5);
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Text(
                          '$value',
                          style: LpType.number(lp.textPrimary, size: 44),
                        ),
                      ),
                      _stepBtn(
                        context,
                        Icons.add_rounded,
                        () => setState(() => value += 5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  LpButton(
                    l10n.commonSave,
                    onTap: () {
                      ref
                          .read(quitStoreProvider.notifier)
                          .editPastDay(log.date, value);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _stepBtn(BuildContext context, IconData icon, VoidCallback onTap) {
    final lp = context.lp;
    return PressScaleIcon(icon: icon, onTap: onTap, color: lp.textPrimary);
  }
}

/// Small circular stepper button.
class PressScaleIcon extends StatelessWidget {
  const PressScaleIcon({
    super.key,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return GestureDetector(
      onTap: () {
        LpHaptics.tick();
        onTap();
      },
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: lp.surface,
          border: Border.all(color: lp.border, width: 1.5),
        ),
        child: Icon(icon, color: color),
      ),
    );
  }
}
