import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../../domain/repositories/repositories.dart';

/// The single door from the app to Cloud Functions.
///
/// Everything callable goes through here so three things can never be
/// forgotten at a call site:
///
/// 1. **Timezone and locale ride on every request.** A callable carries no
///    ambient timezone, and the server's `requireCaller` reads both off the
///    payload. Miss them and every quota rolls over at UTC midnight instead of
///    the user's, and Ember answers in the wrong language.
/// 2. **Wire failures map to the domain taxonomy** the error surfaces already
///    speak, rather than leaking `FirebaseFunctionsException` into views.
/// 3. **Payloads normalize to plain JSON.** Platform channels hand nested maps
///    back as `Map<Object?, Object?>`; the codecs expect `Map<String, dynamic>`
///    (the same round-trip trick `firebase_common.dart` uses).
class LpFunctions {
  LpFunctions({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  /// Resolved once per process. The IANA lookup is a platform channel hop and
  /// the zone does not change mid-session in any way that matters — a device
  /// that crosses a timezone gets the new one on next launch, which is also
  /// when `syncUserContext` re-derives the cron hour.
  static String? _cachedZone;

  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, Object?> data = const {},
  ]) async {
    try {
      final result = await _functions.httpsCallable(name).call<Object?>({
        ...data,
        'timeZone': await _timeZone(),
        'locale': _locale(),
      });
      final payload = result.data;
      if (payload == null) return const {};
      return jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
    } on FirebaseFunctionsException catch (error) {
      throw mapCallableError(error, signedIn: _signedIn());
    }
  }

  /// Calls a callable that streams, yielding each chunk as it lands and the
  /// final envelope last.
  ///
  /// Same three guarantees as [call] — timezone/locale injected, wire failures
  /// mapped onto the domain taxonomy, payloads normalized to plain JSON. The
  /// server only streams when the client asks, so this is what turns
  /// `aiCoachChat`'s streaming branch from dead code into the primary path.
  Stream<({String? chunk, Map<String, dynamic>? result})> stream(
    String name, [
    Map<String, Object?> data = const {},
  ]) async* {
    final payload = {
      ...data,
      'timeZone': await _timeZone(),
      'locale': _locale(),
    };
    try {
      final responses = _functions.httpsCallable(name).stream<Object?, Object?>(
        payload,
      );
      await for (final response in responses) {
        switch (response) {
          case Chunk(:final partialData):
            if (partialData is String && partialData.isNotEmpty) {
              yield (chunk: partialData, result: null);
            }
          case Result(:final result):
            final data = result.data;
            yield (
              chunk: null,
              result: data == null
                  ? const <String, dynamic>{}
                  : jsonDecode(jsonEncode(data)) as Map<String, dynamic>,
            );
        }
      }
    } on FirebaseFunctionsException catch (error) {
      throw mapCallableError(error, signedIn: _signedIn());
    }
  }

  /// Whether Firebase believes someone is signed in *right now*.
  ///
  /// Read at failure time rather than injected, so a token that expired
  /// mid-flight still classifies correctly. Guarded because a caller may reach
  /// here before `Firebase.initializeApp`, and a diagnostic must never become
  /// the thing that throws.
  bool _signedIn() {
    try {
      return FirebaseAuth.instance.currentUser != null;
    } on Object {
      return false;
    }
  }

  /// IANA identifier ('America/Toronto'), never an abbreviation. Dart's own
  /// `DateTime.timeZoneName` yields 'EST', which the server rejects and
  /// silently replaces with UTC — the day boundary would then be wrong for
  /// every user outside it.
  static Future<String> _timeZone() async {
    final cached = _cachedZone;
    if (cached != null) return cached;
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      return _cachedZone = info.identifier;
    } on Object {
      // A missing platform channel is not worth failing a panic request over.
      return _cachedZone = 'UTC';
    }
  }

  static String _locale() =>
      PlatformDispatcher.instance.locale.toLanguageTag();
}

