import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The five ARB files must stay one file in five languages.
///
/// 646 keys held parity by discipline alone until now — there was no test.
/// A rename or a new placeholder is exactly the kind of change that lands in
/// English and quietly misses four other locales (`brand_name_test.dart` says
/// as much in its own docstring), and a translator dropping a `{placeholder}`
/// compiles perfectly and silently renders a sentence with a hole in it.
void main() {
  const locales = ['en', 'es', 'fr', 'de', 'pt'];
  final placeholder = RegExp(r'\{(\w+)\}');

  Map<String, dynamic> load(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;

  /// Message keys only — the `@key` entries are metadata and live in `en`.
  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  /// Placeholders as written in the value. Plural bodies repeat `{count}`, so
  /// a set is the right shape.
  Set<String> placeholdersIn(String value) =>
      placeholder.allMatches(value).map((m) => m.group(1)!).toSet();

  final arbs = {for (final l in locales) l: load(l)};
  final english = arbs['en']!;

  test('every locale carries exactly the same keys as English', () {
    final expected = messageKeys(english);
    for (final locale in locales.where((l) => l != 'en')) {
      final actual = messageKeys(arbs[locale]!);
      expect(
        actual.difference(expected),
        isEmpty,
        reason: '$locale has keys English does not',
      );
      expect(
        expected.difference(actual),
        isEmpty,
        reason: '$locale is missing keys English has',
      );
    }
  });

  test('every translation interpolates the same values English does', () {
    // The one that catches a dropped `{name}` in the German string: it
    // compiles, and it silently renders the sentence without the name in it.
    for (final key in messageKeys(english)) {
      final expected = placeholdersIn(english[key] as String);
      for (final locale in locales.where((l) => l != 'en')) {
        final value = arbs[locale]![key];
        if (value is! String) continue;
        expect(
          placeholdersIn(value),
          expected,
          reason: '$locale/$key does not interpolate the same values as en',
        );
      }
    }
  });

  test('every placeholder-bearing key declares its types in the template', () {
    // gen-l10n reads types from `app_en.arb` only; an undeclared placeholder
    // silently becomes Object and formats as whatever toString gives.
    for (final key in messageKeys(english)) {
      final value = english[key] as String;
      final used = placeholdersIn(value);
      if (used.isEmpty) continue;
      final meta = english['@$key'];
      expect(
        meta,
        isA<Map<String, dynamic>>(),
        reason: '$key interpolates $used but has no @$key block',
      );
      final declared =
          ((meta as Map<String, dynamic>)['placeholders']
                  as Map<String, dynamic>?)
              ?.keys
              .toSet() ??
          const <String>{};
      expect(
        used.difference(declared),
        isEmpty,
        reason: '@$key does not declare every placeholder it uses',
      );
    }
  });

  test('no locale still ships a retired key', () {
    // Deleting a key from `app_en.arb` alone leaves four dead strings behind,
    // which the next translator will faithfully maintain forever.
    const retired = [
      'obSpendKickerSmall',
      'obSpendKickerMid',
      'obSpendKickerBig',
      'obFirstPuffScienceLabel',
      // The panic arena (Sep 2 2026): one why line for every game, minutes
      // counted on the round panel, and the unit per game.
      'gameSubtitle',
      'gameRoundDone',
      'survivedGameTiles',
      // The Free screen became a Free-vs-Pro comparison (Sep 3 2026,
      // docs/12 §5c). These five were the old bullet list, and two of them
      // hardcoded an allowance ("5 coach messages a day", "one post a day")
      // that `LpAllowances` now supplies — bringing either back would
      // reintroduce a number that drifts from the one the app enforces.
      'freePlanFeat1',
      'freePlanFeat2',
      'freePlanFeat3',
      'freePlanFeat4',
      'freePlanFeat5',
    ];
    for (final locale in locales) {
      for (final key in retired) {
        expect(
          arbs[locale]!.containsKey(key),
          isFalse,
          reason: '$locale still has the retired $key',
        );
      }
    }
  });
}
