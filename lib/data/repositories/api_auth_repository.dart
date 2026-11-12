import '../../domain/models/enums.dart';
import '../../domain/models/journey_state.dart';
import '../../domain/repositories/repositories.dart';
import '../api/auth_api.dart';
import '../dto/journey_codec.dart';

/// [AuthRepository] over the wire-level [AuthApi]: pure JSON ↔ domain mapping.
class ApiAuthRepository implements AuthRepository, SignInMethodSource {
  ApiAuthRepository(this._api);

  final AuthApi _api;

  /// The door this process's session came in by. The wire API has no notion
  /// of a provider, so this is remembered here and is null for a session the
  /// backend restored — which the sign-out dialog reads as "nothing to name".
  AccountProvider? _provider;

  @override
  Future<AccountProvider?> signInProvider() async => _provider;

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
    _provider = AccountProvider.email;
    return json == null ? null : JourneyCodec.decode(json);
  }

  @override
  Future<JourneyState?> signInWithApple() async {
    final json = await _api.signInWithApple();
    _provider = AccountProvider.apple;
    return json == null ? null : JourneyCodec.decode(json);
  }

  @override
  Future<JourneyState?> signInWithGoogle() async {
    final json = await _api.signInWithGoogle();
    _provider = AccountProvider.google;
    return json == null ? null : JourneyCodec.decode(json);
  }

  @override
  Future<void> register({
    required String email,
    required String password,
  }) async {
    await _api.register(email: email, password: password);
    _provider = AccountProvider.email;
  }

  @override
  Future<void> requestPasswordReset(String email) =>
      _api.requestPasswordReset(email);

  @override
  Future<void> signOut() {
    _provider = null;
    return _api.signOut();
  }

  @override
  Future<void> deleteAccount() {
    _provider = null;
    return _api.deleteAccount();
  }

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
