import '../../domain/models/journey_state.dart';
import '../../domain/repositories/repositories.dart';
import '../api/auth_api.dart';
import '../dto/journey_codec.dart';

/// [AuthRepository] over the wire-level [AuthApi]: pure JSON ↔ domain mapping.
class ApiAuthRepository implements AuthRepository {
  const ApiAuthRepository(this._api);

  final AuthApi _api;

  @override
  Future<JourneyState?> restoreSession() async {
    final json = await _api.restoreSession();
    return json == null ? null : JourneyCodec.decode(json);
  }

  @override
  Future<JourneyState> signInWithEmail({
    required String email,
    required String password,
  }) async => JourneyCodec.decode(
    await _api.signInWithEmail(email: email, password: password),
  );

  @override
  Future<JourneyState?> signInWithApple() async {
    final json = await _api.signInWithApple();
    return json == null ? null : JourneyCodec.decode(json);
  }

  @override
  Future<void> register({required String email, required String password}) =>
      _api.register(email: email, password: password);

  @override
  Future<void> requestPasswordReset(String email) =>
      _api.requestPasswordReset(email);

  @override
  Future<void> signOut() => _api.signOut();

  @override
  Future<void> deleteAccount() => _api.deleteAccount();
}
