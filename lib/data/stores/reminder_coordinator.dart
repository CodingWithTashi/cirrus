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
/// Two independent schedules live here, each with its own fingerprint: the
/// repeating danger-hour nudges (ids 1000–1023) and the one-shot trial-ending
/// reminder (id 2000). Independent on purpose — a puff tap must never wipe
/// the trial reminder, which is exactly what a shared cancel-all used to do.
class ReminderCoordinator {
  ReminderCoordinator(this._sink);

  final ReminderSink _sink;

  /// Fingerprint of the last applied danger-hour plan. Cheaper and more
  /// honest than comparing journeys: two different journeys that produce the
  /// same slots genuinely need no reschedule.
  String? _applied;

  /// Fingerprint of the last applied trial-ending reminder.
  String? _trialApplied;

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
    DateTime Function() now = DateTime.now,
  }) async {
    // Signed out, or notifications declined: clear the device rather than
    // simply stopping — yesterday's schedule would otherwise keep firing at
    // someone who has explicitly opted out. Everything goes, both schedules.
    if (journey == null || !settings.notificationsOn) {
      if (_applied != _cleared || _trialApplied != _cleared) {
        _applied = _cleared;
        _trialApplied = _cleared;
        await _sink.cancelAll();
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
      await _sink.scheduleOnce(reminder, title: title, body: body);
    }
  }

  static const _cleared = '<cleared>';
}
