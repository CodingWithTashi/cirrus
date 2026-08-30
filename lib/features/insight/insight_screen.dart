import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../domain/date_key.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_format.dart';
import '../../core/widgets/lp_charts.dart';
import '../../core/widgets/press_scale.dart';
import '../../data/stores/providers.dart';
import '../../domain/logic/danger_hours.dart';
import '../../domain/models/journey_state.dart';
import '../../domain/models/models.dart';

/// One story card: a claim, the data behind it, and at most one next move.
class _InsightCard {
  const _InsightCard({
    required this.headline,
    required this.body,
    required this.chartLabel,
    required this.values,
    this.highlight = const {},
    this.action,
  });

  final String headline;
  final String body;
  final String chartLabel;
  final List<num> values;

  /// Bar indexes drawn in Ember — the hard days, or the danger hours.
  final Set<int> highlight;

  /// The concrete thing to do. Only the last card carries one: an action
  /// strip on every card is four instructions, which is none.
  final String? action;
}

/// Frame 42 — the weekly report as swipeable story cards.
///
/// One source only: the report `weeklyInsight` generated for THIS user,
/// rendered verbatim over charts built from their own logs.
///
/// There used to be a set of authored cards standing in whenever no report
/// existed — free tier, a short week, the demo backend. They read as findings
/// about the reader ("You vape 3x more after 10 p.m. on weekends", "Friday and
/// Saturday account for 41% of your weekly puffs") and were the same four
/// paragraphs for everybody. Invented statistics wearing the user's name are
/// the exact thing the "no invented numbers" rule exists to prevent, so when
/// there is no report the screen now says so.
///
/// The model's prose is NOT localized (see [WeeklyInsight]): it is generated
/// in the locale `syncUserContext` recorded, and translating a summary of
/// numbers the model never saw would be a different claim. Only the labels
/// around it come from the ARB files.
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
    final journey = ref.watch(quitStoreProvider);
    final week = ((snap?.dayNumber ?? 7) / 7).ceil();
    final now = DateTime.now();
    final range =
        '${LpFormat.shortDate(LpDate.addDays(now, -6), locale)}–${LpFormat.shortDate(now, locale)}';

    final report = ref.watch(weeklyInsightProvider).valueOrNull;
    final cards = report == null || journey == null
        ? const <_InsightCard>[]
        : _reportCards(context, report, journey);

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
              child: cards.isEmpty
                  ? _PendingReport(
                      coachName:
                          ref.watch(coachNameProvider) ?? l10n.coachName,
                    )
                  : PageView.builder(
                      controller: _controller,
                      itemCount: cards.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _CardView(
                          card: cards[i],
                          index: i,
                          total: cards.length,
                        ),
                      ),
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

  /// The AI report, over charts drawn from this user's own logs.
  ///
  /// The model gets the same window the charts do (docs/04 §5 sends 7 days of
  /// logs plus 14 days of hour buckets), so the prose and the bars are
  /// describing one week — the brand rule is no invented numbers, and a
  /// decorative chart under a real claim would break it just as badly as a
  /// made-up figure.
  List<_InsightCard> _reportCards(
    BuildContext context,
    WeeklyInsight report,
    JourneyState journey,
  ) {
    final l10n = context.l10n;
    final week = _trailingDays(journey, 7);
    final fortnight = _trailingDays(journey, 14);
    final hours = DangerHours.aggregate(fortnight);
    final hot = _hottestHours(hours);

    return [
      _InsightCard(
        headline: report.headline,
        body: report.pattern,
        chartLabel: l10n.insightWeekChartLabel,
        values: [for (final d in week) d.puffs],
        highlight: {
          for (var i = 0; i < week.length; i++)
            if (week[i].isOverLimit) i,
        },
      ),
      _InsightCard(
        headline: l10n.insightWinLabel,
        body: report.win,
        chartLabel: l10n.insightCravingsChartLabel,
        values: [for (final d in week) d.cravingsSurvived],
      ),
      _InsightCard(
        headline: l10n.insightWatchoutLabel,
        body: report.watchout,
        chartLabel: l10n.insightHoursChartLabel,
        values: [for (var h = 0; h < 24; h++) hours[h] ?? 0],
        highlight: hot,
        action: report.move,
      ),
    ];
  }

  /// The [count] most recent logged days, oldest first. Days with no log are
  /// simply absent — a missing day is not a zero-puff day, and charting it as
  /// one would invent a clean day the user never had.
  static List<DayLog> _trailingDays(JourneyState journey, int count) {
    final logs = journey.days.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return logs.length <= count ? logs : logs.sublist(logs.length - count);
  }

  /// The top two puff hours — the same rule the server's report uses, so the
  /// bars it highlights are the ones the prose is about.
  static Set<int> _hottestHours(Map<int, int> hours) {
    final ranked = hours.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value != a.value
          ? b.value.compareTo(a.value)
          : a.key.compareTo(b.key));
    return {for (final e in ranked.take(2)) e.key};
  }
}

class _CardView extends StatelessWidget {
  const _CardView({
    required this.card,
    required this.index,
    required this.total,
  });

  final _InsightCard card;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    return Column(
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
                  l10n.insightCounter(index + 1, total),
                  style: LpType.caption11(
                    lp.voltText,
                    weight: FontWeight.w700,
                  ).copyWith(letterSpacing: 1.5),
                ),
                const SizedBox(height: 14),
                Text(card.headline, style: LpType.title(lp.textPrimary)),
                const SizedBox(height: 12),
                // The model writes to a length budget, but a long week can
                // still overflow a phone in a large text size — scroll the
                // prose rather than clipping a sentence mid-claim.
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      card.body,
                      style: LpType.body14(lp.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  card.chartLabel,
                  style: LpType.caption11(
                    lp.textSecondary,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                BarChart(
                  values: card.values,
                  height: 70,
                  gap: 4,
                  radius: 3,
                  highlight: card.highlight,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (card.action != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: lp.oxygenSoft,
              borderRadius: BorderRadius.circular(LpDimens.rInput),
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
                  style: LpType.body13(lp.oxygenText, weight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    card.action!,
                    style: LpType.body13(lp.textBody),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Shown until `weeklyInsight` has actually written a report.
///
/// Says what it is waiting for rather than filling the space. An empty state
/// that explains itself keeps the promise; four paragraphs of invented
/// statistics would have broken it.
class _PendingReport extends StatelessWidget {
  const _PendingReport({required this.coachName});

  final String coachName;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📄', style: TextStyle(fontSize: 40, color: lp.textFaint)),
            const SizedBox(height: 18),
            Text(
              l10n.insightPendingTitle,
              textAlign: TextAlign.center,
              style: LpType.titleSm(lp.textPrimary),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.insightPendingBody(coachName),
              textAlign: TextAlign.center,
              style: LpType.body13(lp.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
