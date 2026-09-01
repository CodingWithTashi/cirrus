import '../models/models.dart';

/// Ordering for a restored coach transcript.
///
/// `aiCoachChat` writes the user turn and Ember's reply in ONE batch, so
/// both carry the same server timestamp, and a sort on the timestamp alone
/// has no defined order for the pair — after a cold restart the reply
/// rendered above the message that prompted it (QA L1, Aug 31 2026).
///
/// The rule: by time, then user before Ember at the same instant (a reply
/// cannot precede what it replies to), and a turn whose server timestamp
/// has not resolved yet (`sentAt == null`, written moments ago) goes last
/// in arrival order. Stable, so equal keys keep the order they came in.
abstract final class CoachHistory {
  static List<CoachMessage> ordered(List<CoachMessage> messages) {
    final indexed = [
      for (var i = 0; i < messages.length; i++) (i, messages[i]),
    ];
    indexed.sort((a, b) {
      final ta = a.$2.sentAt;
      final tb = b.$2.sentAt;
      if (ta == null || tb == null) {
        if (ta == null && tb == null) return a.$1.compareTo(b.$1);
        return ta == null ? 1 : -1;
      }
      final byTime = ta.compareTo(tb);
      if (byTime != 0) return byTime;
      final byRole = _rank(a.$2.role).compareTo(_rank(b.$2.role));
      if (byRole != 0) return byRole;
      return a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }

  static int _rank(CoachRole role) => role == CoachRole.user ? 0 : 1;
}
