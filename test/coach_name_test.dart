import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

/// The coach's name is now the user's to choose, and this is the test that
/// catches a botched job.
///
/// Modelled on `brand_name_test.dart`, whose docstring says it exactly: a
/// rename is the kind of change that lands in English and quietly misses four
/// other locales. This one goes further, because a user-supplied name breaks
/// grammar that a fixed word did not:
///
/// > **A string rendering {name} must be grammatically valid with the name
/// > treated as an indeclinable proper noun requiring NO article, NO elision,
/// > and NO gendered agreement.**
///
/// The existing translations did not satisfy that. Portuguese carried both
/// "O Ember" and "A Ember" — and "à Ember", a contraction — while French
/// elided to "qu'Ember" in three places and called the coach "il". Those are
/// the failures the probes below are chosen to expose.
void main() {
  const locales = ['en', 'es', 'fr', 'de', 'pt'];

  /// Every key that interpolates the coach's name.
  const renamed = [
    'coachTyping',
    'coachSafetyNote',
    'insightPendingBody',
    'memoriesTitle',
    'memoriesIntro',
    'memoriesEmpty',
    'memoriesForgotten',
    'settingsMemories',
    'memoriesLoading',
  ];

  Map<String, dynamic> arb(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;

  /// Renders every renamed string with [name], for one locale.
  Future<List<String>> renderAll(String locale, String name) async {
    final l10n = await AppLocalizations.delegate.load(Locale(locale));
    return [
      l10n.coachTyping(name),
      l10n.coachGreeting(name, 200, 'taper', 'Sep 15'),
      l10n.coachSafetyNote(name),
      l10n.insightPendingBody(name),
      l10n.memoriesTitle(name),
      l10n.memoriesIntro(name),
      l10n.memoriesEmpty(name),
      l10n.memoriesForgotten(name),
      l10n.settingsMemories(name),
      l10n.memoriesLoading(name),
      l10n.obCoachNameTitle(name),
      l10n.obCoachNameAsk(name),
      l10n.obCoachNameKeep(name),
      l10n.coachRenamed(name),
    ];
  }

  test('the default is still Ember in every locale', () {
    for (final locale in locales) {
      expect(arb(locale)['coachName'], 'Ember', reason: locale);
    }
  });

  test('every renamed key takes {name} and hardcodes nothing', () {
    for (final locale in locales) {
      final strings = arb(locale);
      for (final key in [...renamed, 'coachGreeting']) {
        final value = strings[key] as String;
        expect(value, contains('{name}'), reason: '$locale/$key');
        expect(value, isNot(contains('Ember')), reason: '$locale/$key');
      }
    }
  });

  test('a chosen name renders cleanly in all five languages', () async {
    // The probes are picked to break a specific leftover:
    //   'Ana'    — a French elision (qu'Ana) or a Portuguese article (A Ana)
    //   'Élodie' — accented and vowel-initial, the elision trap again
    //   'Zyx'    — a consonant-initial control
    for (final locale in locales) {
      for (final probe in ['Ana', 'Élodie', 'Zyx']) {
        for (final rendered in await renderAll(locale, probe)) {
          expect(
            rendered,
            contains(probe),
            reason: '$locale dropped the name from "$rendered"',
          );
          expect(
            rendered,
            isNot(contains('Ember')),
            reason: '$locale still says Ember in "$rendered"',
          );
        }
      }
    }
  });

  test('no locale elides or declines the name', () async {
    // Two specific leftovers, not a general grammar check. A blunt "any o/a
    // before the name" rule flags the Portuguese and Spanish PREPOSITION "a"
    // ("contaste a Ana" — told *to* Ana), which is correct and must stay.
    //
    //   elision        French "Ce qu'Ana retient" — always wrong with a name
    //   leading article Portuguese "A Ana começa..." — an article, not a
    //                   preposition, because it opens the clause
    final elision = RegExp(r"['’]\s*Ana");
    final leadingArticle = RegExp(r"(^|[.!?]\s+)[OA]\s+Ana");
    for (final locale in locales) {
      for (final rendered in await renderAll(locale, 'Ana')) {
        expect(
          elision.hasMatch(rendered),
          isFalse,
          reason: '$locale elides before the name in "$rendered"',
        );
        expect(
          leadingArticle.hasMatch(rendered),
          isFalse,
          reason: '$locale puts an article before the name in "$rendered"',
        );
      }
    }
  });

  test('the palette and the wire value survive the rename', () {
    // `Ember` is also a colour token and a CoachRole wire value. A careless
    // find-and-replace across the repo takes both with it, and the wire one
    // would silently reclassify every stored message.
    final colors = File('lib/app/theme/lp_colors.dart').readAsStringSync();
    expect(colors, contains('emberGlow'));
    expect(colors, contains('emberSoft'));

    final models = File('lib/domain/models/models.dart').readAsStringSync();
    expect(models, contains('enum CoachRole { ember, user }'));
  });
}
