/// Day keys are `'yyyy-MM-dd'` at the user's LOCAL midnight — never epoch math.
///
/// Mirrors `functions/src/domain/dateKey.ts` name-for-name so the two files
/// diff side by side. The asymmetry between them is deliberate: the SERVER has
/// no local timezone worth trusting, so every helper there takes an IANA zone
/// explicitly. The CLIENT *is* the user's timezone, so the zone is implicit
/// here and must never become a parameter — the moment a caller can pass one,
/// some caller passes UTC and the user's day boundary moves.
///
/// | this file            | `dateKey.ts`             |
/// |----------------------|--------------------------|
/// | `dayKey(DateTime)`   | `dayKeyIn(Date, tz)`     |
/// | `hour(DateTime)`     | `hourIn(Date, tz)`       |
/// | `daysBetween(a, b)`  | `daysBetween(key, key)`  |
/// | `addDays(day, n)`    | `addDays(key, n)`        |
/// | `isDayKey`           | `isDayKey`               |
/// | `dayStart`, `parseDayKey`, `toYmdInt`, `fromYmdInt` | — (the server deliberately has no local midnight) |
library;

/// The wire shape, identical to `dateKey.ts`'s `KEY`.
final RegExp _keyPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

abstract final class LpDate {
  /// Local midnight of [instant] — THE one truncation in the app.
  ///
  /// Byte-for-byte `DateTime(y, m, d)`: no `toLocal()`, no UTC round-trip. The
  /// journey's day map is keyed by this value and `journeys/{uid}` is written
  /// as a whole document on every optimistic mutation, so a change here that
  /// shifted a key by an hour would make the app miss today's log and then
  /// write the broken map back over the good one.
  static DateTime dayStart(DateTime instant) =>
      DateTime(instant.year, instant.month, instant.day);

  /// Local calendar date → `'yyyy-MM-dd'`.
  static String dayKey(DateTime instant) =>
      '${instant.year.toString().padLeft(4, '0')}-'
      '${instant.month.toString().padLeft(2, '0')}-'
      '${instant.day.toString().padLeft(2, '0')}';

  /// `'yyyy-MM-dd'` → local midnight.
  static DateTime parseDayKey(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Wall-clock hour 0–23 on the device.
  ///
  /// The single reader of the device clock's hour. Danger-hour bucketing stays
  /// client-side on purpose: this is by definition the user's own wall clock at
  /// the moment they vaped, whereas the server's stored `tz` is a snapshot from
  /// the last `syncUserContext`, so a traveller's evening puffs would file
  /// under last week's zone.
  static int hour(DateTime instant) => instant.hour;

  /// Whole CALENDAR days from [from] to [to]. Negative if [to] precedes.
  ///
  /// Compares through UTC-flagged midnights — the same shared fiction
  /// `dateKey.ts`'s private `utcMillis` uses, and for the same reason: both
  /// sides share it, so the difference is exact even across a DST boundary.
  /// `to.difference(from).inDays` truncates a 23-hour spring-forward gap to 0.
  static int daysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  /// Shifts [day] by [delta] CALENDAR days, preserving local midnight.
  ///
  /// `DateTime(y, m, d + delta)` normalizes month and year overflow and lands
  /// on midnight of the target date whatever the offset does in between.
  /// `day.add(Duration(days: delta))` adds absolute hours instead: across a DST
  /// change it returns 23:00 or 01:00 of the neighbouring date, which is not a
  /// key in the day map. That is exactly how the Freedom Streak used to reset
  /// itself to zero twice a year.
  static DateTime addDays(DateTime day, int delta) =>
      DateTime(day.year, day.month, day.day + delta);

  /// Validates the wire shape before it reaches a Firestore path or a date.
  static bool isDayKey(String? value) =>
      value != null && _keyPattern.hasMatch(value);

  /// Local date → the packed `yyyyMMdd` int the coach wire format uses.
  static int toYmdInt(DateTime day) =>
      day.year * 10000 + day.month * 100 + day.day;

  /// The inverse of [toYmdInt] — provably so, because they live together.
  static DateTime fromYmdInt(int ymd) =>
      DateTime(ymd ~/ 10000, (ymd % 10000) ~/ 100, ymd % 100);
}
