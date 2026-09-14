import '../../../domain/repositories/repositories.dart';
import '../auth_api.dart';
import 'fake_server.dart';

/// Placeholder auth backend. Demo rules, formerly scattered in the views:
/// any email + a password of 6+ characters signs into the seeded day-12
/// journey; a short password is "wrong"; the demo email can't be re-registered.
class FakeAuthApi implements AuthApi {
  FakeAuthApi(this._server);

  final FakeServer _server;

  /// The session is the device's and the journey the server's, so a server
  /// that cannot be reached while a session is open is a journey that cannot
  /// be read — never a signed-out person (docs/10 §40). The fake keeps no
  /// on-device copy to fall back to, so this is what a fresh install on a dead
  /// connection meets on the real backend: the splash's retry, not sign-in.
  @override
  Future<Map<String, dynamic>?> restoreSession() {
    if (!_server.reachable && _server.hasSession) {
      return Future<Map<String, dynamic>?>.delayed(
        _server.latency,
        () => throw const JourneyUnavailableException(),
      );
    }
    return _server.respond(_server.journeyJsonForCurrentSession);
  }

  @override
  Future<Map<String, dynamic>?> signInWithEmail({
    required String email,
    required String password,
  }) => _server.respond(() {
    final registered = _server.registeredPassword(email);
    final wrong = registered == null
        ? password.length < 6
        : password != registered;
    if (wrong) throw const InvalidCredentialsException();
    _server.signIn(email);
    return _server.journeyJsonForCurrentSession()!;
  });

  @override
  Future<Map<String, dynamic>?> signInWithApple() => _server.respond(() {
    _server.signInApple();
    return _server.journeyJsonForCurrentSession();
  });

  @override
  Future<Map<String, dynamic>?> signInWithGoogle() => _server.respond(() {
    _server.signInGoogle();
    return _server.journeyJsonForCurrentSession();
  });

  @override
  Future<void> register({required String email, required String password}) =>
      _server.respond(() {
        if (_server.isRegistered(email)) {
          throw const EmailAlreadyInUseException();
        }
        _server.register(email, password);
      });

  @override
  Future<void> requestPasswordReset(String email) => _server.respond(() {});

  @override
  Future<void> signOut() => _server.respond(_server.signOut);

  @override
  Future<void> deleteAccount() => _server.respond(_server.deleteAccount);

  @override
  Future<String> ensureSession() => _server.respond(_server.ensureSessionId);
}
