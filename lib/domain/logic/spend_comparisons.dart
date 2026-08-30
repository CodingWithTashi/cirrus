/// What a year of vaping money actually buys. Pure Dart — no Flutter imports.
///
/// Replaces three fixed sentences chosen by two hardcoded thresholds ("That's
/// a new phone. Every year." for anything under $800) with a catalogue that
/// divides cleanly into the user's own figure and leans on what they told us
/// they want out of this.
///
/// ## Prices are OUR claims about the world, not the user's data
///
/// Every other number in this app derives from something the user typed. These
/// do not, so they are held to a different standard: each is a rounded US
/// median band, listed below with its basis, and **no price is ever rendered**
/// — an item's price is only ever a divisor. That is also what keeps the
/// screen honest in a non-USD locale, since `LpFormat.money` hardcodes `$` and
/// the app does not know the user's country. See docs/02 §8.
///
/// | item            |  USD | basis                                        |
/// |-----------------|-----:|----------------------------------------------|
/// | gymMonth        |   45 | national-chain monthly membership             |
/// | concertTicket   |  120 | mid-tier arena, face value plus fees          |
/// | runningShoes    |  160 | a mainstream running shoe at full price       |
/// | dentalCleaning  |  200 | routine cleaning and exam, no insurance       |
/// | winterCoat      |  240 | an insulated coat rated for real winter       |
/// | festivalTicket  |  350 | weekend general admission plus camping        |
/// | weekendAway     |  420 | two nights plus travel, domestic              |
/// | bike            |  620 | a reliable commuter bike, new                 |
/// | drivingLessons  |  750 | a full course to test standard                |
/// | newPhone        |  800 | a current mid-range handset, unlocked         |
/// | laptop          | 1300 | a mid-range laptop that will last             |
/// | emergencyFund   | 1500 | one month of essential expenses               |
/// | yogaYear        | 1560 | unlimited studio membership, twelve months    |
/// | monthOfRent     | 1600 | US median one-bedroom, monthly                |
/// | familyHoliday   | 3200 | a week away for a family of four              |
/// | usedCar         | 4500 | a running used car                            |
///
/// Reviewed 2026-08-30. Re-check before each release; a stale price is a
/// quiet lie, and `spend_comparisons_test.dart` bounds them but cannot date
/// them.
library;

import '../models/enums.dart';

enum SpendItem {
  gymMonth(price: 45, whys: {WhyChip.fitness}),
  concertTicket(price: 120),
  runningShoes(price: 160, whys: {WhyChip.fitness, WhyChip.health}),
  dentalCleaning(price: 200, whys: {WhyChip.health, WhyChip.appearance}),
  winterCoat(price: 240),
  festivalTicket(price: 350, whys: {WhyChip.freedom}, maxAge: 34),
  weekendAway(price: 420),
  bike(price: 620, whys: {WhyChip.fitness, WhyChip.freedom}),
  drivingLessons(price: 750, whys: {WhyChip.freedom}, maxAge: 24),
  newPhone(price: 800),
  laptop(price: 1300),
  emergencyFund(price: 1500, whys: {WhyChip.family, WhyChip.money}, minAge: 25),
  yogaYear(price: 1560, whys: {WhyChip.fitness, WhyChip.health}),
  monthOfRent(price: 1600, whys: {WhyChip.money}),
  familyHoliday(price: 3200, whys: {WhyChip.family}),
  usedCar(price: 4500, whys: {WhyChip.freedom});

  const SpendItem({
    required this.price,
    // Deliberately unused today — see the doc comment on [audience]. The axis
    // exists so the decision is reviewable and one line to reverse, not so it
    // can be quietly deleted by a linter.
    // ignore: unused_element_parameter
    this.audience = const <Gender>{},
    this.whys = const <WhyChip>{},
    this.minAge,
    this.maxAge,
  });

  final double price;

