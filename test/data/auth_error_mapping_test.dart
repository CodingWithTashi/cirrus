import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
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

  // Oct 16 2026: thirteen Apple failures in the funnel all read
  // `sign_in_failed{code: other}`. `guardSignIn` is what the sign-in paths
  // use now, and it lets nothing leave without a name.
  group('guardSignIn', () {
    Future<Object?> signIn(Object thrown, {String? stage}) async {
      try {
        await guardSignIn<void>(() => throw thrown, stage: stage);
      } on Object catch (error) {
        return error;
      }
      return null;
    }

    test('the taxonomy guardAuth knows is untouched', () async {
      expect(
        await signIn(FirebaseAuthException(code: 'canceled')),
        isA<SignInCancelledException>(),
      );
      expect(
        await signIn(FirebaseAuthException(code: 'wrong-password')),
        isA<InvalidCredentialsException>(),
      );
      expect(
        await signIn(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
        isA<NoConnectionException>(),
      );
    });

    test('Apple 1000 is "not available here", with its code', () async {
      // Verbatim shape of firebase_auth 6.6.1's iOS conversion
      // (AuthErrors.convertAppleAuthorizationErrorToFlutterError).
      final error = await signIn(
        FirebaseAuthException(
          code: 'unknown',
          message:
              'The operation couldn’t be completed. '
              '(com.apple.AuthenticationServices.AuthorizationError error 1000.) '
              '(Domain=com.apple.AuthenticationServices.AuthorizationError Code=1000)',
        ),
      );
      expect(error, isA<SignInUnavailableException>());
      expect((error! as SignInUnavailableException).detail, 'unknown/1000');
    });

    test('another Apple code is named, not mistaken for 1000', () async {
      final error = await signIn(
        FirebaseAuthException(
          code: 'unknown',
          message:
              '(Domain=com.apple.AuthenticationServices.AuthorizationError Code=1006)',
        ),
      );
      expect(error, isA<AuthProviderException>());
      expect((error! as AuthProviderException).detail, 'unknown/1006');
    });

    test('a number from another domain is not read as Apple’s', () async {
      final error = await signIn(
        FirebaseAuthException(
          code: 'unknown',
          message: '(Domain=NSURLErrorDomain Code=1000)',
        ),
      );
      expect(error, isA<AuthProviderException>());
      expect((error! as AuthProviderException).detail, 'unknown');
    });

    test(
      'every leftover leaves with its code, and the stage prefixes it',
      () async {
        Future<String> detail(Object thrown, {String? stage}) async =>
            ((await signIn(thrown, stage: stage))! as AuthProviderException)
                .detail;

        expect(
          await detail(FirebaseAuthException(code: 'operation-not-allowed')),
          'operation-not-allowed',
        );
        expect(
          await detail(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            ),
            stage: 'journey',
          ),
          'journey/cloud_firestore/permission-denied',
        );
        expect(
          await detail(PlatformException(code: 'sign_in_failed')),
          'platform/sign_in_failed',
        );
      },
    );

    test('a message never reaches the detail', () async {
      final error = await signIn(
        FirebaseAuthException(
          code: 'user-disabled',
          message: 'The account maya@quitmail.com is disabled.',
        ),
      );
      expect((error! as AuthProviderException).detail, 'user-disabled');
    });
  });

  test('signInDetail keeps only a short, safe code', () {
    expect(signInDetail('Unknown Error!'), 'unknown_error_');
    expect(signInDetail('a' * 100).length, 64);
    expect(signInDetail('x', stage: 'journey'), 'journey/x');
  });
}
