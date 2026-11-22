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

  test('a plain morning\'s whole text is shown too, not cut to one line', () {
    // The plain 09:00 morning on plan days 2 and 3 rides `ReminderKind.checkin`,
    // like the evening, and its body is a sentence or two: Android collapses a
    // plain body to one line, which would cut it mid-clause in the shade.
    const body =
        'Today\'s line is 12 puffs. Log each one as it happens, the first one '
        'too.';
    final style = android(ReminderKind.checkin, body).styleInformation;
    expect(style, isA<BigTextStyleInformation>());
    expect((style! as BigTextStyleInformation).bigText, body);
  });

  test('the shared channel is named for the mornings as well as the evenings, '
      'and its id never moves', () {
    // The id is the user's own switch in system settings and importance is
    // immutable once created; only the name and description update in place,
    // and only through the scheduler's explicit channel creation.
    for (final kind in [ReminderKind.checkin, ReminderKind.program]) {
      final details = android(kind);
      expect(details.channelId, 'evening_checkins', reason: kind.name);
      expect(details.channelName, 'Check-ins', reason: kind.name);
      expect(
        details.channelDescription,
        'A morning or evening note about your plan.',
        reason: kind.name,
      );
    }
  });

  test('the notification names the channel from the one constant the scheduler '
      'creates, so the two cannot drift', () {
    const shared = ReminderScheduler.checkinChannel;
    for (final kind in [ReminderKind.checkin, ReminderKind.program]) {
      final details = android(kind);
      expect(details.channelId, shared.id, reason: kind.name);
      expect(details.channelName, shared.name, reason: kind.name);
      expect(details.channelDescription, shared.description, reason: kind.name);
      expect(details.importance, shared.importance, reason: kind.name);
    }
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