  /// EMPTY means universal, which is what every item ships as.
  ///
  /// The axis exists so the decision is reviewable rather than unavailable,
  /// but nothing uses it: in this price band every genuinely
  /// gender-differentiated purchase is grooming, appearance, or childcare, and
  /// all three read as a stereotype the moment someone notices the pattern.
  /// `whys` and age band already tailor, and both are self-declared intent,
  /// which is a strictly better signal than an inference from a demographic.
  /// [Gender.nonBinary] is labelled "Non-binary / prefer not to say", so it
  /// resolves to universal items only — never to a guess.
  final Set<Gender> audience;

  /// EMPTY means it applies whatever they said they want out of this.
  final Set<WhyChip> whys;

  final int? minAge;
  final int? maxAge;

  bool matches({Gender? gender, int? age, Set<WhyChip> whys = const {}}) {
    if (audience.isNotEmpty && (gender == null || !audience.contains(gender))) {
      return false;
    }
    if (this.whys.isNotEmpty && !whys.any(this.whys.contains)) return false;
    if (minAge != null && (age == null || age < minAge!)) return false;
    if (maxAge != null && (age == null || age > maxAge!)) return false;
    return true;
  }

  /// How specific this item is; a tailored item outranks a universal one at an
  /// equal fit.
  int get specificity =>
      (audience.isEmpty ? 0 : 1) +
      (whys.isEmpty ? 0 : 1) +
      ((minAge ?? maxAge) == null ? 0 : 1);
}

class SpendComparisonMatch {
  const SpendComparisonMatch(this.item, this.multiple);

  final SpendItem item;

  /// Always 1..[SpendComparisons.maxMultiple].
  final int multiple;
}

abstract final class SpendComparisons {
  /// Above this the comparison stops meaning anything — "47 haircuts" is a
  /// number, not a picture.
  static const int maxMultiple = 12;

  /// The best-fitting comparison for [amount], or null when nothing in the
  /// catalogue divides into it.
  ///
  /// Deterministic by construction — no `Random`, and the item name is the
  /// final tiebreak — so the same answers always produce the same sentence.
  /// A user who backs up and comes forward again must not see it change.
  static SpendComparisonMatch? best({
    required double amount,
    Gender? gender,
    int? age,
    Set<WhyChip> whys = const {},
  }) {
    if (amount <= 0) return null;

    final candidates = <SpendComparisonMatch>[];
    for (final item in SpendItem.values) {
      if (!item.matches(gender: gender, age: age, whys: whys)) continue;
      final multiple = (amount / item.price).floor();
      // Never "0.6 of a bike", never "47 haircuts".
      if (multiple < 1 || multiple > maxMultiple) continue;
      candidates.add(SpendComparisonMatch(item, multiple));
    }
    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => _rank(a, amount).compareTo(_rank(b, amount)));
    return candidates.first;
  }

  /// Leftover, in five-point buckets. Bucketing rather than ranking on the raw
  /// percentage is what lets tailoring actually show: an exact-fit universal
  /// item would otherwise beat a tailored one that fits within a point or two,
  /// and since some universal item usually lands near-exactly, the personalised
  /// half of this feature would almost never appear.
  static const int _slackBucket = 5;

  /// Sortable key. Fit bucket first (so the comparison is always close to
  /// true), then specificity (a tailored item wins a near-tie), then the exact
  /// leftover, then a mild preference for small multiples, then the name —
  /// which makes the order total, and therefore the result stable.
  static String _rank(SpendComparisonMatch m, double amount) {
    final slack = (((amount - m.multiple * m.item.price) / amount) * 100)
        .round();
    final bucket = (slack ~/ _slackBucket).toString().padLeft(2, '0');
    final tailored = 9 - m.item.specificity;
    final chunky = m.multiple <= 3 ? 0 : 1;
    return '$bucket$tailored${slack.toString().padLeft(3, '0')}'
        '$chunky${m.item.name}';
  }
}
