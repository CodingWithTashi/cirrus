import 'dart:convert';

import 'package:flutter/foundation.dart';

/// One puff logged on the home-screen widget, waiting for the app to wake up.
class PendingPuff {
  const PendingPuff({
    required this.id,
    required this.seq,
    required this.at,
    required this.delta,
  });

  /// Opaque, minted natively. Only used to collapse a duplicate inside one
  /// decode; ordering and idempotency ride on [seq].
  final String id;

  /// Strictly increasing, minted from the native counter. This is the spine:
  /// it orders events that share a millisecond, and it is what the cursor
  /// compares against.
  final int seq;

  /// Local instant of the tap. `DateTime.fromMillisecondsSinceEpoch` yields a
  /// local `DateTime`, which is what `JourneyState.dateKey` and `LpDate.hour`
  /// require — they truncate with `DateTime(y, m, d)` and never round-trip
  /// through UTC.
  final DateTime at;

  /// `+1` or `-1`. Never a magnitude: one tap is one puff, which is the rule
  /// `log_feedback.dart` exists to enforce after an 18-tap burst once logged
  /// 68 puffs.
  final int delta;

  Map<String, dynamic> toJson() => {
    'i': id,
    's': seq,
    't': at.millisecondsSinceEpoch,
    'd': delta,
  };

  static PendingPuff? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['i'];
    final seq = raw['s'];
    final at = raw['t'];
    final delta = raw['d'];
    if (id is! String || id.isEmpty) return null;
    if (seq is! int) return null;
    // `num`, not `int`: JSON has one number type, and a writer that produces
    // `1788580827468.0` is carrying exactly the same instant. Rejecting it
    // would drop the event silently AND strand it — a dropped event never
    // advances the cursor, so it stays pending, keeps inflating the widget's
    // count for ever, and eventually fills the queue.
    if (at is! num) return null;
    if (delta != 1 && delta != -1) return null;
    return PendingPuff(
      id: id,
      seq: seq,
      at: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
      delta: delta as int,
    );
  }

  @override
  String toString() => 'PendingPuff(#$seq, ${at.toIso8601String()}, $delta)';
}

/// The outbox: puffs logged on the home screen while the app was not running.
///
/// **Why a queue and not a write.** `journeys/{uid}` is persisted with a
/// whole-document `set()` on every optimistic mutation, so a second writer —
/// a widget process holding its own stale copy — would silently destroy
/// whatever the app had done since. Firestore's offline mutation queue also
/// lives inside the Flutter process, which a widget tap does not start. So the
/// widget writes an *intent* here and the app applies it. `docs/03 §2` calls
/// for exactly this: "widget logs queue via App Group storage and flush on
/// next app/widget process wake."
///
/// **Why every event carries its own timestamp.** A tap at 23:58 drained at
/// 00:05 belongs to yesterday's day key and to hour bucket 23. The danger-hour
/// engine reads those buckets, so stamping them with the drain time would
/// teach the app the wrong risky hour and file the puff on the wrong side of
/// midnight.
///
/// **Why a cursor and not "delete what you applied".** Neither
/// `SharedPreferences` nor `UserDefaults` offers compare-and-swap, so any key
/// written by both processes is a read-modify-write race: a `+` tapped while
/// the app was rewriting the queue would simply vanish. Every key here has
/// **exactly one writer**, which removes the race by construction rather than
/// narrowing it:
///
/// | Key | Written by | Read by |
/// |---|---|---|
/// | [outboxKey] | native only (append, and prune below the cursor) | Dart |
/// | [seqKey] | native only | native |
/// | [cursorKey] | Dart only | both |
///
/// Dart never touches the outbox. It reads it, applies what is above the
/// cursor, and publishes a new cursor.
abstract final class PendingPuffs {
  /// The event log. Mirrored by the Kotlin `PuffWidgetProvider` and the Swift
  /// `LogPuffIntent` — change any of these three names in all three places.
  static const String outboxKey = 'lp.outbox';

  /// Highest [PendingPuff.seq] the app has durably taken responsibility for.
  static const String cursorKey = 'lp.cursor';

  /// The native monotonic minter. Named here so the contract lives in one
  /// place; nothing in Dart reads or writes it.
  static const String seqKey = 'lp.seq';

  static const int schemaVersion = 1;

  /// A ceiling on what one drain can be handed. Far above honest use — a heavy
  /// day is ~200 puffs and the app is opened daily — and it bounds the work
  /// the launch path can be asked to do.
  static const int maxEvents = 1000;

  /// Never throws. Absent, corrupt, truncated or from another schema all
  /// decode to the empty list, which is the stance every persistence file in
  /// this folder takes: an unreadable queue is an empty queue.
  static List<PendingPuff> decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final json = jsonDecode(raw);
      if (json is! Map || json['v'] != schemaVersion) return const [];
      final events = json['e'];
      if (events is! List) return const [];
      return [
        for (final entry in events.take(maxEvents)) ?PendingPuff.fromJson(entry),
      ];
    } on Object {
      return const [];
    }
  }

  /// The outbox never gets written by production Dart — the native side owns
  /// that key. This exists so the tests and the two native implementations
  /// have one written-down contract to agree on.
  @visibleForTesting
  static String encode(List<PendingPuff> events) => jsonEncode({
    'v': schemaVersion,
    'e': [for (final event in events) event.toJson()],
  });

  /// Everything after [cursor], deduplicated by id, ordered by [seq].
  ///
  /// Ascending order is not cosmetic: the over-limit crossing, the repair
  /// token and the slip flow all turn on *which* puff crossed the line, so
  /// replaying out of order burns the token on the wrong puff.
  static List<PendingPuff> pending(List<PendingPuff> all, int cursor) {
    final seen = <String>{};
    final fresh = [
      for (final event in all)
        if (event.seq > cursor && seen.add(event.id)) event,
    ];
    return fresh..sort((a, b) => a.seq.compareTo(b.seq));
  }
}
