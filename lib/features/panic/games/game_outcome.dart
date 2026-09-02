import '../../../domain/logic/games/game_id.dart';

/// What a finished round hands the survived screen, carried in the route's
/// query string so it survives `survive()` invalidating the panic session.
class GameOutcome {
  const GameOutcome({
    required this.game,
    required this.score,
    required this.newBest,
    this.rounds = 1,
    this.intensityBefore,
    this.intensityAfter,
  });

  final GameId game;

  /// The latest round's count — tiles, lines, orbs.
  final int score;

  /// Whether that round set the best; decided before the journey is mutated
  /// (leave first, then mutate).
  final bool newBest;

  /// Rounds played to the end this session.
  final int rounds;

  /// Their 1–10 on the why step and on the round panel; either may be missing.
  final int? intensityBefore;
  final int? intensityAfter;

  static const _gameKey = 'g';
  static const _scoreKey = 'score';
  static const _bestKey = 'best';
  static const _roundsKey = 'rounds';
  static const _beforeKey = 'ib';
  static const _afterKey = 'ia';

  GameOutcome copyWith({int? intensityBefore, int? intensityAfter}) =>
      GameOutcome(
        game: game,
        score: score,
        newBest: newBest,
        rounds: rounds,
        intensityBefore: intensityBefore ?? this.intensityBefore,
        intensityAfter: intensityAfter ?? this.intensityAfter,
      );

  /// Null when reached without playing, or with a game this build lacks.
  static GameOutcome? fromQuery(Map<String, String> query) {
    final game = GameId.values
        .where((g) => g.name == query[_gameKey])
        .firstOrNull;
    final score = int.tryParse(query[_scoreKey] ?? '');
    if (game == null || score == null || score < 0) return null;
    return GameOutcome(
      game: game,
      score: score,
      newBest: query[_bestKey] == '1',
      rounds: (int.tryParse(query[_roundsKey] ?? '') ?? 1).clamp(1, 99),
      intensityBefore: _intensity(query[_beforeKey]),
      intensityAfter: _intensity(query[_afterKey]),
    );
  }

  static int? _intensity(String? raw) {
    final value = int.tryParse(raw ?? '');
    return value == null || value < 1 || value > 10 ? null : value;
  }

  String toQuery() => [
    '$_gameKey=${game.name}',
    '$_scoreKey=$score',
    '$_bestKey=${newBest ? 1 : 0}',
    '$_roundsKey=$rounds',
    if (intensityBefore case final before?) '$_beforeKey=$before',
    if (intensityAfter case final after?) '$_afterKey=$after',
  ].join('&');
}
