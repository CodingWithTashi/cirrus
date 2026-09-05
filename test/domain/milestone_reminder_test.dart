import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/reminder_planner.dart';

/// The streak-celebration reminder (design frame 51 #2).
///
/// The one thing this notification must never do is congratulate somebody for
/// a day they did not have, so most of these cases are about when it stays
/// silent.
void main() {
  MilestoneCelebration? plan({
    Set<String> earned = const {},
    Set<String> celebrated = const {},
    DateTime? now,
    int quietStart = 23,
    int quietEnd = 8,
    bool enabled = true,
  }) => MilestoneReminderPlanner.plan(
    earnedBadges: earned,
    celebratedBadges: celebrated,
    now: now ?? DateTime(2026, 9, 4, 14),
    quietStartHour: quietStart,
    quietEndHour: quietEnd,
    enabled: enabled,
  );

  group('staying quiet', () {
    test('nothing earned, nothing to say', () {
      expect(plan(), isNull);
    });

    test('a badge already celebrated is never celebrated twice', () {
      expect(
        plan(earned: {'weekFlame'}, celebrated: {'weekFlame'}),
        isNull,
      );
    });

    test('notifications off means silence', () {
      expect(plan(earned: {'weekFlame'}, enabled: false), isNull);
    });

    test('the twelve non-streak badges are deliberately silent', () {
      // They are all earned while the person is already looking at the app.
      // A push about something they just did on screen is noise, and this is
      // a permission you only get asked for once.
      for (final badge in [
        'firstLog',
        'firstCraving',
        'tenCravings',
        'hundredSaved',
        'fiveHundredSaved',
        'moodWeek',
        'quarterCurve',
        'cleanWeekend',
        'halfNicotine',
        'comeback',
        'firstPost',
        'helpedSos',
      ]) {
        expect(plan(earned: {badge}), isNull, reason: '$badge should be quiet');
      }
    });
  });

  group('when it lands', () {
    test('earned in the afternoon, celebrated tomorrow morning', () {
      final celebration = plan(
        earned: {'spark'},
        now: DateTime(2026, 9, 4, 14),
      )!;

      expect(celebration.reminder.at, DateTime(2026, 9, 5, 8));
    });

    test('earned before dawn, celebrated the same morning', () {
      final celebration = plan(
        earned: {'spark'},
        now: DateTime(2026, 9, 4, 3),
      )!;

      expect(celebration.reminder.at, DateTime(2026, 9, 4, 8));
    });

    test('8am is already outside the default quiet window', () {
      // 23 -> 8: the hour the celebration wants is the first non-quiet one.
      expect(ReminderPlanner.isQuiet(8, 23, 8), isFalse);
    });

    test('rolling to tomorrow keeps the hour', () {
      // It used to roll with LpDate.addDays, which lands on local MIDNIGHT
      // because it exists to build day keys. Under the default 23→8 quiet
      // window the correction below happened to push 00:00 back up to 08:00,
      // so the bug only showed for someone who had widened their quiet hours —
      // and then the celebration fired at midnight.
      final celebration = plan(
        earned: {'spark'},
        now: DateTime(2026, 9, 4, 14),
        quietStart: 0,
        quietEnd: 0, // start == end means "no quiet hours at all"
      )!;

      expect(celebration.reminder.at, DateTime(2026, 9, 5, 8));
    });

    test('rolling over the end of a month lands on the first', () {
      final celebration = plan(
        earned: {'spark'},
        now: DateTime(2026, 9, 30, 14),
        quietStart: 0,
        quietEnd: 0,
      )!;

      expect(celebration.reminder.at, DateTime(2026, 10, 1, 8));
    });

    test('a quiet window over 8am pushes it FORWARD, never back', () {
      // Backwards is how the trial reminder once fired two days early.
      final celebration = plan(
        earned: {'spark'},
        now: DateTime(2026, 9, 4, 14),
        quietStart: 6,
        quietEnd: 10,
      )!;

      expect(celebration.reminder.at, DateTime(2026, 9, 5, 10));
    });
  });

  group('which badge', () {
    test('the strongest uncelebrated one wins', () {
      // inferno and freedomDay can genuinely land together.
      final celebration = plan(earned: {'inferno', 'freedomDay'})!;

      expect(celebration.badgeId, 'freedomDay');
    });

    test('the choice is deterministic, so the fingerprint is stable', () {
      // The coordinator does nothing when the fingerprint is unchanged, and a
      // planner that picked differently on each call would reschedule on every
      // puff tap.
      final first = plan(earned: {'spark', 'weekFlame'})!;
      final second = plan(earned: {'weekFlame', 'spark'})!;

      expect(first.badgeId, second.badgeId);
      expect(first.reminder.id, second.reminder.id);
    });

    test('one celebration settles every badge owed at that moment', () {
      // A reinstall restores `earnedBadges` from the server while the record
      // of what has been celebrated is device-local, so four can be owed at
      // once. Announcing the strongest and settling the rest is what stops
      // four separate 08:00 notifications about milestones from weeks ago.
      final celebration = plan(
        earned: {'spark', 'weekFlame', 'twoWeekFlame', 'inferno'},
      )!;

      expect(celebration.badgeId, 'inferno');
      expect(celebration.covers, {
        'spark',
        'weekFlame',
        'twoWeekFlame',
        'inferno',
      });
    });

    test('an ordinary single milestone covers only itself', () {
      expect(plan(earned: {'weekFlame'})!.covers, {'weekFlame'});
    });

    test('celebrating the strongest still leaves the weaker one owed', () {
      final celebration = plan(
        earned: {'spark', 'weekFlame'},
        celebrated: {'weekFlame'},
      )!;

      expect(celebration.badgeId, 'spark');
    });
  });

  group('ids', () {
    test('never collide with the danger hours or the trial reminder', () {
      // A cancel that reached either would delete a promise this one knows
      // nothing about — the failure a shared cancelAll() once caused.
      for (final badge in MilestoneReminderPlanner.celebrated) {
        final id = MilestoneReminderPlanner.idBase +
            MilestoneReminderPlanner.celebrated.indexOf(badge);
        expect(id, greaterThanOrEqualTo(3000));
        expect(id, isNot(TrialReminderPlanner.id));
        expect(id, isNot(inInclusiveRange(1000, 1023)));
      }
    });

    test('one id per badge, never reused', () {
      final ids = MilestoneReminderPlanner.celebrated
          .map((b) => MilestoneReminderPlanner.idBase +
              MilestoneReminderPlanner.celebrated.indexOf(b))
          .toSet();

      expect(ids, hasLength(MilestoneReminderPlanner.celebrated.length));
    });
  });

  test('the celebrated list is exactly the flame family the grid shows', () {
    // The milestones screen already marks these five as the ember family. Two
    // lists of the same thing drift — that is what B12 was — so this one is
    // read out of the screen rather than restated here.
    final source = File(
      'lib/features/milestones/milestones_screen.dart',
    ).readAsStringSync();
    final defs = RegExp(r"\('(\w+)', '[^']*', (true|false)\)")
        .allMatches(source);
    final emberFamily = [
      for (final m in defs)
        if (m.group(2) == 'true') m.group(1)!,
    ];

    expect(emberFamily, isNotEmpty, reason: 'the badge catalogue moved');
    expect(
      MilestoneReminderPlanner.celebrated.toSet(),
      emberFamily.toSet(),
      reason: 'a badge joined or left the flame family and the celebration '
          'list did not follow',
    );
  });
}
