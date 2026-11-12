import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/pending_puffs.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/analytics/analytics.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart';

/// The things people do to come back, which the dashboard could not see.
///
/// Read on Nov 11 2026: the only habit-loop event was `puff_logged`. So
/// somebody quitting cold turkey who opened the app every evening and
/// confirmed a vape-free day left no trace of having done anything, a mood
/// check-in was invisible, a tap on the home-screen widget was
/// indistinguishable from one in the app, and signing out — which five of
/// seven people did in order to start over — had to be inferred from the
/// sequence of screens before it.
void main() {
  final now = DateTime(2026, 11, 12, 20, 15);

  (ProviderContainer, RecordingAnalytics) boot({
    JourneyState? journey,
    bool premium = true,
    AnalyticsSink? sink,
  }) {
    final analytics = RecordingAnalytics();
    final c = ProviderContainer(
      overrides: fastBackendOverrides(
        now: now,
        analytics: sink ?? analytics,
        premium: premium,
      ),
    );
    addTearDown(c.dispose);
    c
        .read(quitStoreProvider.notifier)
        .replaceForTest(journey ?? journeyOnDay(5, now: now));
    return (c, analytics);
  }

  /// Cold turkey from day one: the line is zero on every day, and the days
  /// behind today were never confirmed.
  JourneyState coldTurkey(int day) {
    final j = journeyOnDay(day, now: now);
    return j.copyWith(
      plan: j.plan.copyWith(method: QuitMethod.coldTurkey),
      days: {
        for (final e in j.days.entries)
          e.key: DayLog(date: e.key, puffs: 0, limit: 0),
      },
    );
  }

  group('day_confirmed', () {
    test('confirming today on a zero-limit day', () {
      final (c, analytics) = boot(journey: coldTurkey(3));
      c.read(quitStoreProvider.notifier).confirmVapeFreeDay();

      expect(analytics.propsOfAll('day_confirmed'), [
        {'day': 'today', 'zero_day': 'true'},
      ]);
    });

    test('confirming today on a taper day that still has a limit', () {
      final (c, analytics) = boot();
      c.read(quitStoreProvider.notifier).confirmVapeFreeDay();

      expect(analytics.propsOfAll('day_confirmed'), [
        {'day': 'today', 'zero_day': 'false'},
      ]);
    });

    test('answering the morning-after card is a past day', () {
      final (c, analytics) = boot(journey: coldTurkey(3));
      c
          .read(quitStoreProvider.notifier)
          .confirmVapeFreeDay(date: LpDate.addDays(LpDate.dayStart(now), -1));

      expect(analytics.propsOfAll('day_confirmed'), [
        {'day': 'past', 'zero_day': 'true'},
      ]);
    });

    test('confirming a day twice is one confirmation', () {
      final (c, analytics) = boot(journey: coldTurkey(3));
      c.read(quitStoreProvider.notifier)
        ..confirmVapeFreeDay()
        ..confirmVapeFreeDay();

      expect(analytics.propsOfAll('day_confirmed'), hasLength(1));
    });
  });

  test('mood_checked_in carries the mood and never the note', () {
    final (c, analytics) = boot();
    c
        .read(quitStoreProvider.notifier)
        .checkInMood(Mood.rough, note: 'argued with my sister');

    expect(analytics.propsOfAll('mood_checked_in'), [
      {'mood': 'rough'},
    ]);
  });

  group('puff_logged says where the tap happened', () {
    test('in the app', () {
      final (c, analytics) = boot();
      c.read(quitStoreProvider.notifier).logPuff();

      expect(analytics.propsOfAll('puff_logged'), [
        {'source': 'app'},
      ]);
    });

    test('off the home screen or the wrist', () async {
      final (c, analytics) = boot();
      await c
          .read(quitStoreProvider.notifier)
          .applyPendingPuffs([
            PendingPuff(id: 'a', seq: 1, at: now, delta: 1),
            PendingPuff(id: 'b', seq: 2, at: now, delta: 1),
          ], now: now);

      expect(analytics.propsOfAll('puff_logged'), [
        {'source': 'widget'},
        {'source': 'widget'},
      ]);
    });
  });

  group('signed_out', () {
    test('is reported with where the person was, before the identity goes', () {
      final order = _Ordered();
      final (c, _) = boot(sink: order, premium: false);
      c.read(quitStoreProvider.notifier).signOut();

      final at = order.log.indexOf('signed_out');
      expect(at, isNonNegative);
      expect(at, lessThan(order.log.indexOf('<reset>')));
      expect(order.props['signed_out'], {
        'plan_day': 5,
        'past_freedom': 'false',
        'premium': 'false',
      });
    });

    test('says so when the plan had already ended', () {
      final order = _Ordered();
      final (c, _) = boot(sink: order, journey: journeyOnDay(36, now: now));
      c.read(quitStoreProvider.notifier).signOut();

      expect(order.props['signed_out'], {
        'plan_day': 36,
        'past_freedom': 'true',
        'premium': 'true',
      });
    });
  });
}

/// Records events and resets in one list, so "before the reset" is checkable.
class _Ordered implements AnalyticsSink {
  final List<String> log = [];
  final Map<String, Map<String, Object>> props = {};

  @override
  void track(AnalyticsEvent event) {
    log.add(event.name);
    props[event.name] = event.props;
  }

  @override
  void screenViewed(String name) {}

  @override
  void identify(String userId) {}

  @override
  void reset() => log.add('<reset>');
}
