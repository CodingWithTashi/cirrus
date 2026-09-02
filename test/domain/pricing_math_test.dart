import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/pricing_math.dart';

void main() {
  group('PricingMath.yearlySavingsPercent', () {
    test('the launch prices save 74% — the number the mock hardcoded', () {
      expect(
        PricingMath.yearlySavingsPercent(
          yearly: 39.99,
          weekly: 2.99,
          yearlyCurrency: 'USD',
          weeklyCurrency: 'USD',
        ),
        74,
      );
    });

    test('a missing side means no badge, never 0%', () {
      expect(
        PricingMath.yearlySavingsPercent(yearly: 39.99, weekly: null),
        isNull,
      );
      expect(
        PricingMath.yearlySavingsPercent(yearly: null, weekly: 2.99),
        isNull,
      );
    });

    test('mixed currencies cannot be compared', () {
      expect(
        PricingMath.yearlySavingsPercent(
          yearly: 39.99,
          weekly: 2.99,
          yearlyCurrency: 'EUR',
          weeklyCurrency: 'USD',
        ),
        isNull,
      );
    });

    test('no saving is no badge', () {
      expect(
        PricingMath.yearlySavingsPercent(yearly: 200, weekly: 2.99),
        isNull,
      );
      expect(
        PricingMath.yearlySavingsPercent(yearly: 155.48, weekly: 2.99),
        isNull,
      );
    });

    test('non-positive amounts are refused', () {
      expect(PricingMath.yearlySavingsPercent(yearly: 0, weekly: 2.99), isNull);
      expect(PricingMath.yearlySavingsPercent(yearly: 39.99, weekly: 0), isNull);
    });
  });

  test('perWeek spreads a yearly amount over 52 weeks', () {
    expect(PricingMath.perWeek(52), 1);
    expect(PricingMath.perWeek(39.99), closeTo(0.769, 0.001));
  });
}
