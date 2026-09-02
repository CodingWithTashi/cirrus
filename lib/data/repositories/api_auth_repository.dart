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
  Future<JourneyState?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final json = await _api.signInWithEmail(email: email, password: password);
    return json == null ? null : JourneyCodec.decode(json);
  }

  @override
  Future<JourneyState?> signInWithApple() async {
    final json = await _api.signInWithApple();
    return json == null ? null : JourneyCodec.decode(json);
  }

  @override
  Future<JourneyState?> signInWithGoogle() async {
    final json = await _api.signInWithGoogle();
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

  /// Always null, deliberately. The fake backend's only account identifier is
  /// the email address the demo signs in with, and an email must never become
  /// an analytics user id. Nothing is lost: `analyticsProvider` resolves to
  /// `NoopAnalytics` on this backend anyway.
  @override
  Future<String?> currentUserId() async => null;

  /// The fake's account id, which never leaves the process: it keys the
  /// entitlement row on `FakeServer` and nothing else.
  @override
  Future<String?> ensureSessionId() => _api.ensureSession();
}
