import '../../domain/repositories/repositories.dart' show AuthException;

/// Wire-level auth endpoints. JSON in/out; throws [AuthException] subtypes.
/// Implemented by the fake backend today; a REST client or Firebase Auth
/// adapter implements the same surface later.
abstract interface class AuthApi {
  /// The signed-in account's journey JSON, or null (no session, or an account
  /// that has not onboarded yet).
  Future<Map<String, dynamic>?> restoreSession();

  /// Journey JSON on success; null for an account without a journey yet
  /// (→ onboarding). Throws [InvalidCredentialsException].
  Future<Map<String, dynamic>?> signInWithEmail({
    required String email,
    required String password,
  });

  /// Journey JSON when the Apple account already has one; null → onboarding.
  Future<Map<String, dynamic>?> signInWithApple();

  /// Journey JSON when the Google account already has one; null → onboarding.
  Future<Map<String, dynamic>?> signInWithGoogle();

  /// Creates the account and opens a session (no journey yet);
  /// throws [EmailAlreadyInUseException].
  Future<void> register({required String email, required String password});

  Future<void> requestPasswordReset(String email);

  Future<void> signOut();

  /// Deletes the account and its journey server-side.
  Future<void> deleteAccount();

  /// The account id a purchase is filed under, opening a guest session when
  /// there is none yet.
  Future<String> ensureSession();
}
