import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/models/journey_state.dart';
import '../../domain/repositories/repositories.dart';
import '../api/firebase/functions_client.dart';
import 'firebase_common.dart';

/// [AuthRepository] over Firebase Auth + the journeys collection. Selected on
/// mobile by `backendModeProvider`; needs the console prerequisites from the
/// project setup notes (enabled providers, Android SHA fingerprints, iOS
/// Apple-sign-in entitlement).
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    LpFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _db = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? LpFunctions();

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final LpFunctions _functions;

  /// The Firebase project's *web* OAuth client (client_type 3 in
  /// android/app/google-services.json) — google_sign_in v7 requires it as
  /// serverClientId to mint an idToken Firebase accepts.
  static const _googleServerClientId =
      '826701239342-1agl82qs8af24aohuoiep9m7gi64pc6n.apps.googleusercontent.com';

  /// google_sign_in v7 must be initialized exactly once per process.
  Future<void>? _googleInit;

  @override
  Future<JourneyState?> restoreSession() async {
    // First emission, never `currentUser` — a cold start may not have loaded
    // the persisted session yet. The timeouts keep the splash's Future.wait
    // from hanging on a dead wire; the store treats the throw as signed out.
    final user = await _auth.authStateChanges().first.timeout(
      const Duration(seconds: 5),
    );
    if (user == null) return null;
    return guardAuth(
      () => fetchJourney(_db, user.uid),
    ).timeout(const Duration(seconds: 5));
  }

  @override
  Future<JourneyState?> signInWithEmail({
    required String email,
    required String password,
  }) => guardAuth(() async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return fetchJourney(_db, cred.user!.uid);
  });

  @override
  Future<JourneyState?> signInWithApple() => guardAuth(() async {
    final cred = await _auth.signInWithProvider(AppleAuthProvider());
    return fetchJourney(_db, cred.user!.uid);
  });

  @override
  Future<JourneyState?> signInWithGoogle() => guardAuth(() async {
    final google = GoogleSignIn.instance;
    await (_googleInit ??= google.initialize(
      serverClientId: _googleServerClientId,
    ));
    final account = await google.authenticate();
    final cred = await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: account.authentication.idToken),
    );
    return fetchJourney(_db, cred.user!.uid);
  });

  @override
  Future<void> register({required String email, required String password}) =>
      guardAuth(() async {
        // Upgrade the guest rather than replacing them.
        //
        // Guest onboarding runs on an anonymous account (`create()` mints one
        // when there is no session), so registering with a fresh account left
        // the anonymous uid — and the entire nineteen-step journey written
        // under it — orphaned in Firestore, and dropped the user back on an
        // empty app. `linkWithCredential` keeps the uid, so the journey, the
        // coach transcript and everything under `users/{uid}` come with them.
        final current = _auth.currentUser;
        if (current != null && current.isAnonymous) {
          try {
            await current.linkWithCredential(
              EmailAuthProvider.credential(email: email, password: password),
            );
            return;
          } on FirebaseAuthException catch (error) {
            // `credential-already-in-use` / `email-already-in-use` mean this
            // address belongs to a real account already. That is not a link,
            // it is a sign-in, and falling through would report "already in
            // use" — which is the truth and what the view expects.
            if (error.code != 'provider-already-linked') rethrow;
          }
        }
        await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      });

  @override
  Future<void> requestPasswordReset(String email) =>
      guardAuth(() => _auth.sendPasswordResetEmail(email: email));

  @override
  Future<void> signOut() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await GoogleSignIn.instance.signOut();
      } on Exception {
        // Best-effort: a failed Google sign-out never blocks the Firebase one.
      }
    }
    await _auth.signOut();
  }

  /// Full erasure, server-side (`deleteUserData`).
  ///
  /// The client CANNOT do this itself, and the previous local-only version
  /// silently proved it: deleting `journeys/{uid}` and the auth record left
  /// `users/{uid}` (entitlement, coach transcript, cravings, insights) and
  /// every community post standing, with the uid↔post map still naming the
  /// author. That is a broken erasure promise and an App Store 5.1.1(v)
  /// failure, not a rough edge.
  ///
  /// The callable also sidesteps `requires-recent-login`: the Admin SDK
  /// deletes the auth record regardless of how old the session is, so there
  /// is no re-auth surface to build and no half-deleted state to explain.
  @override
  Future<void> deleteAccount() async {
    if (_auth.currentUser == null) return;
    // No `guardAuth` here: LpFunctions is the mapper for callable failures,
    // the way guardAuth is the mapper for the auth plugin's. Wrapping this in
    // both would give one error two translators.
    await _functions.call('deleteUserData');
    // The account is gone server-side; this only drops the local session so
    // the SDK stops trying to refresh a token for a user that no longer
    // exists. It is deliberately after the callable — a failed erasure must
    // leave the user signed in and able to retry.
    await _auth.signOut();
  }
}
