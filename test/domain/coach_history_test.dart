import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/coach_history.dart';
import 'package:last_puff/domain/models/models.dart';

/// QA L1 (Aug 31 2026, production): after a force-stop and cold start, a
/// reply rendered ABOVE the message that prompted it. `aiCoachChat` writes
/// the user turn and the reply in one batch with the same server timestamp,
/// and the restore ordered by that timestamp alone — a tie has no defined
/// order, so the pair came back reversed. Live order was fine.
void main() {
  final t = DateTime(2026, 8, 31, 9, 12);

  test('a same-instant user/reply pair keeps the user first', () {
    final restored = [
      CoachMessage.ember(
        id: 'h_b',
        template: CoachTemplate.generic1,
        text: 'day one — the hardest part is behind you',
        sentAt: t,
      ),
      CoachMessage.user(id: 'h_a', text: 'hey, day one', sentAt: t),
    ];

    final ordered = CoachHistory.ordered(restored);

    expect(ordered.map((m) => m.id), ['h_a', 'h_b']);
  });

  test('distinct timestamps sort by time, and the sort is stable', () {
    final restored = [
      CoachMessage.user(
        id: 'u2',
        text: 'later',
        sentAt: t.add(const Duration(minutes: 5)),
      ),
      CoachMessage.ember(
        id: 'e1',
        template: CoachTemplate.generic1,
        text: 'first reply',
        sentAt: t,
      ),
      CoachMessage.user(id: 'u1', text: 'first', sentAt: t),
      CoachMessage.ember(
        id: 'e2',
        template: CoachTemplate.generic1,
        text: 'second reply',
        sentAt: t.add(const Duration(minutes: 5)),
      ),
    ];

    expect(CoachHistory.ordered(restored).map((m) => m.id), [
      'u1',
      'e1',
      'u2',
      'e2',
    ]);
  });

  test('a turn whose server timestamp has not resolved keeps its place', () {
    // A turn written moments ago can come back with `ts` still null. It is
    // the newest thing there is; it belongs at the end, in arrival order.
    final restored = [
      CoachMessage.user(id: 'u1', text: 'first', sentAt: t),
      const CoachMessage.user(id: 'u9', text: 'just now'),
      const CoachMessage.ember(
        id: 'e9',
        template: CoachTemplate.generic1,
        text: 'just now too',
      ),
    ];

    expect(CoachHistory.ordered(restored).map((m) => m.id), ['u1', 'u9', 'e9']);
  });
}
