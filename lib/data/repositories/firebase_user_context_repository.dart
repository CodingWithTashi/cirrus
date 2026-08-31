import 'package:flutter/foundation.dart';

import '../../domain/repositories/repositories.dart';
import '../api/firebase/functions_client.dart';
import '../api/firebase/push_service.dart';

/// Calls `syncUserContext`, the app's only write path into the server-owned
/// `users/{uid}` document.
///
/// Until this ran at least once, `users/{uid}` did not exist for anybody —
/// which meant both nightly crons paged over an empty collection and silently
/// did nothing, forever (B9). It is the least visible call in the app and one
/// of the most load-bearing.
class FirebaseUserContextRepository implements UserContextRepository {
  FirebaseUserContextRepository({LpFunctions? functions})
    : _functions = functions ?? LpFunctions();

  /// How long sign-out will wait for the server to release this device.
  ///
  /// Bounded because the alternative is worse than a stale registry row: a
  /// backend having a bad minute would leave someone who tapped "sign out"
  /// still signed in, on the shared phone this whole path exists for. The
  /// local `deleteToken` has already stopped delivery by then, so what this
  /// timeout costs is tidiness, not silence.
  static const Duration releaseTimeout = Duration(seconds: 4);

  /// How long sign-out will wait for FCM itself.
  ///
  /// The local half needs bounding too: `tokenOrNull`/`deleteToken` are
  /// platform-channel calls that normally answer in milliseconds but sit on
  /// the plugin's own network client, and `_auth.signOut()` is chained behind
  /// this whole method — an unbounded hang here left "sign out" doing nothing
  /// visible forever, which is the exact failure the callable's timeout was
  /// added to prevent.
  static const Duration localTimeout = Duration(seconds: 2);

  final LpFunctions _functions;

  @override
  Future<void> sync({String? fcmToken}) async {
    // Look the token up here rather than at the call site: every caller wants
    // it registered, and none of them should have to remember. Null is normal
    // — the user may simply not have granted notifications yet.
    final token = fcmToken ?? await PushService.tokenOrNull();
    try {
      await _functions.call('syncUserContext', {
        'fcmToken': ?token,
        'platform': ?(token == null ? null : PushService.platformName),
      });
    } on Object catch (error) {
      // Every current caller fire-and-forgets this, so a failure reached
      // nobody and the symptom was an empty `users` collection with no signal
      // anywhere — which is exactly how it presented. The rethrow keeps the
      // contract for anyone who later wants to await it; the log is so a dev
      // build stops failing in complete silence.
      //
      // The usual cause is App Check: `syncUserContext` sets
      // `enforceAppCheck: true`, and a token the backend will not accept
      // fails every callable at once without looking like an App Check
      // problem. Run through `./tool/device.ps1` so the debug token define is
      // never forgotten.
      debugPrint('syncUserContext failed — $error');
      rethrow;
    }
  }

  @override
  Future<void> unregister() async {
    // Local first, and unconditionally: deleting the token is what actually
    // stops this device receiving, it needs no network and no session, and it
    // cannot be undone by a server that is unreachable. Every stage is
    // bounded — `signOut()` chains behind this method, so any hang here is a
    // sign-out that visibly does nothing.
    String? token;
    try {
      token = await PushService.tokenOrNull().timeout(localTimeout);
    } on Object {
      token = null;
    }
    try {
      await PushService.deleteToken().timeout(localTimeout);
    } on Object {
      // Timed out; FCM keeps whatever state it has. The server release below
      // still runs when we managed to read the token in time.
    }
    if (token == null) return;
    try {
      await _functions
          .call('syncUserContext', {'removeFcmToken': token})
          .timeout(releaseTimeout);
    } on Object {
      // Offline, slow, or already signed out. The device is silent either
      // way, and the row is swept by `pruneDevices` after 60 unseen days.
    }
  }
}

/// The fake-backend stand-in. There is no server to tell anything, so this
/// does nothing rather than pretending to succeed against a fixture.
class NoopUserContextRepository implements UserContextRepository {
  const NoopUserContextRepository();

  @override
  Future<void> sync({String? fcmToken}) async {}

  @override
  Future<void> unregister() async {}
}
