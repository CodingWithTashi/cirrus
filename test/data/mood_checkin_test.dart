import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart';

/// docs/15 QP-B3. `checkInMood` counted every call, and seven of them award a
/// badge. The daily card makes the check-in a daily question that can be
/// answered again, so the counter has to count DAYS, not taps: a changed mind is
/// still one check-in.
void main() {
  late DateTime clock;
  late RecordingAnalytics analytics;

  ProviderContainer open() {
    clock = DateTime(2026, 11, 12, 15, 30);
    analytics = RecordingAnalytics();
    final c = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(analytics: analytics),
        // A moving clock, so a test can step to the next day.
        nowProvider.overrideWithValue(() => clock),
      ],
    );
    addTearDown(c.dispose);
    c.read(quitStoreProvider.notifier).replaceForTest(
      journeyOnDay(5, now: clock),
    );
    return c;
  }

  JourneyState journey(ProviderContainer c) => c.read(quitStoreProvider)!;
  DayLog today(ProviderContainer c) => journey(c).logFor(clock)!;
  void nextDay() => clock = LpDate.addDays(clock, 1);

  test('the first answer of the day counts once and is stored', () {
    final c = open();
    c.read(quitStoreProvider.notifier).checkInMood(Mood.rough);

    expect(journey(c).moodCheckIns, 1);
    expect(today(c).mood, Mood.rough);
  });

  test('changing the answer the same day updates it and counts nothing', () {
    final c = open();
    final store = c.read(quitStoreProvider.notifier);
    store.checkInMood(Mood.rough, note: 'bad morning');
    store.checkInMood(Mood.good, note: 'better after lunch');

    expect(journey(c).moodCheckIns, 1);
    expect(today(c).mood, Mood.good, reason: 'the later answer stands');
    expect(today(c).moodNote, 'better after lunch');
  });

  test('answering the same thing twice counts nothing either', () {
    final c = open();
    final store = c.read(quitStoreProvider.notifier);
    store.checkInMood(Mood.okay);
    store.checkInMood(Mood.okay);
    expect(journey(c).moodCheckIns, 1);
  });

  test('a new day is a new check-in', () {
    final c = open();
    final store = c.read(quitStoreProvider.notifier);
    store.checkInMood(Mood.okay);
    nextDay();
    store.checkInMood(Mood.okay);
    nextDay();
    store.checkInMood(Mood.good);
    expect(journey(c).moodCheckIns, 3);
  });

  test('seven answers on one day do not earn the week badge', () {
    final c = open();
    final store = c.read(quitStoreProvider.notifier);
    for (final mood in [...Mood.values, Mood.okay, Mood.good]) {
      store.checkInMood(mood);
    }
    expect(journey(c).moodCheckIns, 1);
    expect(journey(c).earnedBadges, isNot(contains('moodWeek')));
  });

  test('seven days of answers do', () {
    final c = open();
    final store = c.read(quitStoreProvider.notifier);
    for (var i = 0; i < 7; i++) {
      store.checkInMood(Mood.okay);
      nextDay();
    }
    expect(journey(c).moodCheckIns, 7);
    expect(journey(c).earnedBadges, contains('moodWeek'));
  });

  test('the event is reported once a day, with the mood and never the note', () {
    // Like `day_confirmed` ("confirming a day twice is one confirmation"): the
    // funnel counts days with a check-in, so a changed answer is the same one.
    final c = open();
    final store = c.read(quitStoreProvider.notifier);
    store.checkInMood(Mood.rough, note: 'argued with my sister');
    store.checkInMood(Mood.good);

    expect(analytics.propsOfAll('mood_checked_in'), [
      {'mood': 'rough'},
    ]);
    nextDay();
    store.checkInMood(Mood.great);
    expect(analytics.propsOfAll('mood_checked_in'), [
      {'mood': 'rough'},
      {'mood': 'great'},
    ]);
  });

  test('with no journey it does nothing', () {
    final c = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(c.dispose);
    c.read(quitStoreProvider.notifier).checkInMood(Mood.okay);
    expect(c.read(quitStoreProvider), isNull);
  });
}