/// Maps callable failures onto the taxonomy in `domain/repositories`.
///
/// Only genuinely-offline codes become [NoConnectionException] — that is the
/// one the UI turns into "no wifi, no worries", and labelling a server bug as
/// an outage would send users to check their router.
///
/// [signedIn] disambiguates the one code that carries two meanings. A gen-2
/// callable answers a failed **App Check** with the very same `unauthenticated`
/// it uses for a missing **user**, so the code alone cannot tell "we don't know
/// who you are" from "we don't trust this build". A caller who is demonstrably
/// signed in and still hears `unauthenticated` was refused as an app, not as a
/// person — that is App Check, and it becomes [BackendRejectedException].
///
/// **`permission-denied` is deliberately NOT mapped.** It reads like an App
/// Check refusal and used to be folded into [BackendRejectedException], but
/// exactly one callable raises it — `createPost`, for a free account whose
/// ordinary post a subscription WOULD have let through — and that meaning is
/// the opposite of a rejected build: it is the app's single most valuable
/// upgrade door. Folding it destroyed the distinction the server goes out of
/// its way to draw (`permission-denied` = "upgrading helps" vs
/// `resource-exhausted` = "come back tomorrow"), so
/// `FirebaseCommunityRepository` — which catches the raw code and turns it
/// into a [ContentRefusal] — never saw it, and a free user who had spent the
/// day's post got "couldn't post, tap to retry" on a retry that could never
/// succeed. It was unreachable while `ENTITLEMENT_MODE=ungated` made every
/// caller premium, and went live with the flip to `mirror` (docs/10 §19).
Object mapCallableError(
  FirebaseFunctionsException error, {
  required bool signedIn,
}) => switch (callableErrorCode(error)) {
  'unavailable' || 'deadline-exceeded' => const NoConnectionException(),
  'unauthenticated' =>
    signedIn
        ? const BackendRejectedException()
        : const InvalidCredentialsException(),
  // The one exception to the paragraph above, and it does not weaken it: a
  // permission refusal read out of an `unknown`'s WORDS can only have come
  // from the streaming path, and `aiCoachChat` is the only callable that
  // streams. `createPost` — the sole raiser of a real `permission-denied`,
  // and the upgrade door that paragraph protects — goes over the plain
  // `call`, which never loses its code, so it can never arrive this way.
  // Guarding on the raw code keeps the two apart: the door stays a door.
  'permission-denied' when error.code == 'unknown' =>
    const BackendRejectedException(),
  _ => error,
};

/// The error's code — recovered from its message when the code says nothing.
///
/// The plugin's **streaming** path on Apple platforms flattens every failure
/// to `unknown` and keeps only the SDK's `localizedDescription`
/// (`FunctionsStreamHandler.swift`), which for a `FunctionsError` is the
/// server's status message ("Unauthenticated") or the code's own name
/// ("UNAUTHENTICATED"). So an App Check refusal of `aiCoachChat` on an
/// iPhone arrived here as `unknown`, fell through the switch above, and the
/// coach told a user who was demonstrably online that the signal had dropped
/// — the exact costume this file exists to take off. The plain `call` path
/// keeps its codes, which is why `syncUserContext` on the same device said
/// "this build got bounced" while the coach said "check your connection".
///
/// Only `unknown` is read this way; a real code is never second-guessed.
String callableErrorCode(FirebaseFunctionsException error) {
  if (error.code != 'unknown') return error.code;
  final words = (error.message ?? '').toLowerCase();
  if (words.contains('unauthenticated')) return 'unauthenticated';
  if (words.contains('permission')) return 'permission-denied';
  // NSURLError descriptions for a dead link: "The Internet connection appears
  // to be offline.", "The network connection was lost.", "The request timed
  // out." — and the gRPC names the SDK falls back to.
  if (words.contains('offline') ||
      words.contains('network connection') ||
      words.contains('timed out') ||
      words.contains('unavailable') ||
      words.contains('deadline')) {
    return 'unavailable';
  }
  return error.code;
}
