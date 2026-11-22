import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/quit_program.dart';
import 'package:last_puff/domain/logic/reminder_planner.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart';

/// The evening check-in (docs/10 §51): the one reminder that reaches somebody
/// who has not opened the app today. Two in three people who finished
/// onboarding before Oct 16 2026 never came back a second day, and nothing in
/// the app could reach them.
void main() {
  List<CheckinReminder> plan(
    JourneyState journey, {
    required DateTime now,
    int hour = 20,
    int quietStart = 23,
    int quietEnd = 8,
    bool enabled = true,
    Iterable<DateTime> busy = const [],
  }) => CheckinReminderPlanner.plan(
    journey: journey,
    now: now,
    hour: hour,
    quietStartHour: quietStart,
    quietEndHour: quietEnd,
    enabled: enabled,
    busy: busy,
  );

  final morning = DateTime(2026, 9, 14, 9, 30);

  test('seven evenings from today, each naming the number Home will show', () {
    final journey = journeyOnDay(4, now: morning);
    final checkins = plan(journey, now: morning);

    expect(checkins, hasLength(CheckinReminderPlanner.window));
    for (final (i, c) in checkins.indexed) {
      expect(c.reminder.id, CheckinReminderPlanner.firstId + i);
      expect(c.reminder.at, DateTime(2026, 9, 14 + i, 20));
      expect(c.planDay, 4 + i);
      expect(c.totalDays, 30);
      // Never re-derived here: the limit is the journey's own answer.
      expect(c.limit, journey.limitOn(c.reminder.at));
    }
  });

  test('after the hour, the window starts tomorrow', () {
    final late = DateTime(2026, 9, 14, 21, 5);
    final checkins = plan(journeyOnDay(4, now: late), now: late);

    expect(checkins.first.reminder.at, DateTime(2026, 9, 15, 20));
    expect(checkins.length, CheckinReminderPlanner.window - 1);
  });

  test('not today once today is confirmed — they have been here', () {
    final journey = journeyOnDay(4, now: morning);
    final today = JourneyState.dateKey(morning);
    final logged = journey.copyWith(
      days: {
        ...journey.days,
        today: DayLog(date: today, puffs: 2, limit: journey.limitOn(morning)),
      },
    );

    final checkins = plan(logged, now: morning);
    expect(checkins.first.reminder.at, DateTime(2026, 9, 15, 20));
  });

  test('nothing when switched off or inside quiet hours', () {
    final journey = journeyOnDay(4, now: morning);

    expect(plan(journey, now: morning, enabled: false), isEmpty);
    expect(plan(journey, now: morning, quietStart: 19, quietEnd: 7), isEmpty);
  });

  test(
    'every evening is 20:00 on its own calendar day, across a DST change',
    () {
      // North America leaves DST on Nov 1 2026 and Europe on Oct 25. Whatever
      // zone the suite runs in, `Duration(days: 1)` steps would land on 19:00
      // or 21:00 after the change; calendar arithmetic never does.
      final before = DateTime(2026, 10, 22, 9);
      final checkins = plan(journeyOnDay(4, now: before), now: before);
      for (final (i, c) in checkins.indexed) {
        expect(c.reminder.at.hour, 20);
        expect(
          LpDate.dayKey(c.reminder.at),
          LpDate.dayKey(LpDate.addDays(before, i)),
        );
      }
    },
  );

  test(
    'a plain morning is 09:00 on its own calendar day, across a DST change',
    () {
      // Plan day one is the evening before a clock change, so plan days two
      // and three straddle it: North America leaves DST on Nov 1 2026 and
      // Europe on Oct 25, and both enter it on Mar 8 and Mar 29. Whatever zone
      // the suite runs in, a `Duration(days: 1)` step would land on 08:00 or
      // 10:00 after the change; calendar arithmetic never does.
      for (final start in [
        DateTime(2026, 3, 7, 21),
        DateTime(2026, 3, 28, 21),
        DateTime(2026, 10, 24, 21),
        DateTime(2026, 10, 31, 21),
      ]) {
        final m = plan(journeyOnDay(1, now: start), now: start)
            .where((c) => c.slot == ProgramSlot.morning)
            .toList();
        expect(m.map((c) => c.reminder.id), [5102, 5103]);
        for (final (i, c) in m.indexed) {
          final want = DateTime(start.year, start.month, start.day + i + 1);
          expect(c.reminder.at.hour, 9, reason: '$start -> ${c.reminder.at}');
          expect(c.reminder.at.minute, 0);
          expect(
            DateTime(
              c.reminder.at.year,
              c.reminder.at.month,
              c.reminder.at.day,
            ),
            want,
            reason: '$start -> ${c.reminder.at}',
          );
        }
      }
    },
  );

  test('past Freedom Day the day keeps counting and the limit is zero', () {
    final journey = journeyOnDay(30, now: morning, totalDays: 30);
    final checkins = plan(journey, now: morning);

    expect(checkins.first.planDay, 30);
    expect(checkins.first.limit, 0);
    expect(checkins[1].planDay, greaterThan(checkins[1].totalDays));
    expect(checkins[1].limit, 0);
  });

  test('its ids stay clear of every other schedule', () {
    final ids = CheckinReminderPlanner.ids;
    expect(ids, hasLength(CheckinReminderPlanner.window));
    expect(ids.every((id) => id >= 4000 && id < 4100), isTrue);
    expect(ids.contains(TrialReminderPlanner.id), isFalse);
  });

  // docs/15 QP-B5: the daily program takes over the evening slot on the days it
  // has a message, and adds a morning on the first three days. Everything else
  // is the evening check-in exactly as it was.
  group('the daily program', () {
    // 07:00 on a cold-turkey account's quit day, which is plan day one.
    final dawn = DateTime(2026, 11, 12, 7);

    JourneyState cold({
      int day = 1,
      DateTime? now,
      Mood? mood,
      bool confirmed = false,
    }) {
      final at = now ?? dawn;
      final base = journeyOnDay(day, now: at);
      final today = JourneyState.dateKey(at);
      return base.copyWith(
        plan: base.plan.copyWith(method: QuitMethod.coldTurkey),
        days: {
          ...base.days,
          if (mood != null || confirmed)
            today: DayLog(
              date: today,
              puffs: 0,
              limit: 0,
              mood: mood,
              vapeFreeConfirmed: confirmed,
            ),
        },
      );
    }

    List<CheckinReminder> planFor(
      JourneyState j, {
      DateTime? now,
      int hour = 20,
      int quietStart = 23,
      int quietEnd = 8,
    }) => plan(
      j,
      now: now ?? dawn,
      hour: hour,
      quietStart: quietStart,
      quietEnd: quietEnd,
    );

    test('the quit day arms both messages, and the evening takes the check-in '
        'slot', () {
      final out = planFor(cold());
      final first = out.first;

      expect(first.message, ProgramMessage.q0am);
      expect(first.kind, ReminderKind.program);
      expect(first.reminder.at, DateTime(2026, 11, 12, 9));
      expect(first.reminder.id, 5000);

      final evening = out[1];
      expect(evening.message, ProgramMessage.q0pm);
      expect(evening.kind, ReminderKind.program);
      expect(evening.reminder.at, DateTime(2026, 11, 12, 20));
      expect(evening.reminder.id, CheckinReminderPlanner.firstId);
    });

    test('seven evenings and three mornings, in time order, with no id twice', () {
      final out = planFor(cold());
      final evenings = out.where((c) => c.reminder.id < 5000).toList();
      final mornings = out.where((c) => c.reminder.id >= 5000).toList();

      expect(evenings, hasLength(CheckinReminderPlanner.window));
      expect(mornings, hasLength(3));
      expect(
        out.map((c) => c.reminder.at).toList(),
        [...out.map((c) => c.reminder.at)]..sort(),
      );
      expect(out.map((c) => c.reminder.id).toSet(), hasLength(out.length));
      // Quit day + six more evenings: q0pm, d1pm, d2pm, d3 … d6.
      expect(evenings.map((c) => c.message), [
        ProgramMessage.q0pm,
        ProgramMessage.d1pm,
        ProgramMessage.d2pm,
        ProgramMessage.d3,
        ProgramMessage.d4,
        ProgramMessage.d5,
        ProgramMessage.d6,
      ]);
      expect(mornings.map((c) => c.message), [
        ProgramMessage.q0am,
        ProgramMessage.d1am,
        ProgramMessage.d2am,
      ]);
    });

    test('a morning\'s id is its program day, not its place in the window', () {
      // On program day 1 after 09:00 the first morning left is day two's.
      final late = DateTime(2026, 11, 13, 10);
      final out = planFor(cold(day: 2, now: late), now: late);
      final mornings = out.where((c) => c.reminder.id >= 5000).toList();
      expect(mornings, hasLength(1));
      expect(mornings.single.message, ProgramMessage.d2am);
      expect(mornings.single.reminder.id, 5002);
    });

    test('titles count the plan day exactly as the check-in does', () {
      final out = planFor(cold());
      expect(out.first.planDay, 1);
      expect(out[1].planDay, 1);
      expect(out.last.planDay, greaterThan(1));
      expect(out.first.totalDays, 30);
    });

    test('a morning is at nine, or the first hour quiet hours leave open before '
        'noon, or nothing', () {
      expect(
        planFor(cold(), quietEnd: 8).first.reminder.at.hour,
        9,
      );
      expect(
        planFor(cold(), quietStart: 22, quietEnd: 11).first.reminder.at.hour,
        11,
      );
      // Quiet through noon: no morning at all, but the evening still goes.
      final out = planFor(cold(), quietStart: 20, quietEnd: 13, hour: 14);
      expect(out.where((c) => c.reminder.id >= 5000), isEmpty);
      expect(out, isNotEmpty);
    });

    test('a morning already past is not armed', () {
      final late = DateTime(2026, 11, 12, 10);
      final out = planFor(cold(now: late), now: late);
      expect(out.first.message, ProgramMessage.q0pm);
    });

    test('today\'s evening is skipped once the mood is in, not once the day is '
        'confirmed', () {
      // Cold turkey's day is confirmed by morning, which must not silence the
      // quit day's evening message.
      final confirmedOnly = planFor(cold(confirmed: true));
      expect(
        confirmedOnly.any((c) => c.message == ProgramMessage.q0pm),
        isTrue,
        reason: 'a confirmed day is not an answered card',
      );

      final answered = planFor(cold(mood: Mood.okay));
      expect(
        answered.any((c) => c.message == ProgramMessage.q0pm),
        isFalse,
        reason: 'they have answered today',
      );
      expect(answered.any((c) => c.message == ProgramMessage.d1pm), isTrue);
    });

    test('on a day with no message the old rule stands: skipped once the day '
        'is confirmed, and not once only the mood is in', () {
      // Program day 15 has no message.
      final at = DateTime(2026, 11, 26, 7);
      final confirmed = planFor(cold(day: 16, now: at, confirmed: true), now: at);
      expect(confirmed.first.reminder.at.day, 27, reason: 'today skipped');

      final moodOnly = planFor(cold(day: 16, now: at, mood: Mood.good), now: at);
      expect(moodOnly.first.reminder.at, DateTime(2026, 11, 26, 20));
      expect(moodOnly.first.kind, ReminderKind.checkin);
      expect(moodOnly.first.message, isNull);
    });

    test('a day with no message is the plain evening check-in', () {
      // Program days 14–20: messages on 14, 16 and 18 only.
      final at = DateTime(2026, 11, 25, 7);
      final out = planFor(cold(day: 15, now: at), now: at);
      expect(out.map((c) => c.kind), [
        ReminderKind.program, // 14
        ReminderKind.checkin, // 15
        ReminderKind.program, // 16
        ReminderKind.checkin, // 17
        ReminderKind.program, // 18
        ReminderKind.checkin, // 19
        ReminderKind.checkin, // 20
      ]);
      expect(out.map((c) => c.reminder.id), CheckinReminderPlanner.ids);
    });

    test('a taper counts from Freedom Day: the pre-week arrives as program '
        'evenings', () {
      // Day 24 of 30 → Freedom Day is six days off, so tonight is "pre6".
      final at = DateTime(2026, 11, 12, 7);
      final taper = journeyOnDay(24, now: at);
      final out = planFor(taper, now: at);
      expect(out.first.message, ProgramMessage.pre6);
      expect(
        out.take(6).map((c) => c.message),
        [
          ProgramMessage.pre6,
          ProgramMessage.pre5,
          ProgramMessage.pre4,
          ProgramMessage.pre3,
          ProgramMessage.pre2,
          ProgramMessage.pre1,
        ],
      );
      // The seventh day is Freedom Day itself, and its morning is armed too.
      expect(out.any((c) => c.message == ProgramMessage.q0am), isTrue);
    });

    test('moving the date re-bases the messages immediately', () {
      final at = DateTime(2026, 11, 12, 7);
      final taper = journeyOnDay(24, now: at);
      final stretched = taper.copyWith(
        plan: taper.plan.copyWith(stretchDays: 2),
      );
      expect(planFor(taper, now: at).first.message, ProgramMessage.pre6);
      // Two days further off, today is program day −8: outside the program, so
      // tonight is the plain check-in and "pre7" has moved to tomorrow.
      final after = planFor(stretched, now: at);
      expect(after.first.message, isNull);
      expect(after.first.kind, ReminderKind.checkin);
      expect(after[1].message, ProgramMessage.pre7);
    });

    test('far from the date, and past the program, it is only the check-in', () {
      final far = planFor(journeyOnDay(4, now: dawn));
      expect(far.every((c) => c.kind == ReminderKind.checkin), isTrue);

      final at = DateTime(2027, 1, 20, 7);
      final past = planFor(cold(day: 70, now: at), now: at);
      expect(past.every((c) => c.kind == ReminderKind.checkin), isTrue);
      expect(past, hasLength(CheckinReminderPlanner.window));
    });

    test('off means off, mornings included', () {
      expect(
        CheckinReminderPlanner.plan(
          journey: cold(),
          now: dawn,
          hour: 20,
          quietStartHour: 23,
          quietEndHour: 8,
          enabled: false,
        ),
        isEmpty,
      );
    });

    test('an evening that falls in quiet hours silences the whole schedule, as '
        'before', () {
      final out = planFor(cold(), hour: 21, quietStart: 20, quietEnd: 8);
      expect(out, isEmpty);
    });

    test('the morning ids sit clear of every other schedule', () {
      final ids = CheckinReminderPlanner.morningIds;
      expect(ids, [5000, 5001, 5002]);
      final others = {
        for (var i = 1000; i < 1024; i++) i,
        TrialReminderPlanner.id,
        for (var i = 0; i < MilestoneReminderPlanner.celebrated.length; i++)
          MilestoneReminderPlanner.idBase + i,
        ...CheckinReminderPlanner.ids,
      };
      expect(ids.where(others.contains), isEmpty);
    });

    test('the most the app can have pending at once is well inside iOS\'s 64', () {
      // The plan said 19; recomputed from the real caps rather than trusted.
      final worst =
          ReminderPlanner.maxPerDay +
          1 + // the trial reminder
          MilestoneReminderPlanner.celebrated.length +
          CheckinReminderPlanner.window +
          CheckinReminderPlanner.morningIds.length;
      expect(worst, 19);
      expect(worst, lessThan(64));
    });

    test('every program day produces something the person sees at most once '
        'a slot', () {
      // Walk the whole program from a cold-turkey day one, a week at a time:
      // no id is ever reused inside one window, and no window is empty.
      var at = dawn;
      for (var i = 0; i < 9; i++) {
        final out = planFor(cold(day: 1 + i * 7, now: at), now: at);
        expect(out, isNotEmpty);
        expect(out.map((c) => c.reminder.id).toSet(), hasLength(out.length));
        at = DateTime(at.year, at.month, at.day + 7, 7);
      }
    });
  });

  // docs/10 §59: a taper has no program message on plan days 2 and 3, and the
  // second day is where the first-week drop-off is — so those two mornings
  // get a plain one, which a cold-turkey plan already has from the program.
  group('a plain morning on plan days 2 and 3', () {
    // Plan day 1, after the evening, so everything armed is still to come.
    final eve = DateTime(2026, 9, 14, 21);

    List<CheckinReminder> mornings(List<CheckinReminder> all) =>
        all.where((c) => c.slot == ProgramSlot.morning).toList();

    test('a taper gets 09:00 on plan days 2 and 3, and no other morning', () {
      final m = mornings(plan(journeyOnDay(1, now: eve), now: eve));
      expect(m.map((c) => (c.reminder.id, c.reminder.at, c.planDay)), [
        (5102, DateTime(2026, 9, 15, 9), 2),
        (5103, DateTime(2026, 9, 16, 9), 3),
      ]);
      expect(
        m.every((c) => c.message == null && c.kind == ReminderKind.checkin),
        isTrue,
      );
    });

    test('cold turkey keeps only its program mornings — exactly one each '
        'day', () {
      final j = journeyOnDay(1, now: eve);
      final ct = j.copyWith(
        plan: j.plan.copyWith(method: QuitMethod.coldTurkey),
      );
      final m = mornings(plan(ct, now: eve));
      expect(m.map((c) => c.reminder.id), [5001, 5002]);
      expect(m.map((c) => c.message), [
        ProgramMessage.d1am,
        ProgramMessage.d2am,
      ]);
    });

    test('the limit is the journey\'s own answer', () {
      final j = journeyOnDay(1, now: eve);
      final m = mornings(plan(j, now: eve));
      expect(m, hasLength(2));
      for (final c in m) {
        expect(c.limit, j.limitOn(c.reminder.at));
      }
    });

    test('quiet hours ending at 10 move it to 10:00', () {
      final m = mornings(
        plan(journeyOnDay(1, now: eve), now: eve, quietStart: 23, quietEnd: 10),
      );
      expect(m, hasLength(2));
      expect(m.every((c) => c.reminder.at.hour == 10), isTrue);
    });

    test('quiet hours covering 9-11 mean no plain morning, evenings still '
        'go', () {
      final out = plan(
        journeyOnDay(1, now: eve),
        now: eve,
        hour: 20,
        quietStart: 8,
        quietEnd: 12,
      );
      expect(mornings(out), isEmpty);
      expect(out.where((c) => c.slot == ProgramSlot.evening), isNotEmpty);
    });

    test('switched off means none', () {
      expect(
        plan(journeyOnDay(1, now: eve), now: eve, enabled: false),
        isEmpty,
      );
    });

    test('a nudge within the hour drops that morning only', () {
      final m = mornings(
        plan(
          journeyOnDay(1, now: eve),
          now: eve,
          busy: [DateTime(2026, 9, 15, 8, 50)],
        ),
      );
      expect(m.map((c) => c.reminder.id), [5103]);
    });

    test('a busy instant exactly an hour away still drops it, and one just '
        'over the hour does not', () {
      final j = journeyOnDay(1, now: eve);
      expect(
        mornings(plan(j, now: eve, busy: [DateTime(2026, 9, 15, 8)]))
            .map((c) => c.reminder.id),
        [5103],
      );
      expect(
        mornings(plan(j, now: eve, busy: [DateTime(2026, 9, 15, 7, 59)]))
            .map((c) => c.reminder.id),
        [5102, 5103],
      );
      // The margin is both ways: ten o'clock, an hour after the 09:00 morning,
      // is as close as eight o'clock, an hour before it.
      expect(
        mornings(plan(j, now: eve, busy: [DateTime(2026, 9, 16, 10, 0)]))
            .map((c) => c.reminder.id),
        [5102],
      );
    });

    test('a busy instant never touches an evening', () {
      final out = plan(
        journeyOnDay(1, now: eve),
        now: eve,
        busy: [DateTime(2026, 9, 15, 20)],
      );
      expect(
        out.map((c) => c.reminder.id),
        contains(CheckinReminderPlanner.firstId + 1),
      );
    });

    test('day 2 already under way: only day 3 is left', () {
      final am = DateTime(2026, 9, 15, 9, 30); // plan day 2, past 09:00
      expect(
        mornings(plan(journeyOnDay(2, now: am), now: am))
            .map((c) => c.reminder.id),
        [5103],
      );
    });

    test('a two-day plan gets no plain morning past its end — Freedom Day\'s '
        'own program morning holds those days', () {
      // The brief expected [5102] here, but Freedom Day is plan day 2 of a
      // two-day taper, so the program already has a morning on days 2, 3 and
      // 4 (5000–5002) and the "no program morning that day" rule leaves
      // nothing for the plain one to take.
      final m = mornings(
        plan(journeyOnDay(1, now: eve, totalDays: 2), now: eve),
      );
      expect(m.map((c) => c.reminder.id), [5000, 5001, 5002]);
      expect(
        m.any(
          (c) => CheckinReminderPlanner.planMorningIds.contains(c.reminder.id),
        ),
        isFalse,
      );
    });

    test('the shortest plan with a plain morning gets exactly days 2 and 3, '
        'and the program takes over from Freedom Day on day 4', () {
      final m = mornings(
        plan(journeyOnDay(1, now: eve, totalDays: 4), now: eve),
      );
      expect(m.map((c) => (c.reminder.id, c.planDay)), [
        (5102, 2),
        (5103, 3),
        (5000, 4),
        (5001, 5),
        (5002, 6),
      ]);
      expect(m.take(2).every((c) => c.message == null), isTrue);
    });

    test('a plan started again gets them on its own day 2 and 3', () {
      final j = journeyOnDay(1, now: eve);
      final again = j.copyWith(plan: j.plan.copyWith(planNumber: 2));
      expect(
        mornings(plan(again, now: eve)).map((c) => c.reminder.id),
        [5102, 5103],
      );
    });

    test('the tap says which morning it was', () {
      final c = mornings(plan(journeyOnDay(1, now: eve), now: eve)).first;
      expect(c.tap.encode(), 'checkin|morning|2|');
    });

    test('a program morning\'s tap carries its message', () {
      final j = journeyOnDay(1, now: eve);
      final ct = j.copyWith(
        plan: j.plan.copyWith(method: QuitMethod.coldTurkey),
      );
      final c = mornings(plan(ct, now: eve)).first;
      expect(c.slot, ProgramSlot.morning);
      expect(c.tap.encode(), 'program|morning|2|d1am');
    });

    test('a mid-plan day arms no plain morning', () {
      expect(mornings(plan(journeyOnDay(5, now: eve), now: eve)), isEmpty);
    });

    test('its ids sit clear of every other schedule', () {
      expect(CheckinReminderPlanner.planMorningIds, [5102, 5103]);
      final others = {
        for (var i = 1000; i < 1024; i++) i,
        TrialReminderPlanner.id,
        for (var i = 0; i < MilestoneReminderPlanner.celebrated.length; i++)
          MilestoneReminderPlanner.idBase + i,
        ...CheckinReminderPlanner.ids,
        ...CheckinReminderPlanner.morningIds,
      };
      expect(
        CheckinReminderPlanner.planMorningIds.where(others.contains),
        isEmpty,
      );
    });
  });
}
