import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/api/firebase/reminder_scheduler.dart';
import 'package:last_puff/domain/logic/reminder_planner.dart';

/// How each kind of reminder is presented by the OS. A notification's channel is
/// the user's own switch in system settings, so a message filed under the wrong
/// one (the old `_ =>` fallback filed anything new under "Trial reminders") is
/// a message somebody can only silence by silencing something else.
void main() {
  AndroidNotificationDetails android(ReminderKind kind, [String body = 'b']) =>
      ReminderScheduler.oneShotDetails(kind, body).android!;

  test('a program message shares the evening check-in\'s channel: it takes over '
      'its slot, so one switch in system settings governs both', () {
    expect(android(ReminderKind.program).channelId, 'evening_checkins');
    expect(
      android(ReminderKind.program).channelId,
      android(ReminderKind.checkin).channelId,
    );
  });

  test('a program message is never filed under Trial reminders', () {
    expect(android(ReminderKind.program).channelId, isNot('trial_reminders'));
    expect(
      android(ReminderKind.program).channelName,
      isNot(android(ReminderKind.trial).channelName),
    );
  });

  test('its whole text is shown, not cut to one line', () {
    // Android collapses a plain body to a single line; a message is a sentence
    // or two. The expanded text must be the body, whatever its length.
    const body =
        'The urge on waking is habit as much as nicotine. Change your first '
        'ten minutes.';
    final style = android(ReminderKind.program, body).styleInformation;
    expect(style, isA<BigTextStyleInformation>());
    expect((style! as BigTextStyleInformation).bigText, body);
  });

  test('the other kinds keep their own channels', () {
    expect(android(ReminderKind.milestone).channelId, 'milestone_celebrations');
    expect(android(ReminderKind.trial).channelId, 'trial_reminders');
    expect(android(ReminderKind.checkin).channelId, 'evening_checkins');
  });

  test('every kind has details, and iOS is always given some', () {
    for (final kind in ReminderKind.values) {
      final d = ReminderScheduler.oneShotDetails(kind, 'b');
      expect(d.android, isNotNull, reason: kind.name);
      expect(d.iOS, isNotNull, reason: kind.name);
    }
  });
}
