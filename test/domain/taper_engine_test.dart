import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/taper_engine.dart';
import 'package:last_puff/domain/models/models.dart';

QuitPlan plan({
  int baseline = 200,
  int pace = 30,
  QuitMethod method = QuitMethod.taper,
  int stretch = 0,
}) => QuitPlan(
  method: method,
  paceDays: pace,
  startDate: DateTime(2026, 8, 4),
  baselinePuffsPerDay: baseline,
  weeklySpend: 45,
  strength: NicStrength.mg50,
  stretchDays: stretch,
);

void main() {
  group('TaperEngine base curve', () {
    // The docs/03 §3.1 worked example is the QA gate: B=200, P=30.
    test('matches the spec worked example exactly', () {
      final p = plan();
      expect(TaperEngine.limitFor(p, 1), 190);
      expect(TaperEngine.limitFor(p, 7), 134);
      expect(TaperEngine.limitFor(p, 15), 71);
      expect(TaperEngine.limitFor(p, 21), 33);
      expect(TaperEngine.limitFor(p, 27), 6);
      expect(TaperEngine.limitFor(p, 28), 3);
      expect(TaperEngine.limitFor(p, 29), 1);
      expect(TaperEngine.limitFor(p, 30), 0);
    });

    test('is never increasing day over day', () {
      final curve = TaperEngine.curve(plan(baseline: 320, pace: 60));
      for (var i = 1; i < curve.length; i++) {
        expect(
          curve[i] <= curve[i - 1],
          isTrue,
          reason: 'day ${i + 1} (${curve[i]}) > day $i (${curve[i - 1]})',
        );
      }
    });

    test('small baselines still land on zero', () {
      final curve = TaperEngine.curve(plan(baseline: 20, pace: 14));
      expect(curve.last, 0);
      expect(curve.first, lessThanOrEqualTo(20));
    });

    test('cold turkey is zero from day one', () {
      expect(TaperEngine.limitFor(plan(method: QuitMethod.coldTurkey), 1), 0);
    });
  });

  group('TaperEngine slip recovery', () {
    test('stretches freedom day by two days', () {
      final reflown = TaperEngine.reflowAfterSlip(plan());
      expect(reflown.totalDays, 32);
      expect(reflown.freedomDate, DateTime(2026, 9, 4));
    });

    test('stretch is capped at +50% of the pace', () {
      var p = plan(pace: 14);
      for (var i = 0; i < 20; i++) {
        p = TaperEngine.reflowAfterSlip(p);
      }
      expect(p.stretchDays, 7);
    });
  });

  test('halfwayDay finds the 50% crossing', () {
    final p = plan();
    final day = TaperEngine.halfwayDay(p);
    expect(TaperEngine.limitFor(p, day), lessThanOrEqualTo(100));
    expect(TaperEngine.limitFor(p, day - 1), greaterThan(100));
  });
}
