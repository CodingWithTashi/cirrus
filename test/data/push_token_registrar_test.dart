import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/api/firebase/push_messages.dart';
import 'package:last_puff/data/api/firebase/push_service.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/repositories/repositories.dart';

import '../helpers.dart';

/// The invariant this whole class exists for: **while a session exists and
/// the user has granted notifications, the server holds this device's current
/// FCM token.**
///
/// Every test below is one way that used to stop being true silently. They
/// are worth reading as the list of what "push is dead on iOS" was actually
/// made of: not one bug, but a registration with no owner, spread across
/// seven fire-and-forget call sites that each `.ignore()`d their own failure.
/// A fixed clock. A suite that reads `DateTime.now()` passes in the morning
/// and fails at night — see the Home card-priority trap in CLAUDE.md.
final _now = DateTime(2026, 9, 5, 14, 12);

void main() {
  late _RecordingUsers users;
  late _FakePush push;

  ProviderContainer containerWith({bool signedIn = true}) {
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(now: _now),
        pushMessagesProvider.overrideWithValue(push),
        userContextRepositoryProvider.overrideWithValue(users),
      ],
    );
    addTearDown(container.dispose);
    if (signedIn) {
      // A journey is what `quitStoreProvider` answers with, and the registrar
      // reads exactly that to decide whether there is anyone to register for.
      container
          .read(quitStoreProvider.notifier)
          .replaceForTest(journeyOnDay(3, now: _now));
    }
    return container;
  }

  setUp(() {
    users = _RecordingUsers();
    push = _FakePush();
  });

  tearDown(() => push.dispose());

  test('registers the token once a session exists', () async {
    push.currentToken = 'tok-a';
    final container = containerWith();

    await container.read(pushTokenRegistrarProvider).ensure();

    expect(users.tokens, ['tok-a']);
  });

  test('does not register when nobody is signed in', () async {
    // The QA L6 case: FCM mints a token on a fresh install long before
    // anyone signs in, and `syncUserContext` carries the caller's ID token —
    // so a sessionless attempt is a refused call, not a queued one.
    push.currentToken = 'tok-a';
    final container = containerWith(signedIn: false);

    await container.read(pushTokenRegistrarProvider).ensure();

    expect(users.tokens, isEmpty);
  });

  test('holds a token that arrives before the session does', () async {
    // THE reinstall bug. `onTokenRefresh` fires within milliseconds of
    // launch, while `restoreSession()` is still in flight — so "no session,
    // give up" caught the ordinary cold start as well as the signed-out case
    // it was written for, and the token it discarded is the one a reinstall
    // mints, which is exactly when the server holds a stale one.
    final container = containerWith(signedIn: false);
    final registrar = container.read(pushTokenRegistrarProvider);

    registrar.onTokenRefreshed('rotated');
    await pumpEventQueue();
    expect(users.tokens, isEmpty, reason: 'nothing to register it against');

    container
        .read(quitStoreProvider.notifier)
        .replaceForTest(journeyOnDay(3, now: _now));
    await registrar.ensure();

    expect(users.tokens, ['rotated'], reason: 'the held token is flushed');
  });

  test('registers a rotation immediately when signed in', () async {
    push.currentToken = 'tok-a';
    final container = containerWith();
    final registrar = container.read(pushTokenRegistrarProvider);
    await registrar.ensure();

    registrar.onTokenRefreshed('tok-b');
    await pumpEventQueue();

    expect(users.tokens, ['tok-a', 'tok-b']);
  });

  test('does not re-send a token it has already confirmed', () async {
    // Resume, a token refresh and a permission grant can all land in the same
    // second. Re-asserting the invariant has to be cheap enough to do freely.
    push.currentToken = 'tok-a';
    final container = containerWith();
    final registrar = container.read(pushTokenRegistrarProvider);

    await registrar.ensure();
    await registrar.ensure();
    await registrar.ensure();

    expect(users.tokens, ['tok-a']);
  });

  test('re-sends after a permission grant even if nothing changed', () async {
    // The grant is precisely what changes the answer a previous `ensure`
    // correctly gave, so this one path must ignore the "already registered"
    // shortcut.
    push.currentToken = 'tok-a';
    final container = containerWith();
    final registrar = container.read(pushTokenRegistrarProvider);
    await registrar.ensure();

    registrar.onPermissionGranted();
    await pumpEventQueue();

    expect(users.tokens, ['tok-a', 'tok-a']);
  });

  test('retries when granted but the token is not ready yet', () async {
    // **The iOS bug, in miniature.** `tokenOrNull()` returns null until APNs
    // has answered, which is the ordinary state for the first second of a
    // launch. The old arrangement sent nothing and never tried again, so the
    // device stayed unreachable for the whole session.
    push.currentToken = null;
    push.currentPermission = PushPermission.granted;
    final container = containerWith();
    final registrar = container.read(pushTokenRegistrarProvider);

    await registrar.ensure();
    expect(users.tokens, isEmpty);

    // APNs answers a beat later, as it does on every real launch.
    push.currentToken = 'late-token';
    await registrar.ensure();

    expect(users.tokens, ['late-token']);
  });

  test('does not retry a refusal', () async {
    // The other null. Retrying a decline is pointless, and on Android
    // actively harmful — `requestPermission()` auto-denies after two
    // dismissals without showing anything.
    push.currentToken = null;
    push.currentPermission = PushPermission.denied;
    final container = containerWith();

    await container.read(pushTokenRegistrarProvider).ensure();

    expect(users.tokens, isEmpty);
    expect(push.permissionReads, 1);
  });

  test('retries a failed registration', () async {
    // The gap that made all seven old call sites single points of failure:
    // every one of them `.ignore()`d the future, so a backend having a bad
    // minute cost the device its reachability until something unrelated
    // happened to sync again.
    push.currentToken = 'tok-a';
    users.failNext = 1;
    final container = containerWith();
    final registrar = container.read(pushTokenRegistrarProvider);

    await registrar.ensure();
    expect(users.tokens, ['tok-a'], reason: 'attempted');
    expect(users.succeeded, isEmpty, reason: 'and failed');

    await registrar.ensure();

    expect(users.succeeded, ['tok-a'], reason: 'a failure is not the end');
  });

  test('forgets the device on sign-out', () async {
    // Sixth thing to forget on a shared phone. Without it the next account on
    // the same handset is assumed already registered and never registered at
    // all — the same class of bug as the analytics reset and the milestone
    // ledger.
    push.currentToken = 'tok-a';
    final container = containerWith();
    final registrar = container.read(pushTokenRegistrarProvider);
    await registrar.ensure();

    registrar.forget();
    await registrar.ensure();

    expect(users.tokens, ['tok-a', 'tok-a']);
  });

  test('is completely inert where there is no FCM', () async {
    // Desktop, web, the fake backend and every widget test. Reaching for a
    // platform channel that is not there is what this seam exists to stop.
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(now: _now),
        pushMessagesProvider.overrideWithValue(null),
        userContextRepositoryProvider.overrideWithValue(users),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(quitStoreProvider.notifier)
        .replaceForTest(journeyOnDay(3, now: _now));

    await container.read(pushTokenRegistrarProvider).ensure();

    expect(users.tokens, isEmpty);
  });
}

