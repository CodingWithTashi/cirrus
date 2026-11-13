import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/widget_prompt_policy.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart';

/// docs/15 QP-C2: when Home offers the home-screen widget.
///
/// The offer is a convenience — logging a puff in one tap — made to somebody
/// who is already logging by hand, once. Every rule below is a reason not to
/// make it, and each is pinned alone against a fixture that otherwise qualifies,
/// so a rule cannot pass because another one is also in the way.
void main() {
  final now = DateTime(2026, 11, 13, 14, 30);

  /// A taper on plan day 3: days 1 and 2 logged at their lines (100 and ~96
  /// puffs), today unlogged. Qualifies on every rule.
  JourneyState taper() => journeyOnDay(3, now: now);

  /// The same account with its history replaced by [byDay] (days back → puffs),
  /// so the "five puffs over two days" boundary can be walked one puff at a time.
  JourneyState withPuffs(Map<int, int> byDay) {
    final base = taper();
    final today = LpDate.dayStart(now);
    return base.copyWith(
      days: {
        for (final e in byDay.entries)
          LpDate.addDays(today, -e.key): DayLog(
            date: LpDate.addDays(today, -e.key),
            puffs: e.value,
            limit: 100,
            hourBuckets: e.value == 0 ? const {} : {10: e.value},
          ),
      },
    );
  }

  bool shows({
    JourneyState? journey,
    int? installed = 0,
    bool alreadyShown = false,
    bool tourRunning = false,
    WidgetAddWay? way = WidgetAddWay.pinDialog,
  }) => WidgetPromptPolicy.shouldShow(
    journey: journey ?? taper(),
    now: now,
    installed: installed,
    alreadyShown: alreadyShown,
    tourRunning: tourRunning,
    way: way,
  );

  test('the fixture qualifies, so each test below isolates one rule', () {
    expect(taper().limitOn(now), greaterThan(0));
    expect(shows(), isTrue);
  });

  group('who it is for', () {
    test('not a cold-turkey account: its line is zero', () {
      final base = taper();
      final cold = base.copyWith(
        plan: base.plan.copyWith(method: QuitMethod.coldTurkey),
      );
      expect(cold.limitOn(now), 0);
      expect(shows(journey: cold), isFalse);
    });

    test('not on a day whose line is zero — the taper\'s tail, Freedom Day on',
        () {
      // Past the plan, `limitOn` is 0 for good: here zero puffs IS the goal and
      // "log a puff faster" is the wrong thing to be offered.
      final late = journeyOnDay(40, now: now);
      expect(late.limitOn(now), 0);
      expect(shows(journey: late), isFalse);
    });

    test('not while a slip is waiting to be resolved', () {
      // The slip card owns that slot; an offer on top of it is tone-deaf.
      final slipping = taper().copyWith(pendingSlipCleanDays: () => 2);
      expect(shows(journey: slipping), isFalse);
    });
  });

  group('five puffs, over two days', () {
    // "In-app logs" are what the offer is for, and the journey does not store a
    // puff's source — `puff_logged{source}` is analytics only. With no widget
    // installed (a separate rule) the day map is the proxy.
    test('exactly five puffs on two days is enough', () {
      expect(shows(journey: withPuffs({0: 3, 1: 2})), isTrue);
    });

    test('four puffs on two days is not', () {
      expect(shows(journey: withPuffs({0: 2, 1: 2})), isFalse);
    });

    test('a hundred puffs on one day is not: one day is one sitting', () {
      expect(shows(journey: withPuffs({0: 100})), isFalse);
      expect(shows(journey: withPuffs({1: 100})), isFalse);
    });

    test('a day with nothing logged is not a day of logging', () {
      expect(shows(journey: withPuffs({0: 0, 1: 9})), isFalse);
    });

    test('nothing logged at all is not', () {
      expect(shows(journey: withPuffs(const {})), isFalse);
    });

    test('the two days need not be consecutive', () {
      expect(shows(journey: withPuffs({0: 3, 6: 2})), isTrue);
    });
  });

  group('once, and never to somebody who has it', () {
    test('not once it has been shown', () {
      expect(shows(alreadyShown: true), isFalse);
    });

    test('not when a widget is already placed', () {
      expect(shows(installed: 1), isFalse);
      expect(shows(installed: 3), isFalse);
    });

    test('not when the count cannot be read: unknown is not zero', () {
      // Offering it on a failed read would hand the card to the people who
      // already have the widget.
      expect(shows(installed: null), isFalse);
    });

    test('not while the Day-1 tour is running', () {
      expect(shows(tourRunning: true), isFalse);
    });

    test('not on a device with no way to add one', () {
      expect(shows(way: null), isFalse);
    });

    test('the walkthrough qualifies the same as the dialog', () {
      expect(shows(way: WidgetAddWay.walkthrough), isTrue);
    });
  });

  group('how it is added', () {
    test('Android with a launcher that can pin: the system dialog', () {
      expect(
        WidgetPromptPolicy.wayFor(pinSupported: true, isApple: false),
        WidgetAddWay.pinDialog,
      );
    });

    test('Android with a launcher that cannot pin: no card at all', () {
      // One tap is the promise. A walkthrough would be a different, longer
      // ask, and a button that does nothing is worse than no card.
      expect(WidgetPromptPolicy.wayFor(pinSupported: false, isApple: false), isNull);
    });

    test('iOS: the walkthrough, whatever the plugin says about pinning', () {
      // No app can add a widget on an iPhone; `canPin` is false there and the
      // walkthrough must not depend on it.
      expect(
        WidgetPromptPolicy.wayFor(pinSupported: false, isApple: true),
        WidgetAddWay.walkthrough,
      );
      expect(
        WidgetPromptPolicy.wayFor(pinSupported: true, isApple: true),
        WidgetAddWay.walkthrough,
      );
    });
  });
}
