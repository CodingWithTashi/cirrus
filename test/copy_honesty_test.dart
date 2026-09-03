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
  const locales = ['en', 'es', 'fr', 'de', 'pt'];

  /// The word for "buddy" in each locale's own copy, as it was written.
  const buddyWords = ['buddy', 'buddies', 'binôme', 'aliado', 'parceiro'];

  Map<String, dynamic> arb(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;

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
        'pt': 'marco',
      },
      'streakRisk': {
        'en': 'streak',
        'es': 'racha',
        'fr': 'série',
        'de': 'serie',
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
            line.contains('dobro'),
        isFalse,
        reason: '$locale: $line',
      );
    }
  });
}
