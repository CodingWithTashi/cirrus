import '../../domain/logic/exercises/exercise.dart';
import '../../domain/logic/games/game_id.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../api/firebase/functions_client.dart';

/// [PanicRepository] over the `panicSession` callable.
///
/// The callable is deliberately the only server hop in the whole panic flow.
/// Everything the user sees — the breathing pacer, the why card, the loop
/// breakers — is already on-device and stays on-device, so a dead connection
/// costs the AI option and nothing else.
class FirebasePanicRepository implements PanicRepository {
  FirebasePanicRepository({LpFunctions? functions})
    : _functions = functions ?? LpFunctions();

  final LpFunctions _functions;

  @override
  Future<PanicAvailability> begin() async {
    final json = await _functions.call('panicSession');
    return PanicAvailability(
      // Defaults match [PanicAvailability.unknown]: an older or partial
      // response must never read as "AI withheld".
      aiAvailable: json['aiAvailable'] as bool? ?? true,
      sessionsToday: (json['sessionsToday'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> survived({
    int? intensity,
    int? intensityAfter,
    GameId? game,
    ExerciseId? exercise,
    ExerciseSource? source,
  }) async {
    await _functions.call('panicSession', {
      'outcome': 'survived',
      // Absent, never null and never a default: a craving that did not come
      // through the why step has no strength, and the craving document must
      // not carry one the person never gave.
      'intensity': ?intensity,
      'intensityAfter': ?intensityAfter,
      'game': ?game?.name,
      // What was on screen when they said it passed, and where that screen
      // was opened from. Wire values are the enums' names, the same list
      // `functions/src/domain/exercises.ts` holds. A craving that ended on
      // one of the takeover's own steps, with nothing open, names its source
      // (`panic`) and no exercise.
      'exercise': ?exercise?.name,
      'source': ?source?.name,
    });
  }
}

/// The fake-backend stand-in.
///
/// It answers "available" rather than simulating a quota because the demo
/// backend has no entitlement to read: `FakeServer` never issued a tier the
/// server would recognize. Counting locally would produce a number nothing
/// else in the app agrees with, which is worse than not counting.
class NoopPanicRepository implements PanicRepository {
  const NoopPanicRepository();

  @override
  Future<PanicAvailability> begin() async => PanicAvailability.unknown;

  @override
  Future<void> survived({
    int? intensity,
    int? intensityAfter,
    GameId? game,
    ExerciseId? exercise,
    ExerciseSource? source,
  }) async {}
}
