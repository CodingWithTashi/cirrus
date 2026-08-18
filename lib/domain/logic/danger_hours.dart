import '../models/models.dart';

/// Danger-hour detection (docs/03 §8): top hour buckets over trailing days.
abstract final class DangerHours {
  /// Aggregated puffs per hour over [logs].
  static Map<int, int> aggregate(Iterable<DayLog> logs) {
    final buckets = <int, int>{};
    for (final log in logs) {
      log.hourBuckets.forEach((hour, count) {
        buckets[hour] = (buckets[hour] ?? 0) + count;
      });
    }
    return buckets;
  }

  /// The contiguous high-risk window (start hour, end hour exclusive) around
  /// the single hottest hour; needs ≥3 logged days to be meaningful.
  static (int, int)? window(Iterable<DayLog> logs) {
    final confirmed = logs.where((l) => l.isConfirmed).toList();
    if (confirmed.length < 3) return null;
    final buckets = aggregate(confirmed);
    if (buckets.isEmpty) return null;
    final peak = buckets.entries
        .reduce((a, b) => b.value > a.value ? b : a)
        .key;
    var start = peak;
    var end = peak + 1;
    if ((buckets[peak - 1] ?? 0) * 2 >= (buckets[peak] ?? 1)) start = peak - 1;
    if ((buckets[peak + 1] ?? 0) * 2 >= (buckets[peak] ?? 1)) end = peak + 2;
    return (start.clamp(0, 23), end.clamp(1, 24));
  }

  /// 0..1 heat per hour for the Stats heatmap.
  static Map<int, double> heat(Iterable<DayLog> logs) {
    final buckets = aggregate(logs);
    if (buckets.isEmpty) return const {};
    final max = buckets.values.reduce((a, b) => a > b ? a : b);
    if (max == 0) return const {};
    return buckets.map((h, v) => MapEntry(h, v / max));
  }
}
