import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/community_rules.dart';

/// The composer's "no" before posting (docs/09 issue 6), and the parity that
/// makes it honest: the client refuses exactly the words the server refuses,
/// matched the way the server matches them.
void main() {
  group('check', () {
    test('a slur is refused', () {
      expect(
        CommunityRules.check('quit? not with these faggots cheering'),
        CommunityRuleViolation.slur,
      );
    });

    test('matches whole words, so an innocent word containing one is fine', () {
      // The Scunthorpe problem: "spic" inside "spice" and "conspicuous" is
      // not a slur, and a substring check would have refused a recipe.
      expect(CommunityRules.check('pumpkin spice season saved me'), isNull);
      expect(
        CommunityRules.check('trying to be less conspicuous about it'),
        isNull,
      );
    });

    test('sees through case, diacritics and leetspeak', () {
      expect(CommunityRules.check('these FAGGOTS'), CommunityRuleViolation.slur);
      expect(
        CommunityRules.check('f4gg0ts everywhere'),
        CommunityRuleViolation.slur,
      );
      expect(CommunityRules.check('fággots'), CommunityRuleViolation.slur);
    });

    test('sees through decomposed diacritics, as the server does', () {
      // "a" + COMBINING ACUTE, the form some keyboards and pastes produce.
      // The server NFD-decomposes and strips; a client that only folded
      // precomposed letters let this through to be refused after the pop.
      expect(
        CommunityRules.check('fággots everywhere'),
        CommunityRuleViolation.slur,
      );
      // A caron from Latin Extended-B, outside the Latin-1 block.
      expect(CommunityRules.check('fǎggots'), CommunityRuleViolation.slur);
    });

    test('where-to-buy and for-sale talk is refused as sourcing', () {
      expect(
        CommunityRules.check('anyone know where to buy 50mg pods'),
        CommunityRuleViolation.sourcing,
      );
      expect(
        CommunityRules.check('two unopened boxes for sale, cheap'),
        CommunityRuleViolation.sourcing,
      );
    });

    test('sourcing phrases are whole phrases, not substrings', () {
      // "unplug for a while" contains "plug for". Refusing it outright would
      // block the most ordinary sentence a person mid-quit can write.
      expect(
        CommunityRules.check('gonna unplug for a while, cravings are wild'),
        isNull,
      );
    });

    test('naming the brand you quit is not a refusal', () {
      // Tone is the model's call: praise is blocked server-side, but "threw
      // my juul in the bin" is what this community is for.
      expect(CommunityRules.check('threw my juul in the bin. day 1.'), isNull);
      expect(
        CommunityRules.mentionsBrand('threw my juul in the bin. day 1.'),
        isTrue,
      );
      expect(CommunityRules.mentionsBrand('day 1, still here'), isFalse);
    });

    test('a slur outranks sourcing when a post has both', () {
      expect(
        CommunityRules.check('pods for sale, faggots need not apply'),
        CommunityRuleViolation.slur,
      );
    });

    test('profanity alone is not a violation — the target is the signal', () {
      // The Sep 1 policy: "fuck this app" publishes. Nothing here may refuse
      // it, or the server's allow never gets the chance to say so.
      for (final text in [
        'fuck this app',
        'so fucking proud of myself, day 1',
        'this app is garbage and the coach is a bot',
        'day 3 and I feel like absolute shit but I am still here',
      ]) {
        expect(CommunityRules.check(text), isNull, reason: text);
      }
    });

    test("violates is the fake backend's verdict: refuse or hold", () {
      expect(CommunityRules.violates('hello all'), isFalse);
      expect(CommunityRules.violates('juul saved my life'), isTrue);
      expect(CommunityRules.violates('pods for sale'), isTrue);
    });
  });

  test('the slur list is the one the server blocks with, word for word', () {
    // Two copies of the same list drift, and the one that drifts open lets a
    // post through the client that the server then refuses after the pop.
    // The TypeScript file is the source of truth; this reads it as text.
    final source = File('functions/src/ai/prefilter.ts').readAsStringSync();
    final block = RegExp(
      r'const SLURS: readonly string\[\] = \[(.*?)\];',
      dotAll: true,
    ).firstMatch(source);
    expect(block, isNotNull, reason: 'SLURS array not found in prefilter.ts');
    final serverList = RegExp(r"'([^']+)'")
        .allMatches(block!.group(1)!)
        .map((m) => m.group(1)!)
        .toList();
    expect(serverList, isNotEmpty);
    expect(CommunityRules.slurs, serverList);
  });
}
