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

  /// "2:41" mm:ss timer.
  static String timer(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// "14h" / "38m" compact elapsed time.
  static String compactAgo(Duration d) =>
      d.inHours >= 1 ? '${d.inHours}h' : '${d.inMinutes}m';

  /// Signed percent like "-38%".
  static String signedPercent(int percent) =>
      percent > 0 ? '+$percent%' : '$percent%';
}
