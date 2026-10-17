import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

/// [source] is Firestore's own choice by default: the server when it can
/// reach one, the device's copy once it has decided it cannot. Launch asks for
/// [Source.cache] outright when the server is slow — Firestore's own decision
/// can take longer than the launch budget — and the post-launch refresh asks
/// for [Source.server] to get past that copy (docs/10 §40).
Future<JourneyState?> fetchJourney(
  FirebaseFirestore db,
  String uid, {
  Source source = Source.serverAndCache,
}) async {
  final data = (await journeyDoc(
    db,
    uid,
  ).get(GetOptions(source: source))).data();
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

/// [guardAuth] for the sign-in paths, plus one rule: nothing leaves unnamed.
///
/// What [guardAuth] rethrows untouched used to reach `JourneyStore` raw and be
/// reported as `sign_in_failed{code: other}` — thirteen Apple failures in the
/// Oct 2026 funnel said that and nothing else. Every leftover now leaves as an
/// [AuthProviderException] carrying the provider's own code, and Apple's
/// "the sheet ended with no answer" (`ASAuthorizationError.unknown`, 1000) as
/// a [SignInUnavailableException] whose copy points at email.
///
/// [stage] prefixes the detail. The journey read after a sign-in passes
/// `journey`, so a Firestore refusal after a GOOD Apple sign-in can no longer
/// pass for an Apple failure.
Future<T> guardSignIn<T>(Future<T> Function() op, {String? stage}) async {
  try {
    return await guardAuth(op);
  } on FirebaseAuthException catch (e) {
    final native = _nativeAppleCode(e.message);
    final detail = signInDetail(
      native == null ? e.code : '${e.code}/$native',
      stage: stage,
    );
    if (e.code == 'unknown' && native == '1000') {
      throw SignInUnavailableException(detail);
    }
    throw AuthProviderException(detail);
  } on GoogleSignInException catch (e) {
    throw AuthProviderException(
      signInDetail('google/${e.code.name}', stage: stage),
    );
  } on FirebaseException catch (e) {
    throw AuthProviderException(
      signInDetail('${e.plugin}/${e.code}', stage: stage),
    );
  } on PlatformException catch (e) {
    throw AuthProviderException(
      signInDetail('platform/${e.code}', stage: stage),
    );
  }
}

/// The native code firebase_auth's iOS plugin folds into the message of an
/// Apple sheet failure it has no name for —
/// `"… (Domain=com.apple.AuthenticationServices.AuthorizationError Code=1000)"`
/// — and only that one domain, so no other number is mistaken for it.
String? _nativeAppleCode(String? message) {
  if (message == null) return null;
  final match = RegExp(
    r'Domain=com\.apple\.AuthenticationServices\.AuthorizationError Code=(-?\d+)',
  ).firstMatch(message);
  return match?.group(1);
}

/// The analytics-safe form of a provider code: lower case, `[a-z0-9_/-]`
/// only, at most 64 characters. A code, never a message — messages can carry
/// an email address.
@visibleForTesting
String signInDetail(String raw, {String? stage}) {
  final joined = stage == null ? raw : '$stage/$raw';
  final safe = joined.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_/-]'), '_');
  return safe.length <= 64 ? safe : safe.substring(0, 64);
}
