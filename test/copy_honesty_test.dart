import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/reminder_planner.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

/// The honesty rule, applied to copy (QA observations, Aug 31 2026).
///
/// Quit Buddies was descoped in Aug 2026 and its UI removed, but two strings
/// kept selling it: the push pre-permission promised "Buddy SOS pings" and
/// the paywall sold "Panic Button + buddy ping". Copy that names a feature
/// the app does not have is a claim the app cannot keep, in five languages.
void main() {
  const locales = ['en', 'es', 'fr', 'de', 'it', 'pt'];

  /// The word for "buddy" in each locale's own copy, as it was written.
  const buddyWords = ['buddy', 'buddies', 'binôme', 'aliado', 'parceiro'];

  Map<String, dynamic> arb(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;

  /// docs/15 QP-A6. The 2,588-person trial tested daily quit MESSAGES sent by
  /// text, and its result was self-reported. "A structured program" let this
  /// screen imply that an app like this one had been tested, which nobody has.
  test('the onboarding proof line says what the trial actually tested', () {
    const tested = {
      'en': 'messages by text',
      'es': 'mensajes diarios por sms',
      'fr': 'messages quotidiens par sms',
      'de': 'nachrichten per sms',
      'it': 'messaggi quotidiani via sms',
      'pt': 'mensagens diárias por sms',
    };
    const oldClaim = {
      'en': 'structured program',
      'es': 'programa estructurado',
      'fr': 'programme structuré',
      'de': 'strukturiertem programm',
      'it': 'programma strutturato',
      'pt': 'programa estruturado',
    };
    for (final locale in locales) {
      final line = (arb(locale)['obRevealProof'] as String).toLowerCase();
      expect(
        line.contains(tested[locale]!),
        isTrue,
        reason: '$locale does not say what was tested: $line',
      );
      expect(
        line.contains(oldClaim[locale]!),
        isFalse,
        reason: '$locale still credits "${oldClaim[locale]}": $line',
      );
      // The figures are the trial's, unchanged: 24.1% against 18.6%.
      expect(line, contains('24%'), reason: locale);
      expect(line, contains('19%'), reason: locale);
    }
  });

  /// docs/15 QP-A7. Copy about medicine and quit lines is held to a stricter
  /// bar than the rest: it may say what a trial found and where to ask, and
  /// never that anything works, cures or is safe, and never a dose. Applied to
  /// every key under the `help`, `smokingRule` and `program` prefixes, so the daily program's
  /// strings (stage B) are covered the moment they exist.
  group('medical claims', () {
    /// Stems that make a health claim or state a dose, per locale. A stem is
    /// matched as a substring of the lower-cased string.
    const banned = {
      'en': ['proven', 'cure', 'guarantee', 'clinically', 'miracle', 'dosage', 'dose'],
      'de': ['bewiesen', 'heilt', 'heilung', 'garantiert', 'klinisch', 'wunder', 'dosis'],
      'es': ['comprobado', 'cura', 'garantiz', 'garantía', 'milagro', 'dosis'],
      'fr': ['prouvé', 'guérit', 'guérison', 'garanti', 'miracle', 'dose', 'posologie'],
      'it': ['comprovato', 'guarisce', 'guarigione', 'garantit', 'miracolo', 'dose', 'dosaggio'],
      'pt': ['comprovado', 'cura', 'garantid', 'milagre', 'dose', 'posologia'],
    };
    final milligrams = RegExp(r'\d\s*mg|\bmg\b');

    /// What is wrong with [text] in [locale], or null when it is clean.
    String? problem(String locale, String text) {
      final lower = text.toLowerCase();
      for (final stem in banned[locale]!) {
        if (lower.contains(stem)) return 'says "$stem"';
      }
      if (milligrams.hasMatch(lower)) return 'gives a dose in mg';
      return null;
    }

    test('the check catches what it exists to catch, in every locale', () {
      // A ban list that has never fired proves nothing about the copy it
      // passes. These are the claims it must stop.
      const bad = {
        'en': 'A clinically proven cure that is guaranteed to work.',
        'de': 'Klinisch bewiesen, garantiert, heilt dich.',
        'es': 'Comprobado, garantizado, una cura milagro.',
        'fr': 'Prouvé et garanti, il guérit en une dose.',
        'it': 'Comprovato e garantito, guarisce con una dose.',
        'pt': 'Comprovado e garantido, uma cura sem dose.',
      };
      for (final locale in locales) {
        expect(problem(locale, bad[locale]!), isNotNull, reason: locale);
      }
      expect(problem('en', 'Take 21 mg a day'), 'gives a dose in mg');
      expect(problem('en', 'A doctor or pharmacist can help.'), isNull);
    });

    test('no help or program string makes a medical claim or gives a dose', () {
      var checked = 0;
      for (final locale in locales) {
        final strings = arb(locale);
        for (final key in strings.keys) {
          if (!(key.startsWith('help') ||
              key.startsWith('program') ||
              key.startsWith('smokingRule'))) {
            continue;
          }
          final value = strings[key];
          if (value is! String) continue;
          checked++;
          expect(
            problem(locale, value),
            isNull,
            reason: '$locale/$key ${problem(locale, value)}: $value',
          );
        }
      }
      // Guard against the prefixes matching nothing and the test passing empty.
      expect(checked, greaterThanOrEqualTo(12 * locales.length));
    });
  });

  /// docs/15 QP-A10. The slip screen no longer stretches the plan by default,
  /// so no note under its curve may say it did — or promise it will.
  test('the slip notes no longer promise extra days', () {
    const promise = {
      'en': 'extra days',
      'es': 'días extra',
      'fr': 'jours de plus',
      'de': 'extra-tage',
      'it': 'giorni in più',
      'pt': 'dias extra',
    };
    const reflown = {
      'en': 'reflown',
      'es': 'recalculada',
      'fr': 'recalculée',
      'de': 'neu berechnet',
      'it': 'ricalcolata',
      'pt': 'recalculada',
    };
    for (final locale in locales) {
      final strings = arb(locale);
      for (final key in strings.keys.where((k) => k.startsWith('slipCurveNote'))) {
        final value = (strings[key] as String).toLowerCase();
        expect(
          value.contains(promise[locale]!),
          isFalse,
          reason: '$locale/$key still promises extra days: $value',
        );
      }
      final label = (strings['slipCurveLabel'] as String).toLowerCase();
      expect(
        label.contains(reflown[locale]!),
        isFalse,
        reason: '$locale/slipCurveLabel still says the curve was reflown: $label',
      );
    }
  });

  test('the notification and paywall copy no longer sell the buddy system', () {
    for (final locale in locales) {
      final strings = arb(locale);
      for (final key in ['obNotifBullet3', 'paywallFeatPanic']) {
        final value = (strings[key] as String).toLowerCase();
        for (final word in buddyWords) {
          expect(
            value.contains(word),
            isFalse,
            reason: '$locale/$key still says "$word": $value',
          );
        }
      }
    }
  });

  /// The permission screen may only promise reminders the app actually schedules.
  ///
  /// `obNotifBullet2` sold "Streak + milestone celebrations" in five languages,
  /// and the subtitle promised "one when you hit a milestone", while
  /// `ReminderKind` was `{danger, trial}`. Seventeen badges unlocked in total
  /// silence. It is the same failure as the buddy copy above — a screen selling
  /// a feature that does not exist — except this one spends a system permission
  /// prompt on the strength of it, and you only get asked once.
  ///
  /// Keyed off the enum so it retires itself: the day a `milestone` reminder
  /// ships, this stops forbidding the word and the copy can come back.
  test('the notification permission screen only promises reminders that exist', () {
    const promises = <String, Map<String, String>>{
      'milestone': {
        'en': 'milestone',
        'es': 'hito',
        'fr': 'étape',
        'de': 'meilenstein',
        'it': 'traguardo',
        'pt': 'marco',
      },
      // The daily program (docs/15 stage B), in each locale's own words.
      'program': {
        'en': 'daily message',
        'es': 'mensaje diario',
        'fr': 'message du jour',
        'de': 'tägliche nachricht',
        'it': 'messaggio del giorno',
        'pt': 'mensagem diária',
      },
      // The evening check-in, in each locale's own word for it.
      'checkin': {
        'en': 'check-in',
        'es': 'repaso',
        'fr': 'point du soir',
        'de': 'check-in',
        'it': 'punto della sera',
        'pt': 'balanço',
      },
      'streakRisk': {
        'en': 'streak',
        'es': 'racha',
        'fr': 'série',
        'de': 'serie',
        'it': 'serie',
        'pt': 'sequência',
      },
    };

    final scheduled = ReminderKind.values.map((k) => k.name).toSet();

    for (final promise in promises.entries) {
      if (scheduled.contains(promise.key)) continue; // it is real now; say so freely

      for (final locale in locales) {
        final strings = arb(locale);
        for (final entry in strings.entries) {
          if (!entry.key.startsWith('obNotif')) continue;
          final value = entry.value;
          if (value is! String) continue;

          expect(
            value.toLowerCase().contains(promise.value[locale]!),
            isFalse,
            reason:
                '$locale/${entry.key} promises a ${promise.key} reminder, and '
                'ReminderKind has no such value: $value',
          );
        }
      }
    }
  });

  /// docs/15 QP-B6. The permission screen is where somebody decides to allow
  /// notifications, once. Now that the daily program exists it must say so —
  /// and say that the extra mornings are the first three from the date, which
  /// is all the program ever adds — rather than keep promising "nothing else".
  test('the notification permission screen names the daily message and the '
      'three mornings', () {
    const dailyMessage = {
      'en': 'daily message',
      'es': 'mensaje diario',
      'fr': 'message du jour',
      'de': 'tägliche nachricht',
      'it': 'messaggio del giorno',
      'pt': 'mensagem diária',
    };
    const threeMornings = {
      'en': 'three mornings',
      'es': 'tres primeras mañanas',
      'fr': 'trois premiers matins',
      'de': 'ersten drei morgen',
      'it': 'prime tre mattine',
      'pt': 'primeiras três manhãs',
    };
    expect(ReminderKind.values, contains(ReminderKind.program));
    for (final locale in locales) {
      final strings = arb(locale);
      expect(
        (strings['obNotifBullet2'] as String).toLowerCase(),
        contains(dailyMessage[locale]),
        reason: '$locale/obNotifBullet2',
      );
      expect(
        (strings['obNotifSubtitle'] as String).toLowerCase(),
        contains(dailyMessage[locale]),
        reason: '$locale/obNotifSubtitle',
      );
      expect(
        (strings['obNotifBullet3'] as String).toLowerCase(),
        contains(threeMornings[locale]),
        reason: '$locale/obNotifBullet3',
      );
      expect(
        (strings['settingsCheckinBody'] as String).toLowerCase(),
        contains(threeMornings[locale]),
        reason: '$locale/settingsCheckinBody',
      );
    }
  });

  test('the fake coach never claims a number would have been double', () async {
    // The demo template "two weeks ago that number would've been double" is
    // an invented comparison — absurd at zero, unverifiable at any count.
    for (final locale in locales) {
      final l10n = await AppLocalizations.delegate.load(Locale(locale));
      final line = l10n.coachReplyProgress2(0, 0).toLowerCase();
      expect(
        line.contains('double') ||
            line.contains('doble') ||
            line.contains('doppelt') ||
            line.contains('doppio') ||
            line.contains('dobro'),
        isFalse,
        reason: '$locale: $line',
      );
    }
  });
}
