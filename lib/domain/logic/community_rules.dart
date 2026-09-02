/// The client-side half of the community policy (docs/03 §9), applied while
/// the composer is still open.
///
/// Two refusals, both deterministic, both mirrored on the server:
///
/// * [slurs] — the exact list `functions/src/ai/prefilter.ts` blocks with,
///   matched the same way (whole words; lowercased, diacritics folded, leet
///   mapped). `test/domain/community_rules_test.dart` reads the TypeScript
///   file and fails if the two lists ever differ.
/// * [sourcingPhrases] — where-to-buy and for-sale talk, whole phrases only.
///
/// Bare brand names are deliberately NOT a refusal. "Threw my juul in the
/// bin, day 1" is the most common sentence in a quit community, and only the
/// model can tell it from praise — which it blocks (see the moderation
/// prompt). [mentionsBrand] exists for the fake backend, which cannot judge
/// tone and so holds any brand mention the way the demo always has.
///
/// Why the client checks at all when the server is the guarantee: the Sep 1
/// field test (docs/09 issue 6) asked for a "no" BEFORE posting, not a "not
/// published" after. With this, a slur is refused under the text box with the
/// words still there to edit; without it the post would pop the composer,
/// appear in the feed for a beat, and then come back blocked. `createPost`
/// runs the same prefilter at the door, so a stale or patched client still
/// cannot land one in Firestore.
///
/// The normalizer approximates the server's NFD-and-strip with a fold table
/// for the Latin letters the five locales use plus a strip of combining marks
/// (so decomposed input matches too). The server stays the exact floor; the
/// residual gap shows as an honest "Not published" after the pop, never as a
/// published slur.
library;

enum CommunityRuleViolation {
  /// A slur or hate term — refused outright, on both sides.
  slur,

  /// Where-to-buy or for-sale talk — refused, per the kindness note.
  sourcing,
}

abstract final class CommunityRules {
  /// Verbatim from `prefilter.ts` (`SLURS`). Every entry must be unambiguous
  /// in all five app locales; see that file for the false friends left out.
  static const List<String> slurs = [
    'nigger',
    'niggers',
    'nigga',
    'niggas',
    'faggot',
    'faggots',
    'kike',
    'kikes',
    'spic',
    'spics',
    'wetback',
    'wetbacks',
    'gook',
    'gooks',
    'tranny',
    'trannies',
    'beaner',
    'beaners',
    'towelhead',
    'towelheads',
    'raghead',
    'ragheads',
  ];

  /// Whole phrases, so "unplug for a while" does not trip "plug for".
  static const List<String> sourcingPhrases = [
    'where to buy',
    'for sale',
    'plug for',
    'best flavor to buy',
    'best flavour to buy',
    'dm me for',
  ];

  /// Not a refusal on their own — see the library note.
  static const List<String> brands = [
    'elfbar',
    'elf bar',
    'geekbar',
    'geek bar',
    'juul',
    'vuse',
    'lostmary',
    'lost mary',
  ];

  /// The first rule the text breaks, or null when it is fine to send.
  static CommunityRuleViolation? check(String text) {
    final normalized = _normalize(text);
    if (_slurMatchers.any((m) => m.hasMatch(normalized))) {
      return CommunityRuleViolation.slur;
    }
    if (_sourcingMatchers.any((m) => m.hasMatch(normalized))) {
      return CommunityRuleViolation.sourcing;
    }
    return null;
  }

  /// Whether a brand name appears as a word. Tone is the model's call.
  static bool mentionsBrand(String text) {
    final normalized = _normalize(text);
    return _brandMatchers.any((m) => m.hasMatch(normalized));
  }

  /// The fake backend's verdict: anything the real one would refuse or hold.
  static bool violates(String text) =>
      check(text) != null || mentionsBrand(text);

  /// Lowercase, fold the diacritics of the Latin letters the five locales
  /// use, strip any combining marks left over (decomposed input), then undo
  /// the usual leetspeak. Matching only — the text itself is never altered.
  static String _normalize(String text) {
    final buffer = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      buffer.write(_fold[rune] ?? String.fromCharCode(rune));
    }
    return buffer.toString().replaceAll(_combiningMarks, '');
  }

  /// U+0300–U+036F, what the server's `normalize('NFD')` strips.
  static final RegExp _combiningMarks = RegExp('[̀-ͯ]');

  /// Only letters NFD decomposes, so this folds no more than the server
  /// does: ø, đ, ł, ß and æ have no decomposition and stay as they are.
  static const Map<String, String> _foldSpec = {
    'a': 'àáâãäåāăąǎ',
    'c': 'çćĉċč',
    'd': 'ď',
    'e': 'èéêëēĕėęě',
    'g': 'ĝğġģǧ',
    'h': 'ĥ',
    'i': 'ìíîïĩīĭįǐ',
    'j': 'ĵ',
    'k': 'ķǩ',
    'l': 'ĺļľ',
    'n': 'ñńņň',
    'o': 'òóôõöōŏőǒ',
    'r': 'ŕŗř',
    's': 'śŝşš',
    't': 'ţť',
    'u': 'ùúûüũūŭůűųǔǚ',
    'w': 'ŵ',
    'y': 'ýÿŷ',
    'z': 'źżž',
    // Leetspeak, same map as the server.
    'o0': '0',
    'i1': '1',
    'e3': '3',
    'a4': '4',
    's5': '5',
    't7': '7',
    'a@': '@',
    's\$': '\$',
  };

  static final Map<int, String> _fold = {
    for (final entry in _foldSpec.entries)
      for (final rune in entry.value.runes) rune: entry.key[0],
  };

  /// Word-boundary matchers with explicit Unicode lookarounds, as on the
  /// server: a term matches only when not glued to another letter or digit
  /// on either side. "Scunthorpe" stays innocent; "you CUNT" would not.
  static RegExp _wholeWord(String term) => RegExp(
    '(?<![\\p{L}\\p{N}])${RegExp.escape(term)}(?![\\p{L}\\p{N}])',
    unicode: true,
  );

  static final List<RegExp> _slurMatchers = [
    for (final term in slurs) _wholeWord(term),
  ];
  static final List<RegExp> _sourcingMatchers = [
    for (final term in sourcingPhrases) _wholeWord(term),
  ];
  static final List<RegExp> _brandMatchers = [
    for (final term in brands) _wholeWord(term),
  ];
}
