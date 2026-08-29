import '../../domain/repositories/repositories.dart';
import '../api/firebase/functions_client.dart';

/// Calls `syncUserContext`, the app's only write path into the server-owned
/// `users/{uid}` document.
///
/// Until this ran at least once, `users/{uid}` did not exist for anybody —
/// which meant both nightly crons paged over an empty collection and silently
/// did nothing, forever (B9). It is the least visible call in the app and one
/// of the most load-bearing.
class FirebaseUserContextRepository implements UserContextRepository {
  FirebaseUserContextRepository({LpFunctions? functions})
    : _functions = functions ?? LpFunctions();

  final LpFunctions _functions;

  @override
  Future<void> sync({String? fcmToken}) =>
      _functions.call('syncUserContext', {'fcmToken': ?fcmToken});
}

/// The fake-backend stand-in. There is no server to tell anything, so this
/// does nothing rather than pretending to succeed against a fixture.
class NoopUserContextRepository implements UserContextRepository {
  const NoopUserContextRepository();

  @override
  Future<void> sync({String? fcmToken}) async {}
}
