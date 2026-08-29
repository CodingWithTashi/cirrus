import '../../domain/logic/reminder_planner.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/journey_state.dart';
import '../api/firebase/reminder_scheduler.dart';
import 'settings_store.dart';

/// Keeps the device's notification schedule in step with the journey and the
/// user's settings.
///
/// This runs on every journey mutation — which is once per puff tap — so the
/// important behaviour is the one that does NOTHING. An unchanged plan must
/// not re-hit the OS scheduler, or a heavy logging day would cancel and
/// rebuild the same alarms hundreds of times.
class ReminderCoordinator {
  ReminderCoordinator(this._sink);

  final ReminderSink _sink;

  /// Fingerprint of the last applied plan. Cheaper and more honest than
  /// comparing journeys: two different journeys that produce the same slots
  /// genuinely need no reschedule.
  String? _applied;

  Future<void> sync({
    required JourneyState? journey,
    required SettingsState settings,
    required String title,
    required String body,
  }) async {
    // Signed out, or notifications declined: clear the device rather than
    // simply stopping — yesterday's schedule would otherwise keep firing at
    // someone who has explicitly opted out.
    if (journey == null || !settings.notificationsOn) {
      if (_applied != _cleared) {
        _applied = _cleared;
        await _sink.cancelAll();
      }
      return;
    }

    final slots = ReminderPlanner.plan(
      logs: journey.days.values,
      quietStartHour: settings.quietStartHour,
      quietEndHour: settings.quietEndHour,
      notificationsOn: settings.notificationsOn,
      fallbackHour: journey.profile.firstPuff?.approximateHour,
    );

    final fingerprint = slots.map((s) => '${s.id}@${s.hour}:${s.minute}').join(',');
    if (fingerprint == _applied) return;

    _applied = fingerprint;
    await _sink.apply(slots, title: title, body: body);
  }

  static const _cleared = '<cleared>';
}
