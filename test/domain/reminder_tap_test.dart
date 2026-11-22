import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/quit_program.dart';
import 'package:last_puff/domain/logic/reminder_planner.dart';
import 'package:last_puff/domain/logic/reminder_tap.dart';

/// What a local notification carries so a tap can say which one it was.
void main() {
  test('a tap with everything round-trips', () {
    const tap = ReminderTap(ReminderKind.program,
        slot: ProgramSlot.morning, planDay: 2, message: ProgramMessage.d1am);
    expect(tap.encode(), 'program|morning|2|d1am');
    expect(ReminderTap.decode(tap.encode()), tap);
  });

  test('a plain morning has no message field', () {
    const tap = ReminderTap(ReminderKind.checkin,
        slot: ProgramSlot.morning, planDay: 3);
    expect(tap.encode(), 'checkin|morning|3|');
    expect(ReminderTap.decode('checkin|morning|3|'), tap);
  });

  test('a bare kind is what danger, trial and milestone still carry', () {
    expect(const ReminderTap(ReminderKind.danger).encode(), 'danger');
  });

  test('a 1.0.36 payload, armed before the upgrade, still decodes', () {
    expect(
        ReminderTap.decode('checkin'), const ReminderTap(ReminderKind.checkin));
  });

  test('an unreadable field is dropped, the kind is kept', () {
    expect(ReminderTap.decode('program|dusk|two|d99pm'),
        const ReminderTap(ReminderKind.program));
  });

  test('an unknown kind, empty or null is no tap', () {
    expect(ReminderTap.decode('nudge|morning|2|'), isNull);
    expect(ReminderTap.decode(''), isNull);
    expect(ReminderTap.decode(null), isNull);
  });
}