/// A [UserContextRepository] that records what was registered, and can fail.
class _RecordingUsers implements UserContextRepository {
  /// Every token the registrar attempted, in order.
  final tokens = <String>[];

  /// Every token that actually landed.
  final succeeded = <String>[];

  /// Fail this many of the next calls, the way an offline minute would.
  int failNext = 0;

  @override
  Future<void> sync({
    String? fcmToken,
    Map<String, Object?>? pushPrefs,
    List<String>? readThreads,
    List<String>? readNotifications,
  }) async {
    if (fcmToken == null) return;
    tokens.add(fcmToken);
    if (failNext > 0) {
      failNext--;
      throw const NoConnectionException();
    }
    succeeded.add(fcmToken);
  }

  @override
  Future<void> unregister() async {}
}

/// A [PushMessages] whose answers the test sets directly.
class _FakePush implements PushMessages {
  final _opened = StreamController<RemoteMessage>.broadcast();
  final _foreground = StreamController<RemoteMessage>.broadcast();
  final _tokens = StreamController<String>.broadcast();

  String? currentToken;
  PushPermission currentPermission = PushPermission.granted;

  /// So the "do not retry a refusal" test can prove the decision was reached
  /// once and not re-litigated on a timer.
  int permissionReads = 0;

  @override
  Stream<RemoteMessage> get onOpened => _opened.stream;

  @override
  Stream<RemoteMessage> get onForeground => _foreground.stream;

  @override
  Stream<String> get onTokenRefresh => _tokens.stream;

  @override
  Future<RemoteMessage?> initialMessage() async => null;

  @override
  Future<String?> token() async => currentToken;

  @override
  Future<PushPermission> permission() async {
    permissionReads++;
    return currentPermission;
  }

  @override
  Future<void> ensureChannels() async {}

  void dispose() {
    _opened.close();
    _foreground.close();
    _tokens.close();
  }
}
