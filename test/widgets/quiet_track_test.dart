import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/features/settings/quiet_hours_band.dart';

/// The quiet window on the danger-hours rail (docs/10 §28). The rail runs
/// noon to noon so the night is one band; these pin the mapping between rail
/// positions and wall-clock hours, and the limits every drag obeys.
void main() {
  group('QuietTrack', () {
    test('the shipped 11 PM – 8 AM sits in the middle of the rail', () {
      final t = QuietTrack.fromHours(23, 8);
      expect(t.start, 11);
      expect(t.end, 20);
      expect(t.length, 9);
      expect(t.startHour, 23);
      expect(t.endHour, 8);
    });

    test('positions map to hours from noon', () {
      expect(QuietTrack.hourAt(0), 12);
      expect(QuietTrack.hourAt(6), 18);
      expect(QuietTrack.hourAt(12), 0);
      expect(QuietTrack.hourAt(18), 6);
      expect(QuietTrack.hourAt(24), 12);
    });

    test('every window that does not cross noon round-trips', () {
      for (final (s, e) in [(23, 8), (21, 7), (0, 6), (13, 14), (12, 11)]) {
        final t = QuietTrack.fromHours(s, e);
        expect((t.startHour, t.endHour), (s, e), reason: '$s → $e');
      }
    });

    test('the start knob never crosses the end, and keeps an hour', () {
      final t = QuietTrack.fromHours(23, 8);
      expect(t.withStart(19).start, 19);
      expect(t.withStart(20).start, 19, reason: 'an hour short of the end');
      expect(t.withStart(25).start, 19);
      expect(t.withStart(-3).start, 0);
      expect(t.withStart(0).end, 20, reason: 'the end stays put');
    });

    test('the end knob never crosses the start, and stops at noon', () {
      final t = QuietTrack.fromHours(23, 8);
      expect(t.withEnd(12).end, 12, reason: 'an hour past the start');
      expect(t.withEnd(0).end, 12);
      expect(t.withEnd(30).end, 24);
      expect(t.withEnd(24).start, 11, reason: 'the start stays put');
    });

    test('a window is never the whole day', () {
      // 24 hours would read as start == end, which the planner takes to
      // mean NO quiet hours — the opposite of what was dragged.
      final t = QuietTrack.fromHours(12, 11); // 23 hours, the longest
      expect(t.withStart(-1).length, 23);
      expect(t.withEnd(25).length, 23);
      final wide = QuietTrack.fromHours(13, 12); // start 1, end 24
      expect(wide.withStart(0).start, 1, reason: 'would make it 24');
    });

    test('sliding keeps the length and stops at the rail ends', () {
      final t = QuietTrack.fromHours(23, 8);
      expect(t.shiftedTo(13), QuietTrack.fromHours(1, 10));
      expect(t.shiftedTo(20), QuietTrack.fromHours(8, 12 + 5));
      expect(t.shiftedTo(20).end, 24);
      expect(t.shiftedTo(-5), QuietTrack.fromHours(12, 21));
      expect(t.shiftedTo(-5).start, 0);
    });

    test('a stored start equal to its end opens as the shortest span', () {
      // "No quiet hours" cannot be drawn and nothing in the app writes it;
      // the rail must still open on something rather than throw.
      final t = QuietTrack.fromHours(8, 8);
      expect(t.length, 1);
      expect(t.startHour, 8);
    });

    test('a stored window across noon is pulled back so it fits', () {
      final t = QuietTrack.fromHours(10, 14);
      expect(t.end, 24);
      expect(t.length, 4);
      expect(t.endHour, 12);
    });

    test('equality is by span', () {
      expect(QuietTrack.fromHours(23, 8), QuietTrack.fromHours(23, 8));
      expect(QuietTrack.fromHours(23, 8), isNot(QuietTrack.fromHours(22, 8)));
      expect(
        QuietTrack.fromHours(23, 8).hashCode,
        QuietTrack.fromHours(23, 8).hashCode,
      );
    });
  });
}
