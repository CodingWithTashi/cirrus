import '../models/models.dart';

/// Honest equivalences (docs/03 §2). Every number here is a research
/// heuristic and is always displayed with "≈".
abstract final class DependenceEngine {
  /// ~14 puffs ≈ 1 cigarette (research heuristic, docs/02 §8).
  static int cigaretteEquivalent(int puffs) => (puffs / 14).round();

  /// Estimated nicotine for a day, in mg.
  static double nicotineMg(int puffs, NicStrength strength) =>
      puffs * strength.mgPerPuff;

  /// A typical disposable is ~600 puffs (onboarding estimator).
  static int puffsPerDayFromDevices(double devicesPerWeek) =>
      (devicesPerWeek * 600 / 7).round();
}
