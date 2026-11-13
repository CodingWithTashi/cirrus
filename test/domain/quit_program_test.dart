import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/quit_program.dart';
import 'package:last_puff/domain/logic/taper_engine.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';

/// docs/15 QP-B1. The daily program is a pure function of the CURRENT plan and
/// a date, so it can be armed days ahead on the device and re-based the moment
/// the date moves.
///
/// The anchor is the app's own "your date": `plan.freedomDate` for a taper (the
/// last day of the runway, which is when the line is zero) and `plan.startDate`
/// for cold turkey (day one, which is already vape-free). The plan's wording,
/// "the first zero day", is not the same day for a low baseline, whose curve
/// reaches zero earlier — the choice and its consequence are pinned below.
void main() {
  QuitPlan plan({
    QuitMethod method = QuitMethod.taper,
    int pace = 30,
    int stretch = 0,
    int baseline = 100,
    DateTime? start,
    int planNumber = 1,
  }) => QuitPlan(
    method: method,
    paceDays: pace,
    startDate: start ?? DateTime(2026, 11, 1),
    baselinePuffsPerDay: baseline,
    weeklySpend: 30,
    strength: NicStrength.mg50,
    stretchDays: stretch,
    planNumber: planNumber,
  );

  JourneyState journeyOf(
    QuitPlan p, {
    Map<DateTime, DayLog> days = const {},
    Map<DateTime, Map<CheckupKind, CheckupAnswer>> checkups = const {},
  }) => JourneyState(
    profile: const UserProfile(alias: '@x', avatarEmoji: '🦊'),
    plan: p,
    days: days,
    cravingsSurvivedTotal: 0,
    repairTokens: 0,
    longestStreak: 0,
    goals: const [],
    earnedBadges: const {},
    checkups: checkups,
  );

  /// The date [n] program days from the quit date of [p].
  DateTime on(QuitPlan p, int n) => LpDate.addDays(QuitProgram.quitDate(p), n);

  // The schedule from docs/15 §4: seven evenings before, two a day for the
  // first three days, an evening a day to day 13, then every other day or so.
  const sparse = [
    14, 16, 18, 21, 23, 25, 28, 30, 32, 35, 37, 39, 42, 44, 46, 49, 51, 53, 56,
  ];

  group('the schedule', () {
    test('is 43 messages', () {
      expect(ProgramMessage.values, hasLength(43));
    });

    test('is the table in the plan, day by day and slot by slot', () {
      final pairs = [
        for (final m in ProgramMessage.values) (m.programDay, m.slot),
      ];
      final expected = <(int, ProgramSlot)>[
        for (var d = -7; d <= -1; d++) (d, ProgramSlot.evening),
        for (var d = 0; d <= 2; d++) ...[
          (d, ProgramSlot.morning),
          (d, ProgramSlot.evening),
        ],
        for (var d = 3; d <= 13; d++) (d, ProgramSlot.evening),
        for (final d in sparse) (d, ProgramSlot.evening),
      ];
      expect(pairs, expected);
    });

    test('no two messages share a day and slot', () {
      final seen = <(int, ProgramSlot)>{};
      for (final m in ProgramMessage.values) {
        expect(seen.add((m.programDay, m.slot)), isTrue, reason: '$m');
      }
    });

    test('every message is reachable exactly once across the whole program', () {
      final p = plan();
      final reached = <ProgramMessage>[];
      for (var n = -7; n <= 56; n++) {
        for (final slot in ProgramSlot.values) {
          final m = QuitProgram.messageFor(p, on(p, n), slot);
          if (m != null) reached.add(m);
        }
      }
      expect(reached, hasLength(43));
      expect(reached.toSet(), ProgramMessage.values.toSet());
    });

    test('a day with no message answers null for both slots', () {
      final p = plan();
      for (final n in [15, 17, 19, 20, 22, 24, 26, 27, 29, 31, 55]) {
        for (final slot in ProgramSlot.values) {
          expect(QuitProgram.messageFor(p, on(p, n), slot), isNull, reason: '$n');
        }
      }
    });

    test('the first three days have a morning and an evening, the rest only an '
        'evening', () {
      final p = plan();
      for (final n in [0, 1, 2]) {
        expect(
          QuitProgram.messageFor(p, on(p, n), ProgramSlot.morning),
          isNotNull,
        );
        expect(
          QuitProgram.messageFor(p, on(p, n), ProgramSlot.evening),
          isNotNull,
        );
      }
      for (final n in [-7, -1, 3, 13, 56]) {
        expect(QuitProgram.messageFor(p, on(p, n), ProgramSlot.morning), isNull);
        expect(
          QuitProgram.messageFor(p, on(p, n), ProgramSlot.evening),
          isNotNull,
        );
      }
    });

    test('messagesOn lists a day in order, morning first', () {
      final p = plan();
      expect(QuitProgram.messagesOn(p, on(p, 1)), [
        ProgramMessage.d1am,
        ProgramMessage.d1pm,
      ]);
      expect(QuitProgram.messagesOn(p, on(p, 20)), isEmpty);
    });
  });

  group('what the card shows right now', () {
    final p = plan(method: QuitMethod.coldTurkey);

    ProgramMessage? shown(int day, int hour, {int checkinHour = 20}) =>
        QuitProgram.messageToShow(
          p,
          DateTime(on(p, day).year, on(p, day).month, on(p, day).day, hour, 30),
          checkinHour: checkinHour,
        );

    test('on a two-message day, the morning one until the check-in hour, then '
        'the evening one', () {
      expect(shown(1, 6), ProgramMessage.d1am);
      expect(shown(1, 12), ProgramMessage.d1am);
      expect(shown(1, 19), ProgramMessage.d1am);
      expect(shown(1, 20), ProgramMessage.d1pm);
      expect(shown(1, 23), ProgramMessage.d1pm);
    });

    test('it follows the person\'s own check-in hour', () {
      expect(shown(1, 17, checkinHour: 18), ProgramMessage.d1am);
      expect(shown(1, 18, checkinHour: 18), ProgramMessage.d1pm);
      expect(shown(1, 20, checkinHour: 21), ProgramMessage.d1am);
      expect(shown(1, 21, checkinHour: 21), ProgramMessage.d1pm);
    });

    test('on a one-message day, that message all day', () {
      for (final hour in [0, 7, 14, 21]) {
        expect(shown(5, hour), ProgramMessage.d5, reason: '$hour');
      }
    });

    test('on a day with no message, nothing', () {
      expect(shown(15, 12), isNull);
      expect(shown(70, 12), isNull);
    });
  });

  group('the anchor', () {
    test('a taper counts from Freedom Day, the last day of its runway', () {
      final p = plan();
      expect(QuitProgram.quitDate(p), p.freedomDate);
      expect(QuitProgram.quitDate(p), DateTime(2026, 11, 30));
    });

    test('cold turkey counts from day one, which is already the date', () {
      final p = plan(method: QuitMethod.coldTurkey);
      expect(QuitProgram.quitDate(p), p.startDate);
      // Plan day 1 is program day 0, so the quit-day messages land on day one
      // and "d3" lands on plan day 4.
      expect(QuitProgram.dayOf(p, p.startDate), 0);
      expect(QuitProgram.dayOf(p, LpDate.addDays(p.startDate, 3)), 3);
    });

    test('the program runs 7 days before the date to 56 after, and no further', () {
      final p = plan();
      expect(QuitProgram.dayOf(p, on(p, -7)), -7);
      expect(QuitProgram.dayOf(p, on(p, 0)), 0);
      expect(QuitProgram.dayOf(p, on(p, 56)), 56);
      expect(QuitProgram.dayOf(p, on(p, -8)), isNull);
      expect(QuitProgram.dayOf(p, on(p, 57)), isNull);
    });

    test('a time of day does not change the day', () {
      final p = plan();
      final d = on(p, 5);
      expect(QuitProgram.dayOf(p, DateTime(d.year, d.month, d.day, 23, 59)), 5);
      expect(QuitProgram.dayOf(p, DateTime(d.year, d.month, d.day, 0, 1)), 5);
    });

    test('moving the date moves the whole program with it', () {
      // Add-days after a slip, Adjust, and a restart all change the plan. The
      // program follows the CURRENT date: nothing is remembered, so a message
      // can repeat or be skipped when the date moves, and that is accepted.
      final today = DateTime(2026, 11, 26);
      final before = plan();
      final after = plan(stretch: 2);
      expect(QuitProgram.dayOf(before, today), -4);
      expect(QuitProgram.dayOf(after, today), -6);
      expect(
        QuitProgram.messageFor(before, today, ProgramSlot.evening),
        ProgramMessage.pre4,
      );
      expect(
        QuitProgram.messageFor(after, today, ProgramSlot.evening),
        ProgramMessage.pre6,
      );
    });

    test('a plan started again follows the new plan', () {
      final restarted = plan(
        start: DateTime(2026, 12, 3),
        method: QuitMethod.coldTurkey,
        planNumber: 2,
      );
      expect(QuitProgram.quitDate(restarted), DateTime(2026, 12, 3));
      expect(QuitProgram.dayOf(restarted, DateTime(2026, 12, 3)), 0);
    });

    test('a low baseline reaches a zero line before the date, and the date does '
        'not move for it', () {
      // 20 puffs a day: the curve is already 0 several days before the last
      // day of the runway. The program is still anchored on Freedom Day, the
      // date the app calls "yours" everywhere else, so those zero-line days
      // fall inside the pre-week as negative program days.
      final p = plan(baseline: 20);
      final firstZero = [
        for (var d = 1; d <= p.totalDays; d++)
          if (TaperEngine.limitFor(p, d) == 0) d,
      ].first;
      expect(firstZero, lessThan(p.totalDays), reason: 'the premise');
      final firstZeroDate = LpDate.addDays(p.startDate, firstZero - 1);
      expect(QuitProgram.dayOf(p, firstZeroDate), lessThan(0));
      expect(QuitProgram.quitDate(p), p.freedomDate);
    });

    test('counts calendar days across a clock change', () {
      // US clocks go back on Nov 1 2026, and this plan's pre-week straddles it
      // (Oct 29 – Nov 4, date Nov 5). 24-hour blocks land an hour off the date
      // key and miscount by a day twice a year (CLAUDE.md, `LpDate`).
      final p = plan(start: DateTime(2026, 10, 7));
      expect(p.freedomDate, DateTime(2026, 11, 5));
      expect(QuitProgram.dayOf(p, DateTime(2026, 10, 29, 22, 30)), -7);
      expect(QuitProgram.dayOf(p, DateTime(2026, 11, 1, 1, 15)), -4);
      expect(QuitProgram.dayOf(p, DateTime(2026, 11, 2, 0, 5)), -3);
      expect(QuitProgram.dayOf(p, DateTime(2026, 11, 5, 23, 55)), 0);
      expect(QuitProgram.dayOf(p, DateTime(2026, 10, 28, 12)), isNull);
    });
  });

  group('slipped', () {
    // Cold turkey: every day's line is zero, so a stored limit of 0 is the
    // common case and the rule is easy to read.
    final cold = plan(method: QuitMethod.coldTurkey);
    final today = LpDate.addDays(cold.startDate, 10);

    DayLog log(DateTime d, {int puffs = 0, int limit = 0}) =>
        DayLog(date: d, puffs: puffs, limit: limit);

    ProgramTrack trackWith(Map<DateTime, DayLog> logs, {QuitPlan? p}) =>
        QuitProgram.trackOn(
          journeyOf(p ?? cold, days: logs),
          today,
        );

    test('no logs at all is on track', () {
      expect(trackWith(const {}), ProgramTrack.onTrack);
    });

    test('puffs on a zero line yesterday is a slip', () {
      final y = LpDate.addDays(today, -1);
      expect(trackWith({y: log(y, puffs: 3)}), ProgramTrack.slipped);
    });

    test('and so is today, for someone who has just slipped and answers', () {
      expect(trackWith({today: log(today, puffs: 1)}), ProgramTrack.slipped);
    });

    test('the last three days count, today included, and no further back', () {
      final twoAgo = LpDate.addDays(today, -2);
      final threeAgo = LpDate.addDays(today, -3);
      expect(trackWith({twoAgo: log(twoAgo, puffs: 2)}), ProgramTrack.slipped);
      expect(
        trackWith({threeAgo: log(threeAgo, puffs: 2)}),
        ProgramTrack.onTrack,
      );
    });

    test('a clean zero-line day is not a slip', () {
      final y = LpDate.addDays(today, -1);
      expect(trackWith({y: log(y)}), ProgramTrack.onTrack);
    });

    test('over a line that is not zero is the taper\'s business, not the '
        'program\'s', () {
      // The taper has its own recovery (the slip screen). The program speaks
      // about a zero line, which is the date it is counting from.
      final y = LpDate.addDays(today, -1);
      expect(
        trackWith({y: log(y, puffs: 9, limit: 5)}),
        ProgramTrack.onTrack,
      );
    });

    test('reads the limit each day was LOGGED with, never a recomputed curve', () {
      // A taper whose curve says 40 today, but whose stored log carries 0
      // (a plan started again holds a day's line on the log). The stored
      // number is the one the streak engine and Home use.
      final taper = plan(start: LpDate.addDays(today, -4));
      expect(TaperEngine.limitFor(taper, 4), greaterThan(0), reason: 'premise');
      final y = LpDate.addDays(today, -1);
      expect(
        trackWith({y: log(y, puffs: 2)}, p: taper),
        ProgramTrack.slipped,
      );
      expect(
        trackWith({y: log(y, puffs: 2, limit: 40)}, p: taper),
        ProgramTrack.onTrack,
      );
    });

    test('a zero-line slip in the pre-week of a low baseline counts', () {
      // A taper at 20 a day hits a zero line before its date. Puffs on one of
      // those days are a slip by the app's own rule (limit 0), whatever the
      // program day is called.
      final low = plan(baseline: 20);
      final inPreWeek = LpDate.addDays(QuitProgram.quitDate(low), -4);
      final y = LpDate.addDays(inPreWeek, -1);
      expect(
        QuitProgram.trackOn(
          journeyOf(low, days: {y: log(y, puffs: 2)}),
          inPreWeek,
        ),
        ProgramTrack.slipped,
      );
    });
  });

  group('replies', () {
    ProgramReply reply(
      Mood mood,
      ProgramTrack track,
      int seed, {
      bool hasWhy = true,
    }) => QuitProgram.replyFor(mood, track, seed: seed, hasWhy: hasWhy);

    Set<ProgramReply> allFor(
      Mood mood,
      ProgramTrack track, {
      bool hasWhy = true,
    }) => {for (var s = 0; s < 12; s++) reply(mood, track, s, hasWhy: hasWhy)};

    test('there are fourteen', () {
      expect(ProgramReply.values, hasLength(14));
      expect(ProgramReply.values.where((r) => r.needsWhy), hasLength(2));
    });

    test('rough or meh, on track, get four concrete steps — the same four', () {
      final rough = allFor(Mood.rough, ProgramTrack.onTrack);
      expect(rough, hasLength(4));
      expect(allFor(Mood.meh, ProgramTrack.onTrack), rough);
    });

    test('okay, on track, gets three steadying lines', () {
      expect(allFor(Mood.okay, ProgramTrack.onTrack), hasLength(3));
    });

    test('good or great, on track, get four, two of which use their reason', () {
      final good = allFor(Mood.good, ProgramTrack.onTrack);
      expect(good, hasLength(4));
      expect(good.where((r) => r.needsWhy), hasLength(2));
      expect(allFor(Mood.great, ProgramTrack.onTrack), good);
    });

    test('without a stated reason, the two that need one are never chosen', () {
      for (final mood in [Mood.good, Mood.great]) {
        final set = allFor(mood, ProgramTrack.onTrack, hasWhy: false);
        expect(set, hasLength(2));
        expect(set.any((r) => r.needsWhy), isFalse);
      }
    });

    test('a slip gets one of three, whatever the mood', () {
      final slip = allFor(Mood.great, ProgramTrack.slipped);
      expect(slip, hasLength(3));
      for (final mood in Mood.values) {
        expect(allFor(mood, ProgramTrack.slipped), slip, reason: '$mood');
      }
    });

    test('the same inputs give the same reply, and the seed cycles the variants', () {
      expect(
        reply(Mood.rough, ProgramTrack.onTrack, 5),
        reply(Mood.rough, ProgramTrack.onTrack, 5),
      );
      expect(
        reply(Mood.rough, ProgramTrack.onTrack, 1),
        reply(Mood.rough, ProgramTrack.onTrack, 5),
        reason: 'four variants, so seeds 1 and 5 land together',
      );
      expect(
        reply(Mood.rough, ProgramTrack.onTrack, 0),
        isNot(reply(Mood.rough, ProgramTrack.onTrack, 1)),
      );
    });

    test('every reply is reachable', () {
      final seen = <ProgramReply>{};
      for (final mood in Mood.values) {
        for (final track in ProgramTrack.values) {
          seen.addAll(allFor(mood, track));
        }
      }
      expect(seen, ProgramReply.values.toSet());
    });

    test('a negative seed does not crash or leave the variants', () {
      expect(
        () => reply(Mood.okay, ProgramTrack.onTrack, -7),
        returnsNormally,
      );
    });
  });

  group('tips', () {
    test('there are 5 for stress, 4 for a slip and 12 for more', () {
      expect(ProgramTip.values, hasLength(21));
      expect(
        ProgramTip.values.where((t) => t.kind == ProgramTipKind.stress),
        hasLength(5),
      );
      expect(
        ProgramTip.values.where((t) => t.kind == ProgramTipKind.slipped),
        hasLength(4),
      );
      expect(
        ProgramTip.values.where((t) => t.kind == ProgramTipKind.more),
        hasLength(12),
      );
    });

    test('a tip is always of the kind asked for, and the seed walks them all', () {
      for (final kind in ProgramTipKind.values) {
        final of = ProgramTip.values.where((t) => t.kind == kind).toList();
        final seen = {
          for (var s = 0; s < of.length; s++) QuitProgram.tipFor(kind, s),
        };
        expect(seen, of.toSet(), reason: '$kind');
        expect(QuitProgram.tipFor(kind, of.length), QuitProgram.tipFor(kind, 0));
        expect(QuitProgram.tipFor(kind, -3).kind, kind);
      }
    });
  });

  group('links', () {
    test('only the messages that point somewhere do', () {
      final linked = {
        for (final m in ProgramMessage.values)
          if (m.link != ProgramLink.none) m: m.link,
      };
      expect(linked, {
        ProgramMessage.d2pm: ProgramLink.help,
        ProgramMessage.d5: ProgramLink.stress,
        ProgramMessage.d12: ProgramLink.money,
        ProgramMessage.d35: ProgramLink.health,
        ProgramMessage.d39: ProgramLink.community,
      });
    });
  });

  group('check-ups', () {
    final p = plan(method: QuitMethod.coldTurkey);

    CheckupKind? due(int n, {Map<DateTime, Map<CheckupKind, CheckupAnswer>>? a}) =>
        QuitProgram.checkupDue(journeyOf(p, checkups: a ?? const {}), on(p, n));

    test('"any other nicotine this week?" is asked on days 7, 14, 28 and 56', () {
      for (final n in [7, 14, 28, 56]) {
        expect(due(n), CheckupKind.nicotine, reason: 'day $n');
      }
      for (final n in [0, 6, 8, 13, 15, 27, 29, 55, 57]) {
        expect(due(n), isNull, reason: 'day $n');
      }
    });

    test('"vaped in the last 30 days?" opens on day 30 and stays open to day 44', () {
      for (final n in [30, 31, 38, 44]) {
        expect(due(n), CheckupKind.vaped30, reason: 'day $n');
      }
      expect(due(45), isNull);
    });

    test('the 90-day question opens on day 90, past the end of the program', () {
      expect(QuitProgram.dayOf(p, on(p, 90)), isNull, reason: 'outside −7…56');
      for (final n in [90, 97, 104]) {
        expect(due(n), CheckupKind.vaped90, reason: 'day $n');
      }
      expect(due(89), isNull);
      expect(due(105), isNull);
    });

    test('never more than one at a time', () {
      for (var n = -7; n <= 120; n++) {
        // `checkupDue` returns one kind; what must hold is that no two
        // windows contain the same day, so the one returned is never a choice.
        final containing = [
          for (final k in CheckupKind.values)
            if (k.windowContains(n)) k,
        ];
        expect(containing.length, lessThanOrEqualTo(1), reason: 'day $n');
      }
    });

    test('a question that has been answered is not asked again in its window', () {
      final answered = {
        on(p, 31): {CheckupKind.vaped30: CheckupAnswer.notVaped},
      };
      expect(due(31, a: answered), isNull);
      expect(due(35, a: answered), isNull, reason: 'the rest of the window');
      expect(due(44, a: answered), isNull);
    });

    test('a single-day question is answered for that day only', () {
      final answered = {
        on(p, 7): {CheckupKind.nicotine: CheckupAnswer.noOther},
      };
      expect(due(7, a: answered), isNull);
      expect(due(14, a: answered), CheckupKind.nicotine);
    });

    test('an answer to one question does not close another', () {
      final answered = {
        on(p, 30): {CheckupKind.nicotine: CheckupAnswer.noOther},
      };
      expect(due(30, a: answered), CheckupKind.vaped30);
    });

    test('only the first two sit in the daily card; the 90-day one has its own', () {
      expect(CheckupKind.nicotine.inProgramCard, isTrue);
      expect(CheckupKind.vaped30.inProgramCard, isTrue);
      expect(CheckupKind.vaped90.inProgramCard, isFalse);
    });

    test('each question accepts only its own answers', () {
      expect(
        CheckupKind.nicotine.answers,
        [
          CheckupAnswer.noOther,
          CheckupAnswer.cigarettes,
          CheckupAnswer.pouches,
          CheckupAnswer.patchGum,
        ],
      );
      for (final k in [CheckupKind.vaped30, CheckupKind.vaped90]) {
        expect(k.answers, [CheckupAnswer.vaped, CheckupAnswer.notVaped]);
      }
    });
  });
}
