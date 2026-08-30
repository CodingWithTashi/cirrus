import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/repositories/repositories.dart';
import '../api/firebase/functions_client.dart';

class FirebaseCoachNameRepository implements CoachNameRepository {
  FirebaseCoachNameRepository({LpFunctions? functions})
    : _functions = functions ?? LpFunctions();

  final LpFunctions _functions;

  @override
  Future<bool> reserve(String name) async {
    try {
      await _functions.call('setCoachName', {'coachName': name});
      return true;
    } on FirebaseFunctionsException catch (e) {
      // `invalid-argument` is the guard saying no. Everything else — offline,
      // App Check, a cold start that timed out — is not a verdict on the name,
      // so it rethrows and the caller keeps the name locally.
      if (e.code == 'invalid-argument') return false;
      rethrow;
    }
  }
}

/// The fake backend has no guard to consult, so every name is accepted — which
/// is also the offline behaviour, so both paths are exercised daily.
class NoopCoachNameRepository implements CoachNameRepository {
  const NoopCoachNameRepository();

  @override
  Future<bool> reserve(String name) async => true;
}
