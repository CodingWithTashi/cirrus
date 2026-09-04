import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/community_rules.dart';

/// "Was anything actually said?" — the gate the panic flow made necessary.
///
/// That flow opens the composer PRE-TAGGED `sos`, so publishing is one tap
/// away with the tag already chosen, and a live SOS pins to the top of the
/// feed for an hour. `"a"` used to publish, and it pinned.
///
/// The bar is deliberately low. Every accept case below is something a person
/// mid-craving would plausibly type with shaking hands, and all of them must
/// go through — a gate that turns away a real cry for help costs far more
/// than the noise it filters.
void main() {
  group('a post needs to be a message', () {
    test('refuses what is not one', () {
      for (final junk in [
        '',
        ' ',
        'a',
        'asdf',
        '...',
        '!!!!!!!!!!!!!!',
        '😭😭😭',
        '12345678 90 12',
      ]) {
        expect(
          PostQuality.checkPost(junk),
          isNotNull,
          reason: '"$junk" should not publish',
        );
      }
    });

    test('refuses one thing repeated, however long', () {
      // Long enough to clear the character floor, and still nothing said.
      expect(
        PostQuality.checkPost('aaaaaaaaaaaaaa'),
        PostQualityIssue.tooShort,
        reason: 'one word, so it fails on words before it fails on letters',
      );
      expect(
        PostQuality.checkPost('help help help help'),
        PostQualityIssue.repetitive,
      );
      expect(
        PostQuality.checkPost('aaaa bbb aaaa'),
        PostQualityIssue.repetitive,
      );
      expect(
        // A wall of emoji is long enough and even has three "words", but it
        // has no letters in it — so the honest answer is "say something",
        // not "stop repeating yourself".
        PostQuality.checkPost('😭😭😭😭😭😭😭😭😭😭😭😭 😭 😭'),
        PostQualityIssue.tooShort,
      );
    });

    test('an SOS clears a lower bar than an ordinary post', () {
      // This gate is reached from the composer the panic flow opens
      // PRE-TAGGED `sos`, by somebody at high craving intensity. A wrongly
      // refused cry for help is the most expensive false positive in the app,
      // and the 12-character floor refused both of these — which nobody
      // noticed because the accept list happened to start at 14.
      for (final cry in ['i need help', 'help me now', 'talk to me']) {
        expect(
          PostQuality.checkPost(cry, sos: true),
          isNull,
          reason: '"$cry" must reach the feed as an SOS',
        );
      }
      // Only the character floor moves. Everything that makes something noise
      // rather than short is unchanged.
      expect(PostQuality.checkPost('a', sos: true), isNotNull);
      expect(PostQuality.checkPost('...........', sos: true), isNotNull);
      expect(
        PostQuality.checkPost('help help help', sos: true),
        PostQualityIssue.repetitive,
      );
      expect(
        PostQuality.minSosChars,
        lessThan(PostQuality.minPostChars),
      );
    });

    test('lets a real cry for help through', () {
      // The whole point. Each of these is short, plain and typed by somebody
      // who is not in the mood to compose a paragraph.
      for (final real in [
        'help me please',
        'i want to vape',
        "day 3 and i'm done",
        'i cant i cant i cant',
        'about to cave at work',
        'someone talk me out of this',
      ]) {
        expect(
          PostQuality.checkPost(real),
          isNull,
          reason: '"$real" must reach the feed',
        );
      }
    });

    test('collapses whitespace before measuring, so padding is not length', () {
      expect(PostQuality.checkPost('a     b     c'), isNotNull);
      expect(PostQuality.checkPost('  help me please  '), isNull);
    });

    test('counts accented letters as letters', () {
      // A five-locale app: "estoy fatal ahora" must not read as gibberish
      // because the letters are not ASCII.
      expect(PostQuality.checkPost('estoy fatal ahora'), isNull);
      expect(PostQuality.checkPost('ça va très mal là'), isNull);
    });
  });

  group('a reply may be a nod', () {
    test('accepts the short, real ones', () {
      for (final real in ['thanks', 'yes yes', 'you got this', 'proud of you']) {
        expect(
          PostQuality.checkReply(real),
          isNull,
          reason: '"$real" is a perfectly good reply',
        );
      }
    });

    test('still refuses noise', () {
      for (final junk in ['ok', '👍👍👍', 'aaaaaa', 'abababab', '....']) {
        expect(
          PostQuality.checkReply(junk),
          isNotNull,
          reason: '"$junk" should not post',
        );
      }
    });

    test('is looser than a post in every dimension', () {
      // "thanks" is one word and six characters: a post refuses it, a reply
      // does not. If these two ever converge, one of them is wrong.
      expect(PostQuality.checkPost('thanks'), isNotNull);
      expect(PostQuality.checkReply('thanks'), isNull);
      expect(
        PostQuality.minReplyChars,
        lessThan(PostQuality.minPostChars),
      );
      expect(
        PostQuality.minReplyDistinctLetters,
        lessThan(PostQuality.minPostDistinctLetters),
      );
    });
  });

  test('the thresholds are the ones the server enforces', () {
    // Two copies of the same rule drift, and the copy that drifts LOOSE lets
    // a post through the composer that `createPost` then refuses after the
    // pop — the exact failure mode docs/09 issue 6 was about. The TypeScript
    // file is the source of truth; this reads it as text, the same way the
    // slur lists are pinned in `community_rules_test.dart`.
    final source = File('functions/src/ai/prefilter.ts').readAsStringSync();
    final block = RegExp(
      r'export const POST_QUALITY = \{(.*?)\} as const;',
      dotAll: true,
    ).firstMatch(source);
    expect(block, isNotNull, reason: 'POST_QUALITY not found in prefilter.ts');

    int server(String name) {
      final match = RegExp('$name:\\s*(\\d+)').firstMatch(block!.group(1)!);
      expect(match, isNotNull, reason: '$name missing from POST_QUALITY');
      return int.parse(match!.group(1)!);
    }

    expect(PostQuality.minPostChars, server('minPostChars'));
    expect(PostQuality.minSosChars, server('minSosChars'));
    expect(PostQuality.minReplyChars, server('minReplyChars'));
    expect(PostQuality.minPostWords, server('minPostWords'));
    expect(PostQuality.minDistinctWords, server('minDistinctWords'));
    expect(PostQuality.minLetters, server('minLetters'));
    expect(
      PostQuality.minPostDistinctLetters,
      server('minPostDistinctLetters'),
    );
    expect(
      PostQuality.minReplyDistinctLetters,
      server('minReplyDistinctLetters'),
    );
  });
}
