import '../../domain/logic/reminder_planner.dart';
import '../../domain/models/journey_state.dart';
import '../../domain/models/models.dart';
import '../api/firebase/reminder_scheduler.dart';
import 'settings_store.dart';

/// Keeps the device's notification schedule in step with the journey, the
/// entitlement and the user's settings.
///
/// This runs on every journey mutation — which is once per puff tap — so the
/// important behaviour is the one that does NOTHING. An unchanged plan must
/// not re-hit the OS scheduler, or a heavy logging day would cancel and
/// rebuild the same alarms hundreds of times.
///
/// Three independent schedules live here, each with its own fingerprint: the
/// repeating danger-hour nudges (ids 1000–1023), the one-shot trial-ending
/// reminder (id 2000), and the milestone celebration (3000+). Independent on
/// purpose — a puff tap must never wipe the trial reminder, which is exactly
/// what a shared cancel-all used to do.
class ReminderCoordinator {
  ReminderCoordinator(this._sink);

  final ReminderSink _sink;

  /// Fingerprint of the last applied danger-hour plan. Cheaper and more
  /// honest than comparing journeys: two different journeys that produce the
  /// same slots genuinely need no reschedule.
  String? _applied;

  /// Fingerprint of the last applied trial-ending reminder.
  String? _trialApplied;

  /// Fingerprint of the last scheduled milestone celebration.
  String? _milestoneApplied;

  /// Reminder taps, for the app to route on. See [ReminderSink.opened].
  Stream<ReminderKind> get opened => _sink.opened;

  Future<void> sync({
    required JourneyState? journey,
    required SettingsState settings,
    required String title,
    required String body,
    Entitlement entitlement = const Entitlement.none(),
    String trialTitle = '',
    String trialBody = '',
    String milestoneTitle = '',
    String Function(String badgeId)? milestoneBody,
    void Function(String armed, Set<String> covers)? onMilestoneScheduled,
    void Function()? onMilestonesWithdrawn,
    void Function(Set<String> earned)? onMilestonesAdopted,
    DateTime Function() now = DateTime.now,
  }) async {
    // Signed out, or notifications declined: clear the device rather than
    // simply stopping — yesterday's schedule would otherwise keep firing at
    // someone who has explicitly opted out. Everything goes, both schedules.
    if (journey == null || !settings.notificationsOn) {
      if (_applied != _cleared ||
          _trialApplied != _cleared ||
          _milestoneApplied != _cleared) {
        _applied = _cleared;
        _trialApplied = _cleared;
        _milestoneApplied = _cleared;
        await _sink.cancelAll();
        // `cancelAll` takes the milestone ids with it, and the badge is marked
        // settled at scheduling time — so without this the celebration is not
        // withdrawn, it is destroyed: switching notifications back on finds
        // nothing owed and never re-arms it.
        onMilestonesWithdrawn?.call();
      }
      return;
    }

    await _syncDangerHours(journey, settings, title: title, body: body);
    await _syncTrialEnding(
      entitlement,
      settings,
      now: now(),
      title: trialTitle,
      body: trialBody,
    );
    if (milestoneBody != null) {
      await _syncMilestone(
        journey,
        settings,
        now: now(),
        title: milestoneTitle,
        body: milestoneBody,
        onScheduled: onMilestoneScheduled,
        onAdopted: onMilestonesAdopted,
      );
    }
  }

  /// Schedules the celebration owed for a badge already earned.
  ///
  /// **Never withdrawn.** Unlike the trial reminder, whose reason can evaporate
  /// — converted, lapsed, toggled off — an earned badge stays earned. And the
  /// moment one is marked celebrated the planner answers null, so a
  /// cancel-on-null branch here would delete the very notification the previous
  /// sync had just armed. Only the top-level notifications-off `cancelAll`
  /// takes it down.
  Future<void> _syncMilestone(
    JourneyState journey,
    SettingsState settings, {
    required DateTime now,
    required String title,
    required String Function(String badgeId) body,
    void Function(String armed, Set<String> covers)? onScheduled,
    void Function(Set<String> earned)? onAdopted,
  }) async {
    // A ledger this device has never initialised for this account: adopt what
    // is already earned as settled, and celebrate nothing. Everything in
    // `earnedBadges` right now was earned before this device was watching —
    // an upgrade across the build that added the ledger, or a sign-in on a
    // phone whose ledger was just reset — and arming a celebration for it
    // sends "Two weeks. TWO WEEKS." to somebody who did that a month ago.
    //
    // Returns rather than falling through: `plan` would otherwise read the
    // pre-adoption ledger this same pass and arm exactly that push. The next
    // sync (the next puff tap, at the latest) plans against the adopted one.
    if (!settings.milestonesAdopted) {
      onAdopted?.call(journey.earnedBadges);
      return;
    }

    final celebration = MilestoneReminderPlanner.plan(
      earnedBadges: journey.earnedBadges,
      celebratedBadges: settings.celebratedMilestones,
      now: now,
      quietStartHour: settings.quietStartHour,
      quietEndHour: settings.quietEndHour,
      enabled: settings.notificationsOn,
    );
    if (celebration == null) return;

    final fingerprint =
        '${celebration.reminder.id}@${celebration.badgeId}'
        '@${celebration.reminder.at.toIso8601String()}';
    if (fingerprint == _milestoneApplied) return;
    _milestoneApplied = fingerprint;

    await _sink.scheduleOnce(
      celebration.reminder,
      kind: ReminderKind.milestone,
      title: title,
      body: body(celebration.badgeId),
    );
    onScheduled?.call(celebration.badgeId, celebration.covers);
  }

  Future<void> _syncDangerHours(
    JourneyState journey,
    SettingsState settings, {
    required String title,
    required String body,
  }) async {
    final slots = ReminderPlanner.plan(
      logs: journey.days.values,
      quietStartHour: settings.quietStartHour,
      quietEndHour: settings.quietEndHour,
      notificationsOn: settings.notificationsOn,
      fallbackHour: journey.profile.firstPuff?.approximateHour,
      // A window the user set in Settings beats the detected buckets. One
      // nudge, just before the window opens — a three-hour window does not
      // mean three notifications.
      overrideHours: settings.dangerHoursCustom
          ? [settings.dangerStartHour % 24]
          : null,
    );

    final fingerprint = slots
        .map((s) => '${s.id}@${s.hour}:${s.minute}')
        .join(',');
    if (fingerprint == _applied) return;

    _applied = fingerprint;
    await _sink.apply(slots, title: title, body: body);
  }

  Future<void> _syncTrialEnding(
    Entitlement entitlement,
    SettingsState settings, {
    required DateTime now,
    required String title,
    required String body,
  }) async {
    final reminder = TrialReminderPlanner.plan(
      entitlement: entitlement,
      now: now,
      quietStartHour: settings.quietStartHour,
      quietEndHour: settings.quietEndHour,
      enabled: settings.trialReminderOn,
    );
    final fingerprint = reminder == null
        ? _cleared
        : '${reminder.id}@${reminder.at.toIso8601String()}';
    if (fingerprint == _trialApplied) return;

    _trialApplied = fingerprint;
    if (reminder == null) {
      // Converted, cancelled, expired, or the toggle went off: the promise
      // is withdrawn along with the reason for it.
      await _sink.cancel(TrialReminderPlanner.id);
    } else {
      await _sink.scheduleOnce(
        reminder,
        kind: ReminderKind.trial,
        title: title,
        body: body,
      );
    }
  }

  static const _cleared = '<cleared>';
}
