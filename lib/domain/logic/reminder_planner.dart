import '../models/models.dart';
import 'danger_hours.dart';

/// One scheduled nudge: the local hour and minute it fires at.
class ReminderSlot {
  const ReminderSlot({required this.hour, required this.minute, required this.id});

  final int hour;
  final int minute;

  /// Stable per-slot id so a reschedule replaces rather than duplicates.
  final int id;

  @override
  String toString() =>
      'ReminderSlot($id, ${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')})';
}

/// Decides *when* danger-hour reminders fire (docs/03 §8).
///
/// Pure and separate from the platform scheduler on purpose: the rules here —
/// how many, how early, which hours are off-limits — are the ones that decide
/// whether the app feels like a helpful friend or like spam, and they are the
/// part worth testing. The plugin call is a thin wrapper around the result.
///
/// The rules, all from docs/03 §8:
///   * fire 10 minutes BEFORE the risky hour, not during it
///   * the top two hour buckets over the trailing 14 days
///   * at most three notifications a day, total
///   * nothing during quiet hours — with one deliberate exception below
abstract final class ReminderPlanner {
  static const int leadMinutes = 10;
  static const int maxPerDay = 3;

  /// Needs a few days of real data before it can claim to know anything
  /// (docs/03 §8). Before that the caller falls back to the onboarding
  /// `firstPuffWindow` answer.
  static const int minDaysOfData = 3;

  /// Top [count] hours by puff volume over the given logs, hottest first.
  static List<int> riskiestHours(Iterable<DayLog> logs, {int count = 2}) {
    final confirmed = logs.where((l) => l.isConfirmed).toList();
    if (confirmed.length < minDaysOfData) return const [];

    final buckets = DangerHours.aggregate(confirmed)
      ..removeWhere((_, v) => v == 0);
    if (buckets.isEmpty) return const [];

    final byVolume = buckets.entries.toList()
      // Ties break on the earlier hour so the plan is stable run to run;
      // an unstable order would reschedule notifications for no reason.
      ..sort((a, b) => b.value != a.value
          ? b.value.compareTo(a.value)
          : a.key.compareTo(b.key));

    return [for (final e in byVolume.take(count)) e.key];
  }

  /// Turns risky hours into concrete slots, applying every cap.
  ///
  /// [quietStart]/[quietEnd] wrap midnight (23 → 8 is the default). A reminder
  /// inside that window is dropped rather than shifted: moving a 2am nudge to
  /// 8am would fire it nine hours after the craving it was meant to precede,
  /// which is worse than not firing.
  /// [overrideHours], when set, replaces the detected hours entirely. That is
  /// the Settings "Danger hours" editor: a window the user chose beats a
  /// window we inferred, because they know about the Friday shift that their
  /// last fourteen days do not show. Every other rule still applies — the
  /// 10-minute lead, quiet hours, and the daily cap are safety rails, not
  /// defaults to be overridden.
  static List<ReminderSlot> plan({
    required Iterable<DayLog> logs,
    required int quietStartHour,
    required int quietEndHour,
    required bool notificationsOn,
    int? fallbackHour,
    List<int>? overrideHours,
  }) {
    if (!notificationsOn) return const [];

    var hours = overrideHours ?? riskiestHours(logs);
    if (hours.isEmpty && fallbackHour != null) hours = [fallbackHour];

    final slots = <ReminderSlot>[];
    for (final hour in hours) {
      final fire = _minus(hour, leadMinutes);
      if (_isQuiet(fire.$1, quietStartHour, quietEndHour)) continue;
      slots.add(
        // id is derived from the hour so rescheduling the same hour replaces
        // its notification instead of stacking a second one.
        ReminderSlot(hour: fire.$1, minute: fire.$2, id: 1000 + hour),
      );
      if (slots.length >= maxPerDay) break;
    }
    return slots;
  }

  /// [minutes] before [hour]:00, wrapping backwards past midnight.
  static (int, int) _minus(int hour, int minutes) {
    final total = (hour * 60 - minutes + 24 * 60) % (24 * 60);
    return (total ~/ 60, total % 60);
  }

  /// Quiet hours wrap midnight when start > end (the 23→8 default).
  static bool _isQuiet(int hour, int start, int end) =>
      start == end ? false : (start < end
          ? hour >= start && hour < end
          : hour >= start || hour < end);
}
