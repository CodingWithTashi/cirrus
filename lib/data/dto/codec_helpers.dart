/// Shared JSON encoding primitives for the DTO codecs. Pure Dart.
library;

import '../../domain/date_key.dart';

/// Local calendar date → `'yyyy-MM-dd'`. The journey's day map is keyed by
/// local midnight; epoch-day math would shift dates across timezones.
String encodeDayKey(DateTime d) => LpDate.dayKey(d);

/// `'yyyy-MM-dd'` → local midnight [DateTime].
DateTime decodeDayKey(String key) => LpDate.parseDayKey(key);

String encodeTimestamp(DateTime t) => t.toIso8601String();

DateTime decodeTimestamp(String iso) => DateTime.parse(iso);

/// The same, for a field that is legitimately absent.
///
/// Separate from the required pair rather than loosening it: most timestamps
/// in this app are load-bearing, and a codec that silently accepts null for
/// one of those would turn a missing field into a null model field instead of
/// a decode error somebody notices.
String? encodeTimestampOrNull(DateTime? t) => t?.toIso8601String();

DateTime? decodeTimestampOrNull(String? iso) =>
    iso == null ? null : DateTime.tryParse(iso);

/// Parses an enum by its wire `.name`, falling back when the value is missing
/// or unknown (forward compatibility with payloads from newer backends).
T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

T? enumByNameOrNull<T extends Enum>(List<T> values, Object? name) {
  if (name == null) return null;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}
