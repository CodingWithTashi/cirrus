import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/models/journey_state.dart';
import '../../domain/repositories/repositories.dart';
import '../dto/journey_codec.dart';

/// The whole journey is one document per account — the same JSON the codecs
/// already speak. docs/05's per-day subcollections can split it later without
/// touching stores or views.
DocumentReference<Map<String, dynamic>> journeyDoc(
  FirebaseFirestore db,
  String uid,
) => db.collection('journeys').doc(uid);

Future<JourneyState?> fetchJourney(FirebaseFirestore db, String uid) async {
  final data = (await journeyDoc(db, uid).get()).data();
  if (data == null) return null;
  // Platform channels may hand nested maps back as Map<Object?, Object?>;
  // every value is a JSON primitive by codec contract, so a JSON round-trip
  // normalizes safely (same trick as FakeServer._copy).
  return JourneyCodec.decode(
    jsonDecode(jsonEncode(data)) as Map<String, dynamic>,
  );
}

/// Single translation point from Firebase/Google plugin errors to the domain
/// taxonomy the views already speak (`lp_error.dart` surfaces). Unknown codes
/// rethrow — the generic dialog copy covers them.
Future<T> guardAuth<T>(Future<T> Function() op) async {
  try {
    return await op();
  } on FirebaseAuthException catch (e) {
    final mapped = _mapAuthCode(e.code);
    if (mapped != null) throw mapped;
    rethrow;
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled) {
      throw const SignInCancelledException();
    }
    rethrow;
  } on FirebaseException catch (e) {
    // Firestore reads inside auth flows fail like any other wire error.
    if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
      throw const NoConnectionException();
    }
    rethrow;
  }
}

Exception? _mapAuthCode(String code) => switch (code) {
  'wrong-password' ||
  'user-not-found' ||
  'invalid-credential' ||
  'invalid-email' ||
  'INVALID_LOGIN_CREDENTIALS' => const InvalidCredentialsException(),
  'email-already-in-use' ||
  'account-exists-with-different-credential' ||
  'credential-already-in-use' => const EmailAlreadyInUseException(),
  'weak-password' => const WeakPasswordException(),
  'network-request-failed' => const NoConnectionException(),
  'canceled' ||
  'user-cancelled' ||
  'web-context-canceled' ||
  'web-context-cancelled' => const SignInCancelledException(),
  _ => null,
};
