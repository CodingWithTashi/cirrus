import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/repositories/firebase_common.dart';
import 'package:last_puff/domain/repositories/repositories.dart';

/// `guardAuth` is the ONE place Firebase/Google error codes become the domain
/// taxonomy the views speak. A code it does not know falls through to the
/// generic "that one's on us" dialog — which blames the app and invites a
/// doomed retry for a failure that was the user's input all along.
///
/// QA M4 (Aug 31 2026): registering with the password `123` did exactly
/// that. Firebase answered `weak-password` ("at least 6 characters"), the
/// taxonomy had no case for it, and the user got the glitch dialog.
void main() {
  Future<Object?> mapped(String code) async {
    try {
      await guardAuth<void>(
        () => throw FirebaseAuthException(code: code, message: 'x'),
      );
    } on Object catch (error) {
      return error;
    }
    return null;
  }

  test('weak-password is the user’s input, not our glitch', () async {
    expect(await mapped('weak-password'), isA<WeakPasswordException>());
  });

  test('the existing cases still map', () async {
    expect(
      await mapped('email-already-in-use'),
      isA<EmailAlreadyInUseException>(),
    );
    expect(await mapped('wrong-password'), isA<InvalidCredentialsException>());
    expect(
      await mapped('network-request-failed'),
      isA<NoConnectionException>(),
    );
    expect(await mapped('user-cancelled'), isA<SignInCancelledException>());
    // The literal code the iOS plugin emits when the Apple sheet is dismissed.
    expect(await mapped('canceled'), isA<SignInCancelledException>());
  });

  test('an unknown code still rethrows for the generic surface', () async {
    expect(await mapped('operation-not-allowed'), isA<FirebaseAuthException>());
  });
}
