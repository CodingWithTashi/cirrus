import '../games/game_id.dart';

/// Everything a person can do during a craving, by id. `.name` is a wire
/// value (callable payloads, craving docs, analytics, routes). Never rename
/// one.
///
/// Mirrored row for row by `EXERCISES` in `functions/src/domain/exercises.ts`
/// and pinned to it by `test/domain/exercises_test.dart`, which reads the
/// TypeScript file. A new exercise is one value here, one row in
/// [Exercises.all] and the same row on the server.
enum ExerciseId { breathing, orbs, tiles, blocks, sos }

/// What an exercise is FOR. A locked exercise resolves to a free one of the
/// same kind, and the coach's menu offers one of each.
enum ExerciseKind { calm, focus, people }

/// Where an exercise was opened from. `.name` is a wire value, like
/// [ExerciseId].
enum ExerciseSource { panic, coach, plan, home }

/// One row of the registry.
class ExerciseSpec {
  const ExerciseSpec(this.id, this.kind, {this.premium = false, this.game});

  final ExerciseId id;
  final ExerciseKind kind;

  /// Premium exercises are never shown as a lock: [Exercises.resolveFor]
  /// swaps in a free one of the same kind.
  final bool premium;

  /// The arena game this exercise plays, or null when it is not one.
  final GameId? game;
}

/// The registry: the ONE list of exercises. The catalog, the capability list
/// the coach sends, the server's card policy and the analytics values all
/// derive from it.
abstract final class Exercises {
  /// Row order is the order cards are offered in. [all.first] is free, and
  /// must stay free: it is where [resolveFor] lands when nothing else is.
  static const List<ExerciseSpec> all = [
    ExerciseSpec(ExerciseId.breathing, ExerciseKind.calm),
    ExerciseSpec(ExerciseId.orbs, ExerciseKind.focus, game: GameId.orbs),
    ExerciseSpec(
      ExerciseId.tiles,
      ExerciseKind.focus,
      premium: true,
      game: GameId.tiles,
    ),
    ExerciseSpec(
      ExerciseId.blocks,
      ExerciseKind.focus,
      premium: true,
      game: GameId.blocks,
    ),
    ExerciseSpec(ExerciseId.sos, ExerciseKind.people),
  ];

  static ExerciseSpec of(ExerciseId id) => all.firstWhere((s) => s.id == id);

  /// The exercise a wire value names, or null for anything this build does
  /// not know: a newer server's id, a non-string, nothing at all.
  static ExerciseId? parse(Object? name) {
    for (final id in ExerciseId.values) {
      if (id.name == name) return id;
    }
    return null;
  }

  static ExerciseSource? parseSource(Object? name) {
    for (final source in ExerciseSource.values) {
      if (source.name == name) return source;
    }
    return null;
  }

  /// The exercise that plays [game], or null when the registry has no row
  /// for it.
  static ExerciseId? forGame(GameId game) {
    for (final spec in all) {
      if (spec.game == game) return spec.id;
    }
    return null;
  }

  /// What [id] opens for this account: itself when it is free or the account
  /// is Premium, otherwise the first free exercise of the same kind,
  /// otherwise [all.first]. Nobody lands on a lock mid-craving.
  static ExerciseId resolveFor(ExerciseId id, {required bool premium}) {
    final spec = of(id);
    if (premium || !spec.premium) return id;
    for (final other in all) {
      if (other.kind == spec.kind && !other.premium) return other.id;
    }
    return all.first.id;
  }
}

/// One finished visit to an exercise, however it ended.
class ExerciseRun {
  const ExerciseRun({
    required this.id,
    required this.source,
    required this.seconds,
    required this.completed,
    required this.passed,
    this.score,
  });

  final ExerciseId id;
  final ExerciseSource source;
  final int seconds;

  /// Ran long enough to count as done.
  final bool completed;

  /// Ended on "It passed".
  final bool passed;

  final int? score;
}

/// The app's model of how long a craving lasts (docs/03 §7: most pass in
/// 15–20 minutes). One constant, because the coach's no-selling window, a
/// parked craving a card may join and a run the chat may report all mean the
/// same twenty minutes.
abstract final class CravingWindow {
  static const Duration duration = Duration(minutes: 20);

  /// Whether [now] is still inside the craving that began at [since].
  static bool covers(DateTime? since, DateTime now) =>
      since != null && now.difference(since) < duration;
}
