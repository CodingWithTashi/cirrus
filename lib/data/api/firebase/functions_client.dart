import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_functions/cloud_functions.dart';
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
      throw _mapError(error);
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
Object _mapError(FirebaseFunctionsException error) => switch (error.code) {
  'unavailable' || 'deadline-exceeded' => const NoConnectionException(),
  'unauthenticated' => const InvalidCredentialsException(),
  _ => error,
};
