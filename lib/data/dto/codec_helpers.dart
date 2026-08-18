/// Shared JSON encoding primitives for the DTO codecs. Pure Dart.
library;

/// Local calendar date → `'yyyy-MM-dd'`. The journey's day map is keyed by
/// local midnight; epoch-day math would shift dates across timezones.
String encodeDayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// `'yyyy-MM-dd'` → local midnight [DateTime].
DateTime decodeDayKey(String key) {
  final parts = key.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

String encodeTimestamp(DateTime t) => t.toIso8601String();

DateTime decodeTimestamp(String iso) => DateTime.parse(iso);

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
