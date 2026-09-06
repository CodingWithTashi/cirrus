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
      final fire = fireTimeFor(hour);
      if (isQuiet(fire.$1, quietStartHour, quietEndHour)) continue;
      slots.add(
        // id is derived from the hour so rescheduling the same hour replaces
        // its notification instead of stacking a second one.
        ReminderSlot(hour: fire.$1, minute: fire.$2, id: 1000 + hour),
      );
      if (slots.length >= maxPerDay) break;
    }
    return slots;
  }

  /// When a nudge for [hour] actually fires: (hour, minute), [leadMinutes]
  /// before the top of the hour. Public so the Settings sheet can print the
  /// exact time it is promising, from the same rule that schedules it.
  static (int, int) fireTimeFor(int hour) => _minus(hour, leadMinutes);

  /// The start hours a user may choose in Settings: every hour of the day
  /// whose nudge would NOT fall inside quiet hours, ascending.
  ///
  /// The old editor offered a slider from noon to 2am and silently dropped
  /// the nudge for anything from midnight on — a choice that saved but did
  /// nothing, which the Sep 1 field test read as "what does this even do?"
  /// (docs/09 issue 5). Offering only the hours that work, derived from the
  /// same [_isQuiet] the scheduler applies, means the sheet cannot promise a
  /// nudge the planner will refuse.
  static List<int> eligibleStartHours({
    required int quietStartHour,
    required int quietEndHour,
  }) => [
    for (var hour = 0; hour < 24; hour++)
      if (!isQuiet(fireTimeFor(hour).$1, quietStartHour, quietEndHour)) hour,
  ];

  /// [minutes] before [hour]:00, wrapping backwards past midnight.
  static (int, int) _minus(int hour, int minutes) {
    final total = (hour * 60 - minutes + 24 * 60) % (24 * 60);
    return (total ~/ 60, total % 60);
  }

  /// Quiet hours wrap midnight when start > end (the 23→8 default). Shared
  /// with [TrialReminderPlanner], so both nudges keep the same nights quiet.
  static bool isQuiet(int hour, int start, int end) =>
      start == end ? false : (start < end
          ? hour >= start && hour < end
          : hour >= start || hour < end);
}

/// Which reminder a notification tap came from. Carried as the notification's
/// payload (`kind.name`) and decoded back by the scheduler, so a tap can land
/// on the screen the reminder was about rather than wherever the app last was.
///
/// `milestone` is named, not chosen: `test/copy_honesty_test.dart` is keyed off
/// these values and stops forbidding the word in the notification-permission
/// copy the day a value called exactly that exists. The permission screen sold
/// "milestone celebrations" in five languages while seventeen badges unlocked
/// in silence; this is the value that makes the promise true.
enum ReminderKind { danger, trial, milestone }

/// One nudge at one instant — the trial-ending reminder and the milestone
/// celebration. Unlike a [ReminderSlot] it does not repeat, so it is an
/// absolute time, not a wall-clock hour.
class OneShotReminder {
  const OneShotReminder({required this.id, required this.at});

  final int id;
  final DateTime at;

  @override
  String toString() => 'OneShotReminder($id, ${at.toIso8601String()})';
}

/// Decides when the honest trial-ending reminder fires (docs/02 §4: "we'll
/// remind you before your trial ends", toggle ON by default).
///
/// Neither RevenueCat nor the stores send a "trial ends soon" event, and the
/// end is deterministic from the entitlement's expiry, so — like the
/// danger-hour nudges — it is scheduled on-device. The store's own charge is
/// what actually happens on the day; this is the heads-up the paywall
/// promised, one day before it.
abstract final class TrialReminderPlanner {
  /// Outside the 1000–1023 range the danger-hour slots use, so a danger-hour
  /// resync can cancel its own ids without touching this one.
  static const int id = 2000;

  /// One day before the charge. An absolute duration on purpose: this is
  /// "24 hours before an instant", not a calendar recurrence, so the DST rule
  /// for day keys does not apply — and the copy it fires says "tomorrow".
  static const Duration lead = Duration(hours: 24);

  /// Null when there is nothing honest to schedule: not a trial, no known
  /// end, the toggle off, or the moment already past (the store's own notice
  /// is all that is left to say). A fire time inside quiet hours moves to the
  /// nearest edge that keeps it on the day BEFORE the charge — the copy says
  /// "tomorrow": the evening band (23:30) pulls back to when quiet began that
  /// evening; the post-midnight band (03:00) pushes forward to when quiet
  /// ends that morning. Pulling the morning band back to the previous
  /// evening used to fire two days before the charge, for every trial that
  /// ended between midnight and eight.
  static OneShotReminder? plan({
    required Entitlement entitlement,
    required DateTime now,
    required int quietStartHour,
    required int quietEndHour,
    required bool enabled,
  }) {
    if (!enabled || !entitlement.isTrial) return null;
    final ends = entitlement.expiresAt;
    if (ends == null) return null;
    var at = ends.subtract(lead);
    if (ReminderPlanner.isQuiet(at.hour, quietStartHour, quietEndHour)) {
      // Same calendar day either way, so the "tomorrow" in the copy holds:
      // back to when quiet began, unless that was yesterday evening (the
      // wrapped window's morning band), in which case forward to its end.
      final wraps = quietStartHour > quietEndHour;
      final morningBand = wraps && at.hour < quietEndHour;
      at = DateTime(
        at.year,
        at.month,
        at.day,
        morningBand ? quietEndHour : quietStartHour,
      );
    }
    if (!at.isAfter(now)) return null;
    return OneShotReminder(id: id, at: at);
  }
}

