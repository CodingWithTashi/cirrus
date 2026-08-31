/// Cleanup for the one onboarding answer written in the user's own words.
/// Pure Dart.
///
/// The sibling of [CoachName], and the differences are deliberate. A name is
/// one word rendered into a chat header, so it bans emoji and punctuation and
/// explains every refusal as you type. This is a sentence — it is allowed to
/// look like one, and the only thing it refuses is length.
///
/// **This is hygiene, not a security boundary.** The text lands in a
/// client-owned document (`journeys/{uid}`), so by the time the server sees it
/// nothing here can be trusted: `journeyCodec.ts` sanitizes it again on decode,
/// the same treatment `coachName` and `moodNote` get, and the prompt fences it
/// as background rather than instruction. A string that ends up in a system
/// prompt is checked where it is read, not only where it is typed.
library;

enum WhyWordsError { tooLong }

abstract final class WhyWords {
  /// Two hundred characters is a couple of sentences — long enough to say a
  /// real thing, short enough that it costs nothing in the user card, which
  /// carries a ~1.5K token budget for everything.
  ///
  /// Counted in runes rather than code units, so an answer with emoji in it
  /// is not cut off at half the length it looks.
  static const int maxLength = 200;

  /// Whitespace of every kind, including the newlines a multi-line paste
  /// carries. Matched one at a time rather than in runs — see [normalize].
  static final RegExp _whitespace = RegExp(r'\s');

  /// Control (Cc), format (Cf) and private-use (Co) characters. Invisible by
  /// design, which is exactly why a stored string is the wrong place for
  /// them: a right-to-left override can make this text render as something
  /// else entirely wherever it is later displayed.
  static final RegExp _invisible = RegExp(r'[\p{Cc}\p{Cf}\p{Co}]', unicode: true);

  /// Runs of the spaces left behind once the above have gone.
  static final RegExp _runs = RegExp(r' {2,}');

  /// The answer as it should be stored.
  ///
  /// The order of these three steps is load-bearing. Newlines and tabs are
  /// themselves control characters, so stripping [_invisible] first would weld
  /// the words on either side of a line break together. Each whitespace
  /// character becomes a single space, THEN the remaining invisibles go, THEN
  /// the runs collapse — which is also what stops a stripped control character
  /// leaving a double space behind it.
  static String normalize(String raw) => raw
      .replaceAll(_whitespace, ' ')
      .replaceAll(_invisible, '')
      .replaceAll(_runs, ' ')
      .trim();

  /// What to persist: the normalized answer, or **null when they skipped**.
  ///
  /// Null rather than an empty string because the two mean different things.
  /// Null is "never answered"; an empty string would round-trip through the
  /// codec as a value and print an empty line into Ember's user card as
  /// though the user had said something.
  static String? stored(String raw) {
    final text = normalize(raw);
    return text.isEmpty ? null : text;
  }

  /// Null when [raw] is usable — which includes empty, because the question
  /// is optional and declining it is a valid answer.
  static WhyWordsError? validate(String raw) =>
      normalize(raw).runes.length > maxLength ? WhyWordsError.tooLong : null;
}
