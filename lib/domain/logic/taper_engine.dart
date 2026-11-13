import 'dart:math' as math;

import '../models/models.dart';

/// The adaptive taper curve — core IP from docs/03 §3.
///
/// Base curve: `limit(d) = round(B × (1 − d/P)^1.5)` with a fixed tail so the
/// final approach is always […, ≤3, ≤1, 0]. The spec's prose floor
/// (`[5% of B capped at 5, 3, 1]`) contradicts its own worked example
/// (B=200,P=30 → D27=6, D28=3, D29=1, D30=0), and the QA gate in §12 pins the
/// example table — so the example wins here.
abstract final class TaperEngine {
  /// Daily limit for 1-based day [d] of a plan.
  static int limitFor(QuitPlan plan, int d) {
    if (plan.method == QuitMethod.coldTurkey) return 0;
    final p = plan.totalDays;
    // Where THIS plan's curve starts: the baseline on a first plan, the
    // level it was started again at on a later one (`QuitPlan.taperFrom`).
    final b = plan.curveStart;
    if (d >= p) return 0;
    final base = (b * math.pow(1 - d / p, 1.5)).round();
    if (d == p - 1) return math.min(base, 1).clamp(0, 1);
    if (d == p - 2) return math.min(base, 3);
    return base;
  }

  /// Full curve, day 1..totalDays.
  static List<int> curve(QuitPlan plan) => [
    for (var d = 1; d <= plan.totalDays; d++) limitFor(plan, d),
  ];

  /// Day index (1-based) where the limit first drops to half of where the
  /// curve started.
  static int halfwayDay(QuitPlan plan) {
    for (var d = 1; d <= plan.totalDays; d++) {
      if (limitFor(plan, d) <= plan.curveStart / 2) return d;
    }
    return plan.totalDays;
  }

  /// Day index (1-based) where cravings typically fade — 70% through the
  /// plan (docs/03 §3, the frame-37 "coming up" milestone).
  static int cravingsFadeDay(QuitPlan plan) => (plan.totalDays * 0.7).round();

  /// Puffs the curve avoids vs baseline: `Σ (B − limit(d))`.
  ///
  /// [fromDay] mirrors `MoneyEngine.projectedToFreedom`: it sums the days
  /// AFTER it, so 0 (the default) is the whole plan and a day number part-way
  /// through gives what is still ahead. A paywall shown to someone on day 25
  /// of 30 must not offer them the whole curve as though none of it had
  /// happened yet.
  static int projectedPuffsAvoided(QuitPlan plan, {int fromDay = 0}) {
    var avoided = 0;
    for (var d = fromDay + 1; d <= plan.totalDays; d++) {
      avoided += plan.baselinePuffsPerDay - limitFor(plan, d);
    }
    return avoided;
  }

  /// The most days a plan's Freedom Day can be pushed back in total
  /// (docs/15 QP-A9). It was half the plan — 15 days on a 30-day taper, so a
  /// few slips could turn a month into six weeks — and each week of delay to a
  /// quit date raised the chance of lapsing by 19% (Hughes 2010).
  ///
  /// **This number lives in exactly two places**: here and `MAX_STRETCH_DAYS`
  /// in `functions/src/domain/taperEngine.ts`. Both are pinned to the same
  /// table, and a client a build behind the server must not disagree about
  /// the ceiling.
  static const maxStretchDays = 7;

  /// The ceiling for [plan]: [maxStretchDays], or half of a plan too short for
  /// that, and nothing at all for cold turkey — there is no runway to lengthen.
  static int _stretchCeiling(QuitPlan plan) => plan.method == QuitMethod.coldTurkey
      ? 0
      : math.min(maxStretchDays, (plan.paceDays * 0.5).floor());

  /// How many more days a slip could still add to [plan]'s runway.
  static int stretchLeft(QuitPlan plan) =>
      math.max(0, _stretchCeiling(plan) - plan.stretchDays);

  /// Big-relapse recovery (docs/03 §5): stretch Freedom Day by [extraDays],
  /// up to the ceiling. The curve regenerates over the longer runway.
  ///
  /// A stretch already given is never lowered. Plans stretched under the old
  /// half-the-plan rule keep every day they were promised; the ceiling only
  /// stops them growing further.
  static QuitPlan reflowAfterSlip(QuitPlan plan, {int extraDays = 2}) {
    final ceiling = _stretchCeiling(plan);
    final stretch = math.max(
      plan.stretchDays,
      math.min(plan.stretchDays + extraDays, ceiling),
    );
    return stretch == plan.stretchDays
        ? plan
        : plan.copyWith(stretchDays: stretch);
  }

  /// Normalized (0..1) points of the curve for painting, downsampled to
  /// at most [samples] points. First point = day 1, last = Freedom Day.
  static List<double> normalizedCurve(QuitPlan plan, {int samples = 40}) {
    final b = plan.curveStart;
    if (b == 0) return const [0, 0];
    final total = plan.totalDays;
    final n = math.min(samples, total);
    return [
      for (var i = 0; i < n; i++)
        limitFor(plan, 1 + ((total - 1) * i / (n - 1)).round()) / b,
    ];
  }
}
