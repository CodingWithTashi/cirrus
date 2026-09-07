import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/repositories.dart';
import '../api/firebase/push_messages.dart';
import '../api/firebase/push_service.dart';
import 'providers.dart';

/// **The one owner of "a signed-in device is reachable by push."**
///
/// ## Why this exists
///
/// Registering the FCM token used to be a side effect of seven unrelated call
/// sites — sign-in, restore, resume, the three permission CTAs, and the token
/// refresh stream — each calling `syncUserContext` fire-and-forget and each
/// `.ignore()`ing the result. That arrangement has no notion of whether the
/// device is *currently* registered, so **every one of those seven was a
/// silent single point of failure**: if the call failed, or the token was not
/// available at the instant it ran, nothing noticed and nothing tried again.
/// The device simply stopped being reachable, and the failure of a push is
/// silence, which looks like nothing.
///
/// That is exactly how iOS ended up unreachable while Android worked. On iOS
/// `tokenOrNull()` returns null until APNs has answered, so the sign-in sync
/// legitimately had no token to send — and there was no second attempt,
/// because no code anywhere held the belief "this device should be
/// registered and is not".
///
/// This class holds that belief. Everything else calls [ensure] and forgets.
///
/// ## The invariant
///
/// *While a session exists and the user has granted notifications, the server
/// holds this device's current FCM token.*
///
/// It is maintained by re-asserting it at every moment it could have become
/// false, and by retrying until it is true:
///
/// * a session appears (sign-in, register, restore, guest onboarding),
/// * the app resumes (the token may have rotated while it was away, and
///   permission may have been granted in system settings, which the app is
///   never told about),
/// * a permission CTA is granted,
/// * FCM rotates the token — which it does on every reinstall,
/// * and on a backoff timer after any of those failed.
///
/// ## Two nulls, and only one of them is retriable
///
/// [PushMessages.token] answers null for "the user declined" and for "iOS has
/// not handed APNs' token to FCM yet". The first is final; retrying it is
/// pointless and, on Android, actively harmful (`requestPermission()`
/// auto-denies after two dismissals). The second clears in under a second and
/// MUST be retried, because it is the ordinary state at launch. [ensure]
/// reads [PushMessages.permission] to tell them apart.
///
/// ## Why the record is in memory and not on disk
///
/// [_registeredToken] is per app session on purpose. A persisted "already
/// registered" ledger would be device-scoped but account-shaped — the exact
/// shape the sign-out forget list exists to clean up after (see
/// `celebratedMilestones`) — and it would buy nothing: the first [ensure] of
/// a cold start is a call this app wants to make anyway, because it is also
/// what refreshes `lastSeenAt` and keeps `pruneDevices` from sweeping the row
/// after 60 days. So the only thing worth remembering is what we have already
/// confirmed *this run*, which is enough to stop a resume storm from sending
/// the same token five times.
///
/// ## Inert where there is no FCM
///
/// [PushMessages] is null on the fake backend, so desktop, web and every
/// widget test construct a registrar that does nothing at all — the same
/// arrangement `_PushSync` uses, and for the same reason: `fastBackend-
/// Overrides()` pins tests to the fake, and reaching for a platform channel
/// that is not there is how this seam earned its existence.
class PushTokenRegistrar {
  PushTokenRegistrar(this._ref);

  final Ref _ref;

  /// The token we have confirmed the server holds, this run. Null means "not
  /// known to be registered", which is the state every cold start begins in,
  /// and the state [forget] returns us to.
  ///
  /// Deliberately NOT keyed by uid. Doing that meant asking
  /// `currentUserId()` on the hot path and skipping registration whenever it
  /// answered null or was slow — one more way to silently do nothing, which
  /// is the exact failure mode this class was written to remove. Account
  /// changes are covered from the other side instead, and more reliably:
  /// [forget] runs on sign-out and account deletion, and every path that
  /// establishes a session calls [onSessionEstablished], which re-sends
  /// unconditionally.
  String? _registeredToken;

  /// A token FCM handed us while there was no session to file it under.
  ///
  /// Held rather than dropped. `onTokenRefresh` fires within milliseconds of
  /// launch, while `restoreSession()` is still in flight — so a plain "no
  /// session, give up" caught the ordinary cold start as well as the
  /// signed-out case it was meant for, and the token it threw away is the one
  /// a REINSTALL mints, which is precisely when the server is holding a stale
  /// one.
  String? _pending;

  /// Coalesces concurrent runs. Resume, a token refresh and a permission
  /// grant can land in the same frame; without this they would each fire
  /// their own callable with the same token.
  Future<void>? _inFlight;

  Timer? _retry;
  int _attempt = 0;
  bool _disposed = false;

