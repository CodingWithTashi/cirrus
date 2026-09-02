/// The two derived numbers the paywall shows next to a store price. Both are
/// computed from the store's own amounts at render time — the "no invented
/// numbers" rule (docs/07 §8) applied to money: the yearly card's
/// "per week · SAVE x%" used to be a hardcoded string, which was only true in
/// USD and only at the launch prices.
abstract final class PricingMath {
  static const int weeksPerYear = 52;

  /// A yearly amount spread over its 52 weeks.
  static double perWeek(double yearlyAmount) => yearlyAmount / weeksPerYear;

  /// Percent saved by paying yearly instead of weekly for a year, rounded —
  /// 39.99 against 2.99 is 74.
  ///
  /// Null whenever the badge could not be honest: either amount missing or
  /// non-positive, the two priced in different currencies (a mixed offering
  /// during a store rollout), or no saving at all. Null means "show nothing",
  /// never "show 0%".
  static int? yearlySavingsPercent({
    required double? yearly,
    required double? weekly,
    String? yearlyCurrency,
    String? weeklyCurrency,
  }) {
    if (yearly == null || weekly == null) return null;
    if (yearly <= 0 || weekly <= 0) return null;
    if (yearlyCurrency != weeklyCurrency) return null;
    final fullYearWeekly = weekly * weeksPerYear;
    if (yearly >= fullYearWeekly) return null;
    final percent = ((1 - yearly / fullYearWeekly) * 100).round();
    // Break-even within float noise (2.99 × 52 is 155.48000000000002) rounds
    // to 0, and a "SAVE 0%" badge is the one thing worse than no badge.
    return percent <= 0 ? null : percent;
  }
}
