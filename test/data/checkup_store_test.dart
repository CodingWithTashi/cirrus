import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart';

/// docs/15 QP-B7. The program's check-ups are answers the person gives about
/// their own nicotine use. They live on the journey document, and they are also
/// REPORTED the moment they are given: an older build on a second device
/// rewrites the whole journey document and would drop the stored copy, so the
/// analytics event is the record that cannot be overwritten.
void main() {
  final now = DateTime(2026, 11, 12, 15, 30);

  ({ProviderContainer c, RecordingAnalytics a}) open() {
    final a = RecordingAnalytics();
    final c = ProviderContainer(
      overrides: fastBackendOverrides(now: now, analytics: a),
    );
    addTearDown(c.dispose);
    c
        .read(quitStoreProvider.notifier)
        .replaceForTest(journeyOnDay(10, now: now));
    return (c: c, a: a);
  }

  JourneyState journey(ProviderContainer c) => c.read(quitStoreProvider)!;
  final today = LpDate.dayStart(now);

  test('an answer is filed under today, by question', () {
    final (:c, :a) = open();
    c
        .read(quitStoreProvider.notifier)
        .recordCheckup(CheckupKind.nicotine, CheckupAnswer.pouches);
    expect(journey(c).checkups[today], {
      CheckupKind.nicotine: CheckupAnswer.pouches,
    });
  });

  test('a different question the same day sits beside it', () {
    final (:c, :a) = open();
    final store = c.read(quitStoreProvider.notifier);
    store.recordCheckup(CheckupKind.nicotine, CheckupAnswer.noOther);
    store.recordCheckup(CheckupKind.vaped30, CheckupAnswer.notVaped);
    expect(journey(c).checkups[today], {
      CheckupKind.nicotine: CheckupAnswer.noOther,
      CheckupKind.vaped30: CheckupAnswer.notVaped,
    });
  });

  test('answering again the same day replaces the answer', () {
    final (:c, :a) = open();
    final store = c.read(quitStoreProvider.notifier);
    store.recordCheckup(CheckupKind.nicotine, CheckupAnswer.noOther);
    store.recordCheckup(CheckupKind.nicotine, CheckupAnswer.cigarettes);
    expect(journey(c).checkups[today], {
      CheckupKind.nicotine: CheckupAnswer.cigarettes,
    });
  });

  test('an answer that belongs to another question is refused outright', () {
    final (:c, :a) = open();
    final before = journey(c);
    c
        .read(quitStoreProvider.notifier)
        .recordCheckup(CheckupKind.nicotine, CheckupAnswer.vaped);
    expect(identical(journey(c), before), isTrue, reason: 'nothing written');
    expect(a.propsOfAll('checkup_answered'), isEmpty);
  });

  test('the same answer twice is one write and one event', () {
    final (:c, :a) = open();
    final store = c.read(quitStoreProvider.notifier);
    store.recordCheckup(CheckupKind.nicotine, CheckupAnswer.patchGum);
    final after = journey(c);
    store.recordCheckup(CheckupKind.nicotine, CheckupAnswer.patchGum);
    expect(identical(journey(c), after), isTrue);
    expect(a.propsOfAll('checkup_answered'), hasLength(1));
  });

  group('what is reported', () {
    test('every accepted answer, as the question and the answer', () {
      final (:c, :a) = open();
      c
          .read(quitStoreProvider.notifier)
          .recordCheckup(CheckupKind.nicotine, CheckupAnswer.cigarettes);
      expect(a.propsOfAll('checkup_answered'), [
        {'kind': 'nicotine', 'answer': 'cigarettes'},
      ]);
      expect(
        a.propsOfAll('quit_status_reported'),
        isEmpty,
        reason: 'the nicotine question says nothing about vaping',
      );
    });

    test('a vaping question also reports the quit status at its horizon', () {
      final (:c, :a) = open();
      final store = c.read(quitStoreProvider.notifier);
      store.recordCheckup(CheckupKind.vaped30, CheckupAnswer.notVaped);
      store.recordCheckup(CheckupKind.vaped90, CheckupAnswer.vaped);
      expect(a.propsOfAll('quit_status_reported'), [
        {'at': 30, 'vape_free': 'true'},
        {'at': 90, 'vape_free': 'false'},
      ]);
    });
  });

  test('with no journey it does nothing', () {
    final c = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(c.dispose);
    c
        .read(quitStoreProvider.notifier)
        .recordCheckup(CheckupKind.nicotine, CheckupAnswer.noOther);
    expect(c.read(quitStoreProvider), isNull);
  });
}
