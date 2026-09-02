/// The one rule every game's personal best follows.
abstract final class GameScore {
  /// Zero never sets a best (the honest empty state holds) and a tie does
  /// not either; null [best] means never played.
  static bool beats(int score, int? best) =>
      score > 0 && (best == null || score > best);
}
