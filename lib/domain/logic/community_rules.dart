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

/// Why a post is too thin to publish. Two kinds, because they need two
/// different sentences: one asks for more, the other asks for words.
///
/// Neither is a rule violation — nobody has done anything wrong — so the
/// composer renders these in its neutral tone, never the red one.
enum PostQualityIssue {
  /// Not enough there yet: too short, or not enough words to act on.
  tooShort,

  /// Long enough, but it is the same thing over and over ("aaaaaaaaaaaaaa",
  /// "help help help help") or has no letters in it at all.
  repetitive,
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

/// Is there actually a message here?
///
/// Separate from [CommunityRules] on purpose: that class answers "may this be
/// said", this one answers "was anything said". A slur is refused forever; a
/// two-character post is refused until the person types a few more words, and
/// the two must never wear the same styling or the same tone.
///
/// It exists because the panic flow opens the composer **pre-tagged `sos`**,
/// so publishing is one tap away with the tag already chosen — and a live SOS
/// pins to the top of the feed for an hour. `"a"` used to publish, and it
/// pinned. The bar is deliberately low enough that a real cry for help clears
/// it: "help me please" and "i want to vape" both pass.
///
/// Mirrored value-for-value by `postQuality` in `functions/src/ai/prefilter.ts`
/// and pinned across the two by `test/domain/post_quality_test.dart`, which
/// reads the TypeScript file — the same discipline
/// `test/domain/community_rules_test.dart` applies to the slur lists. The
/// server is the floor; this exists so the refusal happens under the text box
/// with the words still there to edit, rather than as "not published" after
/// the composer has closed.
///
/// **Assumes a space-separated script.** All five shipped locales
/// (en/es/fr/de/pt) are; the word rules would have to become script-aware
/// before shipping Chinese, Japanese or Thai.
abstract final class PostQuality {
  /// A post is a thing somebody is meant to answer, so it asks for a
  /// sentence.
  static const int minPostChars = 12;

  /// …but an SOS asks for less.
  ///
  /// This gate is reached from the composer the panic flow opens PRE-TAGGED
  /// `sos`, by somebody at high craving intensity with shaking hands, and a
  /// wrongly-refused cry for help is the most expensive false positive in
  /// the app — far more expensive than the junk post it would have caught.
  /// Ten lets "i need help" (11) and "help me now" (11) through; twelve
  /// refused both, which nobody noticed because the accept list happened to
  /// start at "help me please" (14).
  ///
  /// Only the character floor moves. Every anti-noise rule below applies to
  /// an SOS unchanged, so "a", "asdf", "..." and "😭😭😭" are still refused.
  static const int minSosChars = 10;

  /// A reply is allowed to be "thanks". It only has to be *words*.
  static const int minReplyChars = 6;

  static const int minPostWords = 3;

  /// Kills a wall of one word repeated. Two, not three, so "i cant i cant"
  /// still reaches the feed.
  static const int minDistinctWords = 2;

  /// Letters, not characters: refuses "12345678 90 12" and any emoji wall.
  static const int minLetters = 3;

  /// Distinct letters, which is what separates "aaaa bbb aaaa" from a
  /// sentence. Lower for replies so "yes yes" survives.
  static const int minPostDistinctLetters = 4;
  static const int minReplyDistinctLetters = 3;

  /// The issue with [text] as a post, or null when it is fine to send.
  ///
  /// [sos] lowers only the character floor — see [minSosChars].
  static PostQualityIssue? checkPost(String text, {bool sos = false}) => _check(
    text,
    minChars: sos ? minSosChars : minPostChars,
    minWords: minPostWords,
    minDistinctLetters: minPostDistinctLetters,
  );

  /// The issue with [text] as a reply. Lower bar in every dimension: a reply
  /// is a nod as often as it is a paragraph, and refusing "thanks" would cost
  /// far more than the noise it filters.
  static PostQualityIssue? checkReply(String text) => _check(
    text,
    minChars: minReplyChars,
    minWords: 1,
    minDistinctLetters: minReplyDistinctLetters,
  );

  static PostQualityIssue? _check(
    String text, {
    required int minChars,
    required int minWords,
    required int minDistinctLetters,
  }) {
    final collapsed = text.trim().replaceAll(_whitespace, ' ');
    if (collapsed.length < minChars) return PostQualityIssue.tooShort;

    final words = collapsed.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length < minWords) return PostQualityIssue.tooShort;

    // Only meaningful once there are enough words for repetition to BE
    // repetition — a two-word reply is not "the same thing over and over".
    if (words.length >= minPostWords &&
        words.map((w) => w.toLowerCase()).toSet().length < minDistinctWords) {
      return PostQualityIssue.repetitive;
    }

    final letters = [
      for (final rune in collapsed.toLowerCase().runes)
        if (_letter.hasMatch(String.fromCharCode(rune)))
          String.fromCharCode(rune),
    ];
    if (letters.length < minLetters) return PostQualityIssue.tooShort;
    if (letters.toSet().length < minDistinctLetters) {
      return PostQualityIssue.repetitive;
    }
    return null;
  }

  static final RegExp _whitespace = RegExp(r'\s+');

  /// Any Unicode letter, so accented and non-Latin scripts count as letters.
  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);
}