/// A celebration that is owed: which badge, and when to say so.
class MilestoneCelebration {
  const MilestoneCelebration({
    required this.badgeId,
    required this.covers,
    required this.reminder,
  });

  /// The one being celebrated: the strongest that is owed.
  final String badgeId;

  /// Every badge this celebration settles, [badgeId] included.
  ///
  /// Usually just the one. It matters on a restored journey: `earnedBadges`
  /// comes back from the server while the record of what has been celebrated
  /// is device-local, so a reinstall can find four owed at once. Marking all
  /// of them here is what stops the app scheduling four separate 08:00
  /// notifications about milestones from weeks ago.
  final Set<String> covers;

  final OneShotReminder reminder;

  @override
  String toString() => 'MilestoneCelebration($badgeId, covers: $covers)';
}

/// Decides when a streak milestone is celebrated — the reminder the
/// notification-permission screen has been promising since onboarding shipped
/// (`test/copy_honesty_test.dart`), while seventeen badges unlocked in silence.
///
/// **It only ever celebrates a badge that is already earned.** `earnedBadges`
/// is a set union that never removes anything, so a scheduled celebration is a
/// statement about something that has already permanently happened. Nothing
/// here forward-guesses a streak that might break tonight — which is the only
/// way this notification could ever lie, and a quit app that congratulates you
/// for a day you did not have is worse than one that says nothing.
///
/// The timing follows from that. `StreakEngine.currentStreak` counts today as
/// soon as today is confirmed and holds, so the badge lands *during* the
/// qualifying day and the celebration lands the following morning — which is
/// also the beat the design frame draws it on.
abstract final class MilestoneReminderPlanner {
  /// 3000+. The danger-hour slots own 1000–1023 and the trial reminder owns
  /// 2000, so a cancel here can never reach either — the rule that exists
  /// because a `cancelAll()` on a puff-tap resync once took the trial reminder
  /// down with it.
  static const int idBase = 3000;

  /// Morning, so it opens a day rather than closing one.
  static const int hour = 8;

  /// The five ember-family badges, weakest first.
  ///
  /// Streak achievements only: `spark` at 3 days, `weekFlame` at 7,
  /// `twoWeekFlame` at 14, `inferno` at 30, and `freedomDay` at the end of the
  /// plan. That is five moments across a 30-day programme, which is rare enough
  /// that each one still means something.
  ///
  /// The other twelve badges are deliberately silent. `firstLog`,
  /// `firstCraving`, `firstPost`, `hundredSaved` and the rest are all earned
  /// while the person is already looking at the app — a push about something
  /// they just did on screen is noise, and this is a permission you only get
  /// asked for once. `test/domain/milestone_reminder_test.dart` pins the list
  /// against the ember-family flag in the milestones grid so the two cannot
  /// drift.
  static const List<String> celebrated = [
    'spark',
    'weekFlame',
    'twoWeekFlame',
    'inferno',
    'freedomDay',
  ];

  /// Null when nothing is owed: notifications off, nothing new earned, or
  /// everything earned has already been celebrated.
  ///
  /// When two land together — `inferno` and `freedomDay` can — the strongest
  /// wins, deterministically, so the same inputs always schedule the same
  /// notification and the coordinator's fingerprint stays stable.
  static MilestoneCelebration? plan({
    required Set<String> earnedBadges,
    required Set<String> celebratedBadges,
    required DateTime now,
    required int quietStartHour,
    required int quietEndHour,
    required bool enabled,
  }) {
    if (!enabled) return null;

    final owedAll = {
      for (final badge in celebrated)
        if (earnedBadges.contains(badge) && !celebratedBadges.contains(badge))
          badge,
    };
    if (owedAll.isEmpty) return null;
    // The strongest wins. `celebrated` is ordered weakest-first, so this is
    // the last one still owed.
    final owed = celebrated.lastWhere(owedAll.contains);

    // `DateTime(y, m, d + 1, h)` rather than `LpDate.addDays`: that helper
    // deliberately lands on local MIDNIGHT because it exists to build day
    // keys, and using it here silently threw the hour away. It still read
    // correctly under the default 23→8 quiet window — 00:00 is quiet, so the
    // correction below happened to push it back to 08:00 — and would have
    // fired at midnight for anyone who widened their quiet hours. Same
    // calendar arithmetic, same DST safety, hour kept.
    var at = _at(now, hour);
    if (!at.isAfter(now)) at = _at(now, hour, tomorrow: true);

    // A celebration is never time-critical, so a quiet hour pushes it FORWARD
    // to the end of the quiet window — never backward. Pulling it back is what
    // used to make the trial reminder fire two days before the charge.
    if (ReminderPlanner.isQuiet(at.hour, quietStartHour, quietEndHour)) {
      at = _at(at, quietEndHour);
      if (!at.isAfter(now)) at = _at(at, quietEndHour, tomorrow: true);
    }

    return MilestoneCelebration(
      badgeId: owed,
      covers: owedAll,
      // One id per badge, and each badge is celebrated at most once ever, so
      // an id is never reused and a second celebration can never replace a
      // first that has not fired yet.
      reminder: OneShotReminder(id: idBase + celebrated.indexOf(owed), at: at),
    );
  }

  static DateTime _at(DateTime day, int hour, {bool tomorrow = false}) =>
      DateTime(day.year, day.month, day.day + (tomorrow ? 1 : 0), hour);
}
