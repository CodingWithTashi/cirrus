import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/pending_puffs.dart';

/// The outbox codec and the cursor rule.
///
/// Pure — no container, no platform. This is the contract the Kotlin
/// `PuffWidgetProvider` and the Swift `LogPuffIntent` write against, so it is
/// deliberately spelled out rather than round-tripped through Dart alone.
void main() {
  PendingPuff puff(int seq, {int delta = 1, String? id, DateTime? at}) =>
      PendingPuff(
        id: id ?? 'e$seq',
        seq: seq,
        at: at ?? DateTime(2026, 9, 4, 21, 40),
        delta: delta,
      );

  group('the wire shape', () {
    test('round-trips a mixed queue', () {
      final events = [
        puff(1),
        puff(2, delta: -1, at: DateTime(2026, 9, 3, 23, 58)),
        puff(3, at: DateTime(2026, 9, 4, 8)),
      ];

      final decoded = PendingPuffs.decode(PendingPuffs.encode(events));

      expect(decoded.map((e) => e.seq), [1, 2, 3]);
      expect(decoded.map((e) => e.delta), [1, -1, 1]);
      expect(decoded[1].at, DateTime(2026, 9, 3, 23, 58));
    });

    test('the encoded keys are the short ones the native side writes', () {
      final json =
          jsonDecode(PendingPuffs.encode([puff(7)])) as Map<String, dynamic>;

      expect(json['v'], PendingPuffs.schemaVersion);
      final event = (json['e'] as List).single as Map<String, dynamic>;
      expect(event.keys.toSet(), {'i', 's', 't', 'd'});
      expect(event['t'], isA<int>(), reason: 'epoch millis, not a string');
    });

    test('a timestamp decodes to a LOCAL DateTime', () {
      // The day key and the hour bucket are computed with `DateTime(y, m, d)`
      // and `.hour`, which read local wall-clock. A UTC-flagged DateTime here
      // would file a late-evening puff on the wrong day for half the world.
      final at = DateTime(2026, 9, 4, 23, 58);
      final decoded = PendingPuffs.decode(
        PendingPuffs.encode([puff(1, at: at)]),
      );

      expect(decoded.single.at.isUtc, isFalse);
      expect(decoded.single.at, at);
    });
  });

  group('an unreadable queue is an empty queue', () {
    test('never throws, whatever it is handed', () {
      for (final raw in <String?>[
        null,
        '',
        'not json at all',
        '{"v":1,"e":',
        '[]',
        '{"v":1}',
        '{"v":1,"e":{}}',
        '{"v":2,"e":[{"i":"a","s":1,"t":0,"d":1}]}',
      ]) {
        expect(PendingPuffs.decode(raw), isEmpty, reason: 'raw: $raw');
      }
    });

    test('drops malformed events but keeps the good ones beside them', () {
      const raw =
          '{"v":1,"e":['
          '{"i":"a","s":1,"t":100,"d":1},'
          '{"i":"","s":2,"t":100,"d":1},' // empty id
          '{"i":"c","s":3,"t":100,"d":5},' // a magnitude, not a tap
          '{"i":"d","s":"4","t":100,"d":1},' // seq is not an int
          '{"i":"e","s":5,"t":100,"d":-1}'
          ']}';

      expect(PendingPuffs.decode(raw).map((e) => e.id), ['a', 'e']);
    });

    test('tolerates an unknown field a newer build might add', () {
      const raw = '{"v":1,"e":[{"i":"a","s":1,"t":100,"d":1,"src":"lock"}]}';

      expect(PendingPuffs.decode(raw).single.id, 'a');
    });

    test('caps a runaway queue', () {
      final huge = [for (var i = 1; i <= PendingPuffs.maxEvents + 50; i++) puff(i)];

      expect(
        PendingPuffs.decode(PendingPuffs.encode(huge)),
        hasLength(PendingPuffs.maxEvents),
      );
    });
  });

  group('the cursor', () {
    test('skips everything at or below it', () {
      final all = [puff(1), puff(2), puff(3), puff(4)];

      expect(PendingPuffs.pending(all, 2).map((e) => e.seq), [3, 4]);
      expect(PendingPuffs.pending(all, 4), isEmpty);
      expect(PendingPuffs.pending(all, 0).map((e) => e.seq), [1, 2, 3, 4]);
    });

    test('orders by seq, whatever order the queue was stored in', () {
      // Ordering is not cosmetic: the over-limit crossing, the repair token
      // and the slip flow all turn on WHICH puff crossed the line.
      final shuffled = [puff(3), puff(1), puff(4), puff(2)];

      expect(PendingPuffs.pending(shuffled, 0).map((e) => e.seq), [1, 2, 3, 4]);
    });

    test('orders by seq even when two taps share a millisecond', () {
      final same = DateTime(2026, 9, 4, 21, 40, 0, 500);
      final all = [puff(9, at: same), puff(8, at: same)];

      expect(PendingPuffs.pending(all, 0).map((e) => e.seq), [8, 9]);
    });

    test('a repeated id inside one decode applies once', () {
      final all = [puff(1, id: 'dup'), puff(2, id: 'dup'), puff(3)];

      expect(PendingPuffs.pending(all, 0).map((e) => e.seq), [1, 3]);
    });
  });
}
