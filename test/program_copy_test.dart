import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/quit_program.dart';

/// docs/15 QP-B2: the rules the daily program's copy is held to, in all six
/// languages. The words are the product here, and a notification is armed days
/// before it is read — so what it may say is a short list, and the list is
/// pinned.
///
/// (The medical-claims ban list lives in `copy_honesty_test.dart` and covers
/// every `program*` key; this file covers what is specific to the program.)
void main() {
  const locales = ['en', 'de', 'es', 'fr', 'it', 'pt'];

  Map<String, dynamic> arb(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;

  String cap(String s) => s[0].toUpperCase() + s.substring(1);
  String msgKey(ProgramMessage m) => 'programMsg${cap(m.name)}';
  String replyKey(ProgramReply r) => 'programReply${cap(r.name)}';
  String tipKey(ProgramTip t) => 'programTip${cap(t.name)}';

  final bundles = {for (final l in locales) l: arb(l)};

  Iterable<(String, String, String)> all(
    Iterable<String> keys,
  ) sync* {
    for (final l in locales) {
      for (final k in keys) {
        yield (l, k, bundles[l]![k] as String);
      }
    }
  }

  final messageKeys = ProgramMessage.values.map(msgKey).toList();
  final replyKeys = ProgramReply.values.map(replyKey).toList();
  final tipKeys = ProgramTip.values.map(tipKey).toList();

  group('every id has its words, and nothing has words without an id', () {
    for (final (prefix, keys) in [
      ('programMsg', messageKeys),
      ('programReply', replyKeys),
      ('programTip', tipKeys),
    ]) {
      test('$prefix*', () {
        for (final l in locales) {
          final present = bundles[l]!.keys.where((k) => k.startsWith(prefix));
          expect(present.toSet(), keys.toSet(), reason: l);
          for (final k in keys) {
            expect(
              (bundles[l]![k] as String).trim(),
              isNotEmpty,
              reason: '$l/$k',
            );
          }
        }
      });
    }
  });

  group('a message', () {
    test('is at most 140 characters, in every language', () {
      for (final (l, k, v) in all(messageKeys)) {
        expect(v.length, lessThanOrEqualTo(140), reason: '$l/$k (${v.length}): $v');
      }
    });

    test('carries no digit at all', () {
      // The day is in the title; a message that said "day 3" would be a second
      // count of the same thing, and one that quoted a number would be an
      // invented one. Spelled-out spans ("a week since your date") are
      // calendar facts about the schedule, true by construction.
      for (final (l, k, v) in all([...messageKeys, ...replyKeys, ...tipKeys])) {
        final body = v.replaceAll(RegExp(r'\{\w+\}'), '');
        expect(
          RegExp(r'[0-9]').hasMatch(body),
          isFalse,
          reason: '$l/$k has a digit: $v',
        );
      }
    });

    test('has no placeholder: it is armed days ahead, with nothing to fill', () {
      for (final (l, k, v) in all(messageKeys)) {
        expect(v.contains('{'), isFalse, reason: '$l/$k: $v');
      }
    });

    test('never says the reader is vape-free or has not slipped', () {
      // Armed days ahead, so it cannot know. A reply is shown at answer time,
      // when the track is known, and may say what it likes; a notification may
      // not. The stems are the phrases each locale's own copy already uses.
      const claims = {
        'en': ["vape-free", "vape free", "haven't slipped", "have not slipped",
          "no slips", "still clean", "you've stopped", "you stopped", "so far"],
        'de': ['vape-frei', 'dampffrei', 'nicht ausgerutscht', 'bisher'],
        'es': ['sin vapear', 'libre de vapeo', 'no has recaído', 'hasta ahora'],
        'fr': ['sans vape', 'sans taffe', "tu n'as pas craqué", "jusqu'ici"],
        'it': ['senza svapo', 'non hai ceduto', 'finora'],
        'pt': ['sem vape', 'não escorregaste', 'até agora'],
      };
      for (final (l, k, v) in all(messageKeys)) {
        for (final stem in claims[l]!) {
          expect(
            v.toLowerCase().contains(stem),
            isFalse,
            reason: '$l/$k claims a status ("$stem"): $v',
          );
        }
      }
    });
  });

  group('replies', () {
    test('carry the person\'s own words in exactly the ones that need them', () {
      for (final l in locales) {
        for (final r in ProgramReply.values) {
          final has = (bundles[l]![replyKey(r)] as String).contains('{why}');
          expect(has, r.needsWhy, reason: '$l/${r.name}');
        }
      }
    });
  });

  test('no invented peer quotes: quotation marks appear only where they quote '
      'the reader\'s own head', () {
    // The trialled program used real users' words. This app has none, so the
    // voice is its own. What is allowed to sit in quotation marks is the thing
    // an urge says ("one won't hurt"), and the reader's own reason. Adding to
    // this list is a decision somebody reads.
    final allowed = {
      msgKey(ProgramMessage.d4),
      msgKey(ProgramMessage.d16),
      msgKey(ProgramMessage.d49),
      tipKey(ProgramTip.stress1),
      replyKey(ProgramReply.praiseWhy1),
      replyKey(ProgramReply.praiseWhy2),
    };
    final quoted = RegExp('["“”„«»]');
    for (final l in locales) {
      for (final k in [...messageKeys, ...replyKeys, ...tipKeys]) {
        final has = quoted.hasMatch(bundles[l]![k] as String);
        expect(
          has,
          allowed.contains(k),
          reason: '$l/$k ${has ? "has" : "lacks"} a quotation mark',
        );
      }
    }
  });

  group('the voice of each language', () {
    test('Italian never agrees with the reader: no gendered adjective or '
        'participle about them', () {
      // "Sono pronto" assumes a man; "Sono pronta" a woman. The copy uses avere
      // verbs, nouns and adverbs instead.
      final gendered = RegExp(
        r'\b(sei|ti sei|sentirti|essere|stai|resta|restare|rimani)\s+'
        r'(pront|stanc|sicur|contenti?\b|contento|arrabbiat|nervos|sol[oa]\b)',
        caseSensitive: false,
      );
      for (final (l, k, v) in all([...messageKeys, ...replyKeys, ...tipKeys])) {
        if (l != 'it') continue;
        expect(gendered.hasMatch(v), isFalse, reason: '$l/$k: $v');
      }
    });

    test('German says vapen, never dampfen', () {
      for (final (l, k, v) in all([...messageKeys, ...replyKeys, ...tipKeys])) {
        if (l != 'de') continue;
        expect(v.toLowerCase().contains('dampf'), isFalse, reason: '$k: $v');
      }
    });

    test('French says taffe, never bouffée', () {
      for (final (l, k, v) in all([...messageKeys, ...replyKeys, ...tipKeys])) {
        if (l != 'fr') continue;
        expect(v.toLowerCase().contains('bouffée'), isFalse, reason: '$k: $v');
      }
    });

    test('a puff is the locale\'s own word in the two lines that name one', () {
      const puff = {
        'en': 'puff',
        'de': 'zug',
        'es': 'calada',
        'fr': 'taffe',
        'it': 'tiro',
        'pt': 'passa',
      };
      for (final l in locales) {
        for (final k in [
          msgKey(ProgramMessage.d16),
          replyKey(ProgramReply.slipToday),
        ]) {
          expect(
            (bundles[l]![k] as String).toLowerCase().contains(puff[l]!),
            isTrue,
            reason: '$l/$k',
          );
        }
      }
    });
  });
}