  /// How long to wait before re-asserting the invariant after a failure.
  ///
  /// Front-loaded because the overwhelmingly common case is the APNs
  /// round-trip finishing a beat after launch, and long-tailed because the
  /// other case is a backend having a bad minute, where hammering it helps
  /// nobody. It stops after the last step rather than retrying forever: by
  /// then the next resume is a better trigger than any timer, and an app in
  /// the background has no business holding one.
  static const retryDelays = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 60),
    Duration(minutes: 5),
  ];

  PushMessages? get _messages => _ref.read(pushMessagesProvider);

  UserContextRepository get _users => _ref.read(userContextRepositoryProvider);

  /// Re-asserts the invariant. Safe to call from anywhere, at any time, as
  /// often as you like.
  ///
  /// [force] re-sends even a token we have already confirmed — what a
  /// permission grant wants, because the token that was refused before the
  /// grant is the one the server is missing.
  Future<void> ensure({bool force = false}) {
    final running = _inFlight;
    if (running != null) return running;
    final run = _run(force: force);
    _inFlight = run;
    return run.whenComplete(() => _inFlight = null);
  }

  Future<void> _run({required bool force}) async {
    if (_disposed) return;
    final messages = _messages;
    // No FCM here: the fake backend, desktop, web, every widget test.
    if (messages == null) return;

    // No session means nothing to register the device against. The callable
    // carries the caller's ID token, so a sessionless attempt is a refused
    // call, not a queued one (QA L6).
    if (_ref.read(quitStoreProvider) == null) return;

    String? token;
    try {
      token = _pending ?? await messages.token();
    } on Object catch (error) {
      debugPrint('push-registrar: token lookup failed — $error');
      token = null;
    }
    if (_disposed) return;

    if (token == null || token.isEmpty) {
      // Which null is it? Only one of them is worth coming back for.
      final permission = await _permissionOrNull(messages);
      if (permission == PushPermission.granted) {
        // Granted but no token yet: iOS has not handed APNs' token to FCM.
        // This is the ordinary state for the first second of a launch, and
        // the state the whole class exists to survive.
        debugPrint('push-registrar: granted but no token yet — will retry');
        _scheduleRetry();
      } else {
        // Declined, or never asked. Nothing to register and nothing to wait
        // for; a later grant comes back through `onPermissionGranted`.
        _cancelRetry();
      }
      return;
    }

    // The session went away underneath us (sign-out mid-flight). Registering
    // now would bind this device to an account that has left, which is the
    // shared-phone leak `unregister()` exists to prevent.
    if (_ref.read(quitStoreProvider) == null) return;

    if (!force && _registeredToken == token) {
      _pending = null;
      _cancelRetry();
      return;
    }

    try {
      await _users.sync(fcmToken: token);
      if (_disposed) return;
      _registeredToken = token;
      _pending = null;
      _cancelRetry();
      debugPrint('push-registrar: device registered (…${_tail(token)}).');
    } on Object catch (error) {
      // The one thing the old arrangement never did. A failed registration is
      // a device that will hear nothing until something else happens to try
      // again — so we try again.
      debugPrint('push-registrar: registration failed — $error');
      _scheduleRetry();
    }
  }

  Future<PushPermission?> _permissionOrNull(PushMessages messages) async {
    try {
      return await messages.permission();
    } on Object {
      return null;
    }
  }

  /// FCM rotated this device's token.
  ///
  /// Registered immediately when there is a session, held when there is not —
  /// see [_pending].
  void onTokenRefreshed(String token) {
    _pending = token;
    // A new token invalidates whatever we believed was registered.
    _registeredToken = null;
    ensure().ignore();
  }

  /// A permission CTA was granted.
  ///
  /// [force] because the interesting case is the one where [ensure] has
  /// already run and correctly concluded there was nothing to register: the
  /// grant is what changes that answer.
  void onPermissionGranted() => ensure(force: true).ignore();

  /// A session appeared — sign-in, register, restore, guest onboarding.
  ///
  /// Forcing, because this is the one moment the ACCOUNT may have changed.
  /// A device whose token is unchanged still has to be registered against
  /// whoever just signed in, and `registerDevice` is an idempotent overwrite,
  /// so the redundant case costs one cheap call and the missed case costs the
  /// user every push they were ever going to get.
  void onSessionEstablished() => ensure(force: true).ignore();

  /// The app came back to the foreground.
  ///
  /// Not forcing: the token usually has not changed, and this fires every
  /// time the user switches back to the app. What it IS for is the two things
  /// that can change while the app is away — FCM rotating the token, and the
  /// user granting notifications in system settings, which the app is never
  /// told about.
  void onResume() => ensure().ignore();

  /// Sign-out and account deletion.
  ///
  /// Forgets what this device was, so the next account on the same phone is
  /// registered from scratch rather than being assumed already done — the
  /// same class of shared-phone bug as the analytics reset and the milestone
  /// ledger. The server-side release is `UserContextRepository.unregister`,
  /// which the store already chains ahead of the credential going away; this
  /// is only the belief.
  void forget() {
    _registeredToken = null;
    _pending = null;
    _cancelRetry();
  }

  void _scheduleRetry() {
    if (_disposed) return;
    if (_attempt >= retryDelays.length) return;
    final delay = retryDelays[_attempt];
    _attempt++;
    _retry?.cancel();
    _retry = Timer(delay, () => ensure().ignore());
  }

  void _cancelRetry() {
    _attempt = 0;
    _retry?.cancel();
    _retry = null;
  }

  /// Never the token itself: a registration token is a credential — anyone
  /// holding one can push to this device.
  String _tail(String token) =>
      token.length <= 6 ? token : token.substring(token.length - 6);

  void dispose() {
    _disposed = true;
    _cancelRetry();
  }
}
