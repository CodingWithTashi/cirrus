import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/spend_comparisons.dart';
import 'package:last_puff/domain/models/models.dart';

void main() {
  group('the catalogue itself', () {
    test('every price sits in a band a year of vaping could reach', () {
      // A typo'd price is how you get "that's 400 coffees". The bound is wide
      // on purpose — it is a smoke alarm, not a pricing policy.
      for (final item in SpendItem.values) {
        expect(
          item.price,
          inInclusiveRange(40, 6000),
          reason: '${item.name} is priced outside the band',
        );
      }
    });

    test('ships with the gender axis empty', () {
      // The mechanism exists so the decision is reviewable; nothing uses it.
      // If this ever fails, the editorial rule in tailoring.dart applies and
      // someone signed off on the item deliberately.
      for (final item in SpendItem.values) {
        expect(item.audience, isEmpty, reason: item.name);
      }
    });

    test('no two items share a price, so ranking never coin-flips', () {
      final prices = SpendItem.values.map((i) => i.price).toSet();
      expect(prices, hasLength(SpendItem.values.length));
    });
  });

  group('SpendComparisons.best', () {
    test('is deterministic across repeated calls', () {
      // The same answers must always produce the same sentence — someone who
      // backs up and comes forward again must not see it change.
      for (var i = 0; i < 100; i++) {
        final m = SpendComparisons.best(
          amount: 1300,
          age: 23,
          whys: const {WhyChip.fitness},
        );
        expect(m!.item, SpendComparisons.best(
          amount: 1300,
          age: 23,
          whys: const {WhyChip.fitness},
        )!.item);
      }
    });

    test('the multiple is always a picture, never a number', () {
      for (var amount = 50.0; amount <= 12000; amount += 37) {
        final m = SpendComparisons.best(amount: amount, age: 30);
        if (m == null) continue;
        expect(m.multiple, inInclusiveRange(1, SpendComparisons.maxMultiple));
        // It must never claim more than the user actually has.
        expect(m.multiple * m.item.price, lessThanOrEqualTo(amount));
      }
    });

    test('picks the item that divides most cleanly', () {
      // $1300/yr with nothing declared: only universal items are eligible, and
      // a laptop at $1300 lands exactly where a phone leaves $500 over.
      final m = SpendComparisons.best(amount: 1300, age: 23)!;
      expect(m.item, SpendItem.laptop);
      expect(m.multiple, 1);
    });

    test('every realistic yearly spend gets a close comparison', () {
      // \$10-\$150 a week is the range this app is actually for. Across all of
      // it there must always be an item, and it must stay close to true — a
      // comparison that explains half the money is just a noun.
      for (var amount = 520.0; amount <= 7800; amount += 29) {
        final m = SpendComparisons.best(amount: amount, age: 30);
        expect(m, isNotNull, reason: 'no comparison for \$amount');
        final leftover = (amount - m!.multiple * m.item.price) / amount;
        expect(leftover, lessThan(0.2), reason: '\$amount -> \${m.item.name}');
      }
    });

    test('a declared why pulls in a tailored item at a near-equal fit', () {
      // Same $1300 as above, which without a why picks the universal laptop.
      // Running shoes fit within a couple of points, so the declared reason
      // decides it.
      final m = SpendComparisons.best(
        amount: 1300,
        age: 23,
        whys: const {WhyChip.fitness},
      )!;
      expect(m.item.whys, contains(WhyChip.fitness));
      expect(m.item, isNot(SpendItem.laptop));
    });

    test('an age band gates the items that name one', () {
      // Driving lessons are for someone who might not drive yet.
      final young = SpendComparisons.best(
        amount: 750,
        age: 19,
        whys: const {WhyChip.freedom},
      );
      expect(young!.item, SpendItem.drivingLessons);

      final older = SpendComparisons.best(
        amount: 750,
        age: 52,
        whys: const {WhyChip.freedom},
      );
      expect(older?.item, isNot(SpendItem.drivingLessons));
    });

    test('an unknown age never matches an age-gated item', () {
      for (var amount = 50.0; amount <= 12000; amount += 53) {
        final m = SpendComparisons.best(
          amount: amount,
          whys: WhyChip.values.toSet(),
        );
        if (m == null) continue;
        expect(m.item.minAge, isNull, reason: '${m.item.name} at $amount');
        expect(m.item.maxAge, isNull, reason: '${m.item.name} at $amount');
      }
    });

    test('an unstated or non-binary gender only ever gets universal items', () {
      // "Non-binary / prefer not to say" resolves to universal items, never to
      // a guess and never to a third bucket, which is a guess wearing a hat.
      for (final gender in [null, Gender.nonBinary]) {
        for (var amount = 50.0; amount <= 12000; amount += 53) {
          final m = SpendComparisons.best(
            amount: amount,
            gender: gender,
            age: 30,
            whys: WhyChip.values.toSet(),
          );
          if (m == null) continue;
          expect(m.item.audience, isEmpty, reason: '$gender at $amount');
        }
      }
    });

    test('returns null rather than inventing a fallback', () {
      // Below the catalogue floor an honest empty state is the right answer —
      // the screen renders nothing.
      expect(SpendComparisons.best(amount: 0), isNull);
      expect(SpendComparisons.best(amount: -100), isNull);
      expect(SpendComparisons.best(amount: 20), isNull);
    });

    test('an absurd amount degrades to nothing rather than to nonsense', () {
      // The keypad allows \$9999 a week. Past the catalogue's ceiling the
      // honest answer is silence, not "that's 400 laptops".
      final m = SpendComparisons.best(amount: 500000, age: 40);
      expect(m, isNull);
    });
  });
}
