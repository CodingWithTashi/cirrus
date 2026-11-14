import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../../domain/repositories/repositories.dart';

/// Remote Config's `force_update_app` and `update_release_notes`.
///
/// The only file importing `firebase_remote_config`. Constructed only on the
/// Firebase backend (`remoteFlagsRepositoryProvider`): the fake backend and
/// every widget test never call `Firebase.initializeApp`, and
/// `FirebaseRemoteConfig.instance` throws without it.
///
/// **Fail open, and the cached-true edge is the reason for the shape.** A
/// fetch that fails or times out this launch answers `forceUpdate: false`
/// even if an earlier launch activated `true` — an app must never be locked
/// by a value it could not confirm. The notes may come from the cache or the
/// default: they are shown only for the version the store is offering, so a
/// stale copy says nothing wrong.
class FirebaseRemoteFlagsRepository implements RemoteFlagsRepository {
  FirebaseRemoteFlagsRepository({FirebaseRemoteConfig? config})
    : _config = config;

  final FirebaseRemoteConfig? _config;

  static const forceKey = 'force_update_app';
  static const notesKey = 'update_release_notes';

  /// How long the fetch may take before the launch stops caring. The SDK's
  /// own `fetchTimeout` is set a little shorter, so in the usual failure the
  /// SDK gives up first and says why.
  static const timeout = Duration(seconds: 5);

  @override
  Future<RemoteFlags> fetch() async {
    final FirebaseRemoteConfig config;
    try {
      config = _config ?? FirebaseRemoteConfig.instance;
    } on Object {
      return RemoteFlags.none;
    }
    try {
      await config.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 4),
          // An hour in release — Remote Config's own throttle advice, and a
          // flag flipped in the console reaches everyone within it. Zero in
          // debug and profile so a device check sees a change at once.
          minimumFetchInterval: kReleaseMode
              ? const Duration(hours: 1)
              : Duration.zero,
        ),
      );
      await config.setDefaults(const {forceKey: false, notesKey: '{}'});
      // Inside the hour this completes from the SDK's cache without a network
      // call, which is still Remote Config answering: the values are at most
      // an hour old, from a fetch that succeeded.
      await config.fetchAndActivate().timeout(timeout);
      return RemoteFlags(
        forceUpdate: config.getBool(forceKey),
        releaseNotes: _notes(config),
      );
    } on Object catch (error) {
      debugPrint('remote flags: fetch failed, nothing forced — $error');
      return RemoteFlags(releaseNotes: _notes(config));
    }
  }

  static String _notes(FirebaseRemoteConfig config) {
    try {
      return config.getString(notesKey);
    } on Object {
      return '{}';
    }
  }
}
