import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/why_words.dart';
import 'package:last_puff/domain/models/enums.dart';

/// The one thing onboarding asks in the user's own words.
///
/// Nineteen screens of chips and enums land in the deterministic user card,
/// exactly and for free. None of them can seed Ember's vector memory, because
/// that layer is only for things somebody actually said — so it started empty
/// for every user and stayed empty until they talked to the coach.
///
/// This is the sibling of `CoachName` and the differences are the point. A
/// name is one word rendered into a chat header, so it bans emoji and
/// punctuation. A sentence is prose bound for a prompt and an embedding, so it
/// allows both — and what it strips instead is the invisible characters that
/// have no business in either.
///
/// Every invisible in this file is written as an escape rather than pasted:
/// a test whose subject cannot be seen in the diff is a test nobody can
/// review.
void main() {
  /// Right-to-left override. Can make stored text render as something else
  /// entirely wherever it is later displayed — a support ticket, say.
  const rtlOverride = '\u202E';

  /// Zero-width joiner: a way to smuggle one string past a check that reads
  /// another.
  const zeroWidthJoiner = '\u200D';

  /// A raw C0 control character, the kind a bad paste carries.
  const controlChar = '\u0001';

  group('normalize', () {
    test('trims and collapses the whitespace a paste brings', () {
      expect(
        WhyWords.normalize('  I want to run\n\n  with my kid   again '),
        'I want to run with my kid again',
      );
    });

    test('folds newlines rather than dropping the words around them', () {
      expect(WhyWords.normalize('one\ntwo\ttree'), 'one two tree');
    });

    test('keeps the punctuation a sentence needs', () {
      const said = "my daughter's asthma — that's it, really!";
      expect(WhyWords.normalize(said), said);
    });

    test('keeps emoji, unlike a coach name', () {
      // A name goes in the chat header, which cannot lay emoji out. This goes
      // into a prompt and an embedding, both of which handle them fine.
      const said = 'being around for her \u{1F9D2}';
      expect(WhyWords.normalize(said), said);
    });

    test('strips invisible characters', () {
      expect(
        WhyWords.normalize('quit${rtlOverride}for${zeroWidthJoiner}me'),
        'quitforme',
      );
    });

    test('strips raw control characters without welding the words together', () {
      // The control character sits between two spaces. Removing it before
      // collapsing whitespace would leave a double space behind.
      expect(WhyWords.normalize('for my $controlChar kid'), 'for my kid');
    });

    test('an empty answer normalizes to nothing', () {
      expect(WhyWords.normalize('   \n\t '), '');
    });
  });

  group('stored', () {
    test('a skipped answer is null, not an empty string', () {
      // Null means "never answered". An empty string would round-trip through
      // the codec as a value, and the card would print a blank line as though
      // the user had said something.
      expect(WhyWords.stored(''), isNull);
      expect(WhyWords.stored('   '), isNull);
    });

    test('an answer that was only invisible characters is also nothing', () {
      expect(WhyWords.stored(rtlOverride + zeroWidthJoiner), isNull);
    });

    test('a real answer comes back normalized', () {
      expect(WhyWords.stored('  so I can   breathe  '), 'so I can breathe');
    });
  });

  group('validate', () {
    test('an empty answer is valid — the question is optional', () {
      expect(WhyWords.validate(''), isNull);
    });

    test('accepts an answer at the limit', () {
      expect(WhyWords.validate('a' * WhyWords.maxLength), isNull);
    });

    test('refuses one past it', () {
      expect(
        WhyWords.validate('a' * (WhyWords.maxLength + 1)),
        WhyWordsError.tooLong,
      );
    });

    test('counts the way a person counts, not the way UTF-16 does', () {
      // Every one of these is two code units. Counting them as two would cut
      // an answer off at half the length it appears to be.
      final emoji = '\u{1F9D2}' * WhyWords.maxLength;
      expect(WhyWords.validate(emoji), isNull);
      expect(WhyWords.validate('\u{1F9D2}$emoji'), WhyWordsError.tooLong);
    });

    test('judges the normalized length, not the raw one', () {
      // Otherwise a sentence padded with the whitespace we are about to
      // collapse would be refused for a length it does not end up having.
      final padded = '${'a' * WhyWords.maxLength}${' ' * 50}';
      expect(WhyWords.validate(padded), isNull);
    });
  });

  group('hintFor', () {
    // The placeholder echoes a why the user picked two screens earlier, so a
    // first-time user reads it as a continuation of their own answers rather
    // than a line about somebody else's life (docs/09 issue 2).
    test('echoes the one why they picked', () {
      for (final chip in WhyChip.values) {
        expect(WhyWords.hintFor({chip}), chip, reason: chip.name);
      }
    });

    test('with several, the most personal one wins', () {
      expect(
        WhyWords.hintFor({WhyChip.money, WhyChip.health, WhyChip.family}),
        WhyChip.family,
      );
      expect(WhyWords.hintFor({WhyChip.appearance, WhyChip.money}), WhyChip.money);
      expect(WhyWords.hintFor({WhyChip.health, WhyChip.freedom}), WhyChip.health);
    });

    test('is deterministic, so going back a step does not reshuffle it', () {
      const picked = {WhyChip.health, WhyChip.money, WhyChip.fitness};
      expect(WhyWords.hintFor(picked), WhyWords.hintFor({...picked}));
    });

    test('nothing picked falls back to the line that shipped first', () {
      expect(WhyWords.hintFor(const {}), WhyChip.fitness);
    });

    test('the precedence names every why exactly once', () {
      // Otherwise a new chip would silently fall through to the fallback and
      // every user who picked only it would see a line about running.
      expect(WhyWords.hintPrecedence.toSet(), WhyChip.values.toSet());
      expect(WhyWords.hintPrecedence.length, WhyChip.values.length);
    });
  });
}
