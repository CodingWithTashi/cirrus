/// Backend contracts (DIP seam). Stores — the view-model layer — depend on
/// these interfaces only; today they're implemented over a fake JSON API
/// (`data/api/fake`), later over Firebase or a REST client without touching a
/// single store or view (docs/05 architecture).
library;

import '../models/journey_state.dart';
import '../models/models.dart';

/// Session lifecycle. Every method is a real (fake-backed) API round-trip.
abstract interface class AuthRepository {
  /// The signed-in account's journey, or null (no session / not onboarded).
  Future<JourneyState?> restoreSession();

  /// Throws [InvalidCredentialsException] on a wrong password.
  Future<JourneyState> signInWithEmail({
    required String email,
    required String password,
  });

  /// The account's journey when it already has one; null → onboarding.
  Future<JourneyState?> signInWithApple();

  /// Creates the account and opens a session (journey comes later, from
  /// onboarding). Throws [EmailAlreadyInUseException].
  Future<void> register({required String email, required String password});

  Future<void> requestPasswordReset(String email);

  Future<void> signOut();

  Future<void> deleteAccount();
}

/// Persistence of the quit journey itself.
abstract interface class JourneyRepository {
  /// The backend creates the initial journey from onboarding output.
  Future<JourneyState> create({
    required UserProfile profile,
    required QuitPlan plan,
  });

  /// Write-behind upsert after every local mutation.
  Future<void> save(JourneyState journey);

  Future<void> delete();
}

/// Anonymous community feed.
abstract interface class CommunityRepository {
  Future<List<Post>> fetchPosts();

  Future<void> addPost(Post post);

  Future<void> setReaction(String postId, String emoji, {required bool on});

  Future<void> addReply(String postId, Reply reply);

  Future<void> reportPost(String postId);

  Future<void> blockAuthor(String alias);

  Future<void> nudgeBuddy();
}

/// Ember — the backend decides *what* to say ([CoachReply]); views localize.
abstract interface class CoachRepository {
  Future<CoachReply> requestReply({
    String? text,
    CoachChip? chip,
    required bool capped,
  });
}

sealed class AuthException implements Exception {
  const AuthException();
}

final class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException();
}

final class EmailAlreadyInUseException extends AuthException {
  const EmailAlreadyInUseException();
}

/// The device can't reach the backend (airplane mode, dead wifi, tunnel…).
/// Thrown by every repository operation that needs the wire; views map it to
/// the friendly offline surfaces, never to a generic failure.
final class NoConnectionException implements Exception {
  const NoConnectionException();
}
