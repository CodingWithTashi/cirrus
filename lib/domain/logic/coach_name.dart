/// Syntactic validation for a user-chosen coach name. Pure Dart.
///
/// Layer one of two. This runs as they type: instant, offline, and the only
/// check that can say *why* it refused. Layer two is `nameGuard.ts` on the
/// server, which refuses impersonation and abuse and deliberately explains
/// nothing — a denylist that explains itself is a denylist you can enumerate.
///
/// There is no layer three. `ai/moderation.ts`'s `classify()` was considered
/// and rejected: it is fail-CLOSED, so a model outage would stop every user
/// naming their coach on the screen immediately before the paywall; it costs
/// most of a second on a CTA; it does not work offline when everything else
/// here does; and on a string of one to twenty characters it has almost no
/// context to judge with.
library;

enum CoachNameError { empty, tooLong, badCharacters }

abstract final class CoachName {
  /// Twenty is what the chat header and `requireText` on the server both
  /// assume, and it is counted in grapheme clusters rather than code units so
  /// an emoji-free accented name is not cut short by its own combining marks.
  static const int maxLength = 20;

  /// Letters (any script), combining marks, digits, spaces, hyphen and
  /// apostrophe. Everything else is out — including emoji, which the chat
  /// header cannot lay out, and the format characters below.
  static final RegExp _allowed = RegExp(
    r"^[\p{L}\p{M}\p{N} \-']+$",
    unicode: true,
  );

  /// Cf (bidi overrides, zero-width joiners) and Co (private use). Invisible
  /// by design, which is exactly why a name is the wrong place for them: a
  /// right-to-left override can make a stored name render as something else
  /// entirely in a support ticket.
  static final RegExp _invisible = RegExp(r'[\p{Cf}\p{Co}]', unicode: true);

  /// The name as it should be stored: trimmed, with internal runs of
  /// whitespace collapsed so "Wren    " and "Wren" cannot both exist.
  static String normalize(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Null when [raw] is usable.
  static CoachNameError? validate(String raw) {
    final name = normalize(raw);
    if (name.isEmpty) return CoachNameError.empty;
    // Counted the way a person counts it, not the way UTF-16 does.
    if (name.runes.length > maxLength) return CoachNameError.tooLong;
    if (_invisible.hasMatch(name)) return CoachNameError.badCharacters;
    if (!_allowed.hasMatch(name)) return CoachNameError.badCharacters;
    // A name that is only punctuation is not a name; it is also what an
    // otherwise-empty submission looks like after normalization.
    if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(name)) {
      return CoachNameError.badCharacters;
    }
    return null;
  }
}
