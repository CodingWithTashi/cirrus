import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/models/journey_state.dart';
import '../../domain/repositories/repositories.dart';
import 'firebase_common.dart';

/// [AuthRepository] over Firebase Auth + the journeys collection. Selected on
/// mobile by `backendModeProvider`; needs the console prerequisites from the
/// project setup notes (enabled providers, Android SHA fingerprints, iOS
/// Apple-sign-in entitlement).
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

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
        // TODO(follow-up): link a guest (anonymous) session instead of
        // creating a fresh account, so a Frame-Map journey survives sign-up.
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

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await journeyDoc(_db, user.uid).delete();
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      // Deleting is only allowed shortly after sign-in and the store fires
      // this write-behind, so there is no re-auth surface: degrade to
      // sign-out (journey doc already gone). docs/05's deleteUserData Cloud
      // Function is the real erasure path later.
      if (e.code != 'requires-recent-login') rethrow;
      await _auth.signOut();
    }
  }
}
