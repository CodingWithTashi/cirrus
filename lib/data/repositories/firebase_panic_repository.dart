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
  Future<void> survived({required int intensity}) async {
    await _functions.call('panicSession', {
      'outcome': 'survived',
      'intensity': intensity,
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
  Future<void> survived({required int intensity}) async {}
}
