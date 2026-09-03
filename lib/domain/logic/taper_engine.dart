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
    final b = plan.baselinePuffsPerDay;
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

  /// Day index (1-based) where the limit first drops to half the baseline.
  static int halfwayDay(QuitPlan plan) {
    for (var d = 1; d <= plan.totalDays; d++) {
      if (limitFor(plan, d) <= plan.baselinePuffsPerDay / 2) return d;
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

  /// Big-relapse recovery (docs/03 §5): stretch Freedom Day, capped at +50%
  /// of the original pace. The curve regenerates over the longer runway.
  static QuitPlan reflowAfterSlip(QuitPlan plan, {int extraDays = 2}) {
    final cap = (plan.paceDays * 0.5).floor();
    final stretch = math.min(plan.stretchDays + extraDays, cap);
    return plan.copyWith(stretchDays: stretch);
  }

  /// Normalized (0..1) points of the curve for painting, downsampled to
  /// at most [samples] points. First point = day 1, last = Freedom Day.
  static List<double> normalizedCurve(QuitPlan plan, {int samples = 40}) {
    final b = plan.baselinePuffsPerDay;
    if (b == 0) return const [0, 0];
    final total = plan.totalDays;
    final n = math.min(samples, total);
    return [
      for (var i = 0; i < n; i++)
        limitFor(plan, 1 + ((total - 1) * i / (n - 1)).round()) / b,
    ];
  }
}
