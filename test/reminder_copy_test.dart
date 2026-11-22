import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/reminder_copy.dart';
import 'package:last_puff/core/utils/program_copy.dart';
import 'package:last_puff/domain/logic/quit_program.dart';
import 'package:last_puff/domain/logic/reminder_planner.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import 'helpers.dart';

/// The words a check-in notification carries, by slot (docs/superpowers/specs/
/// 2026-11-21-day2-morning-design.md §4.2). `checkinNotifTitle` reads as an
/// evening title in three languages ("le point du soir", "Check-in am Abend",
/// "il punto della sera"), and it sat on cold turkey's 09:00 program mornings
/// as well, so production said "evening" at nine in those three. Every morning
/// slot wears the morning title now, and a morning on a zero line never tells
/// anybody to log a puff.
void main() {
  const locales = ['en', 'es', 'fr', 'de', 'it', 'pt'];
  final nine = DateTime(2026, 11, 13, 9);

  CheckinReminder checkin({
    required ProgramSlot slot,
    int planDay = 2,
    int totalDays = 30,
    int limit = 9,
    ProgramMessage? message,
  }) => CheckinReminder(
    reminder: OneShotReminder(id: 5102, at: nine),
    planDay: planDay,
    totalDays: totalDays,
    limit: limit,
    message: message,
    slot: slot,
  );

  test('no morning title says evening', () {
    const evening = ['evening', 'noche', 'soir', 'abend', 'sera', 'noite'];
    for (final code in locales) {
      final l10n = lookupAppLocalizations(Locale(code));
      for (final title in [
        l10n.morningNotifTitle(2),
        l10n.morningNotifTitlePast,
      ]) {
        for (final word in evening) {
          expect(
            title.toLowerCase(),
            isNot(contains(word)),
            reason: '$code: $title',
          );
        }
      }
    }
  });

  test('the zero morning never says log', () {
    // The brief's stems, plus the verbs the store art and the evening body
    // use for logging in Spanish and French (APUNTAR CALADA, NOTER UNE TAFFE),
    // which none of the others catch.
    const log = [
      'log',
      'registr',
      'enregistr',
      'eintrag',
      'tragen',
      'segna',
      'regist',
      'apunt',
      'anot',
      'note',
      'noté',
    ];
    for (final code in locales) {
      final body = lookupAppLocalizations(
        Locale(code),
      ).morningNotifBodyZero.toLowerCase();
      for (final stem in log) {
        expect(body, isNot(contains(stem)), reason: '$code: $body');
      }
    }
  });

  test('no morning claims a status', () {
    // Armed days ahead, so it cannot know how the day went — the stems are the
    // ones `program_copy_test` holds the program's notifications to.
    const claims = {
      'en': ['vape-free', 'vape free', "haven't slipped", 'still clean'],
      'de': ['vape-frei', 'nicht ausgerutscht', 'bisher'],
      'es': ['sin vapear', 'no has recaído', 'hasta ahora'],
      'fr': ['sans vape', "tu n'as pas craqué", "jusqu'ici"],
      'it': ['senza svapo', 'non hai ceduto', 'finora'],
      'pt': ['sem vape', 'não escorregaste', 'até agora'],
    };
    for (final code in locales) {
      final l10n = lookupAppLocalizations(Locale(code));
      for (final body in [
        l10n.morningNotifBody(9),
        l10n.morningNotifBodyZero,
      ]) {
        for (final stem in claims[code]!) {
          expect(body.toLowerCase(), isNot(contains(stem)), reason: body);
        }
      }
    }
  });

  test('a program morning wears the morning title', () {
    for (final code in locales) {
      final l10n = lookupAppLocalizations(Locale(code));

      final morning = programCopy(
        l10n,
        checkin(slot: ProgramSlot.morning, message: ProgramMessage.d1am),
      );
      expect(morning.title, l10n.morningNotifTitle(2), reason: code);
      expect(morning.body, ProgramMessage.d1am.text(l10n), reason: code);

      final evening = programCopy(
        l10n,
        checkin(slot: ProgramSlot.evening, message: ProgramMessage.d1pm),
      );
      expect(evening.title, l10n.checkinNotifTitle(2), reason: code);
      expect(evening.body, ProgramMessage.d1pm.text(l10n), reason: code);
    }
  });

  test('a plain morning on a zero line gets the zero body', () {
    for (final code in locales) {
      final l10n = lookupAppLocalizations(Locale(code));

      final zero = checkinCopy(
        l10n,
        checkin(slot: ProgramSlot.morning, limit: 0),
      );
      expect(zero.title, l10n.morningNotifTitle(2), reason: code);
      expect(zero.body, l10n.morningNotifBodyZero, reason: code);
      expect(
        checkinCopy(l10n, checkin(slot: ProgramSlot.morning, limit: 9)).body,
        l10n.morningNotifBody(9),
        reason: code,
      );

      // The evening is the check-in it always was.
      final evening = checkinCopy(
        l10n,
        checkin(slot: ProgramSlot.evening, limit: 0),
      );
      expect(evening.title, l10n.checkinNotifTitle(2), reason: code);
      expect(evening.body, l10n.checkinNotifBodyZero, reason: code);
      expect(
        checkinCopy(l10n, checkin(slot: ProgramSlot.evening, limit: 9)).body,
        l10n.checkinNotifBody(9),
        reason: code,
      );
    }
  });

  test('past Freedom Day a morning has no number and no evening', () {
    for (final code in locales) {
      final l10n = lookupAppLocalizations(Locale(code));

      final plain = checkinCopy(
        l10n,
        checkin(slot: ProgramSlot.morning, planDay: 31, limit: 0),
      );
      expect(plain.title, l10n.morningNotifTitlePast, reason: code);
      expect(plain.title, isNot(contains('31')), reason: code);

      final program = programCopy(
        l10n,
        checkin(
          slot: ProgramSlot.morning,
          planDay: 31,
          limit: 0,
          message: ProgramMessage.d2am,
        ),
      );
      expect(program.title, l10n.morningNotifTitlePast, reason: code);

      // An evening past the date keeps its own numberless title.
      expect(
        checkinCopy(
          l10n,
          checkin(slot: ProgramSlot.evening, planDay: 31, limit: 0),
        ).title,
        l10n.checkinNotifTitlePast,
        reason: code,
      );
    }
  });

  test('every morning the real planner arms wears the morning title', () {
    // By the clock, not by `slot`: a planner that armed a 09:00 message and
    // forgot to say it was a morning would hand it the evening title, and the
    // hand-built reminders above could never show it.
    final dawn = DateTime(2026, 11, 12, 7);
    for (final method in [QuitMethod.taper, QuitMethod.coldTurkey]) {
      final base = journeyOnDay(1, now: dawn);
      final journey = base.copyWith(plan: base.plan.copyWith(method: method));
      final checkins = CheckinReminderPlanner.plan(
        journey: journey,
        now: dawn,
        hour: 20,
        quietStartHour: 23,
        quietEndHour: 8,
        enabled: true,
      );
      expect(
        checkins.where((c) => c.reminder.at.hour == 9),
        isNotEmpty,
        reason: method.name,
      );

      for (final code in locales) {
        final l10n = lookupAppLocalizations(Locale(code));
        for (final c in checkins) {
          final text = c.message == null
              ? checkinCopy(l10n, c)
              : programCopy(l10n, c);
          final morning = c.reminder.at.hour == 9;
          expect(
            text.title,
            morning
                ? l10n.morningNotifTitle(c.planDay)
                : l10n.checkinNotifTitle(c.planDay),
            reason: '$code ${method.name} $c',
          );
          // A taper's plain morning names the line Home will show.
          if (morning && c.message == null) {
            expect(
              text.body,
              c.limit == 0
                  ? l10n.morningNotifBodyZero
                  : l10n.morningNotifBody(c.limit),
              reason: '$c',
            );
          }
        }
      }
    }
  });
}
