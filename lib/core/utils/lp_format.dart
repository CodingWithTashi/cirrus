import 'package:intl/intl.dart';

/// Locale-aware formatting helpers. All money in the demo is USD; the
/// formatter still localizes separators/symbol position per locale.
abstract final class LpFormat {
  static String money(num amount, String locale, {bool cents = false}) {
    final f = NumberFormat.currency(
      locale: locale,
      symbol: '\$',
      decimalDigits: cents ? 2 : 0,
    );
    return f.format(amount);
  }

  /// An amount in a specific currency — the store's, for a derived figure
  /// beside a store price (the yearly card's per-week line). [money] is USD
  /// by construction; a store price in EUR must not be divided into dollars.
  static String moneyIn(num amount, String locale, String currencyCode) =>
      NumberFormat.simpleCurrency(
        locale: locale,
        name: currencyCode,
        decimalDigits: 2,
      ).format(amount);

  static String integer(num value, String locale) =>
      NumberFormat.decimalPattern(locale).format(value.round());

  /// "Sep 15" style short date.
  static String shortDate(DateTime date, String locale) =>
      DateFormat.MMMd(locale).format(date);

  /// "Sep 15, 2026" style date.
  static String mediumDate(DateTime date, String locale) =>
      DateFormat.yMMMd(locale).format(date);

  /// "Sunday, Aug 16" — the Home header.
  static String weekdayDate(DateTime date, String locale) =>
      '${DateFormat.EEEE(locale).format(date)}, ${DateFormat.MMMd(locale).format(date)}';

  static String weekday(DateTime date, String locale) =>
      DateFormat.EEEE(locale).format(date);

  /// "9 PM" style hour.
  static String hour(int hour24, String locale) =>
      DateFormat.j(locale).format(DateTime(2026, 1, 1, hour24));

  /// "3:07 PM" style clock time.
  static String clockTime(DateTime t, String locale) =>
      DateFormat.jm(locale).format(t);

  /// "Sat, Aug 15" style weekday + short date.
  static String weekdayShortDate(DateTime t, String locale) =>
      DateFormat.MMMEd(locale).format(t);

  /// "2:41" mm:ss timer.
  static String timer(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// "3d" / "14h" / "38m" compact elapsed time. The day bucket matters for
  /// feed ages: a three-day-old post used to read "72h", which nobody says.
  ///
  /// `dayBucket: false` keeps hours past 24 — the Health timeline's
  /// milestones are hour-denominated (24h/48h/72h), and "2d" would hide that
  /// someone is one hour short of the 72h node.
  static String compactAgo(Duration d, {bool dayBucket = true}) =>
      dayBucket && d.inDays >= 1
      ? '${d.inDays}d'
      : d.inHours >= 1
      ? '${d.inHours}h'
      : '${d.inMinutes}m';

  /// Signed percent like "-38%".
  static String signedPercent(int percent) =>
      percent > 0 ? '+$percent%' : '$percent%';
}
