import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/plan_paces.dart';

/// docs/15 QP-A8. A taper is now at most six weeks. A quit date inside six
/// weeks is what NICE NG209 advises for smoking, each week of delay to a quit
/// date raised the chance of lapsing by 19% (Hughes 2010), and tapers used to
/// run to 90 days.
void main() {
  test('the choices are 14, 21, 30 and 42 days, and nothing longer', () {
    expect(PlanPaces.options, [14, 21, 30, 42]);
    expect(PlanPaces.options.last, 42, reason: 'six weeks is the ceiling');
  });

  test('30 stays the default, and is one of the choices', () {
    expect(PlanPaces.defaultDays, 30);
    expect(PlanPaces.options, contains(PlanPaces.defaultDays));
  });

  group('clamp: a length a draft or a link carries', () {
    test('a length on offer is kept', () {
      for (final days in PlanPaces.options) {
        expect(PlanPaces.clamp(days), days);
      }
    });

    test('the retired 60 and 90 come down to the longest on offer', () {
      expect(PlanPaces.clamp(60), 42);
      expect(PlanPaces.clamp(90), 42);
    });

    test('anything beyond the ceiling comes down to it', () {
      expect(PlanPaces.clamp(43), 42);
      expect(PlanPaces.clamp(365), 42);
    });

    test('a missing or nonsensical length becomes the default, not the floor', () {
      expect(PlanPaces.clamp(null), 30);
      expect(PlanPaces.clamp(0), 30);
      expect(PlanPaces.clamp(-5), 30);
    });

    test('an in-between length is not invented into a choice', () {
      // 25 was never on offer. Guessing "the nearest" would put a person on a
      // length they did not pick; the default is the honest fallback.
      expect(PlanPaces.clamp(25), 30);
    });
  });
}
