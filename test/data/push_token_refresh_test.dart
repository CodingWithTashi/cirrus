import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:last_puff/data/api/firebase/push_messages.dart';
import 'package:last_puff/data/api/firebase/push_service.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/repositories/repositories.dart';

import '../helpers.dart';

/// QA L6 (Aug 31 2026, production): a fresh install with no session logged
/// `syncUserContext failed — InvalidCredentialsException` on cold launch.
/// The tracker pins that a launch with no session syncs nothing — and the
/// restore path honours that — but FCM mints a token on first launch and the
/// token-refresh listener re-registered it unconditionally, signed out or
/// not. Log-only, but every sessionless launch burned a refused callable.
///
/// The refresh path now goes through [PushTokenRegistrar], which is the one
/// thing that knows whether there is a session to sync for — and, unlike the
/// store that owned this before it, holds a token that arrives *before* the
/// session rather than discarding it. Broader coverage of the registrar
/// itself lives in `push_token_registrar_test.dart`; these two cases stay
/// here because they are the incident.
class _RecordingUserContext implements UserContextRepository {
  final synced = <String?>[];

  @override
  Future<void> sync({
    String? fcmToken,
    Map<String, Object?>? pushPrefs,
    List<String>? readThreads,
    List<String>? readNotifications,
  }) async => synced.add(fcmToken);

  @override
  Future<void> unregister() async {}
}

void main() {
  late _RecordingUserContext context;

  setUp(() => context = _RecordingUserContext());

  ProviderContainer harness() {
    final push = _SilentPush();
    addTearDown(push.dispose);
    final c = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        // The registrar is inert without a `PushMessages`, which is correct
        // on the fake backend and useless here: this suite is about the
        // refresh path itself.
        pushMessagesProvider.overrideWithValue(push),
        userContextRepositoryProvider.overrideWithValue(context),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('a token refresh with no session syncs nothing', () async {
    final c = harness();

    c.read(quitStoreProvider.notifier).onPushTokenRefreshed('fcm-1');
    await pumpEventQueue();

    expect(context.synced, isEmpty);
  });

  test('a token refresh with a session re-registers that token', () async {
    final c = harness();
    c.read(quitStoreProvider.notifier).seedDemoJourney();

    c.read(quitStoreProvider.notifier).onPushTokenRefreshed('fcm-2');
    await pumpEventQueue();

    expect(context.synced, ['fcm-2']);
  });
}

/// A [PushMessages] that has nothing of its own to say: the refreshed token
/// is handed in directly, so `token()` is never the source here.
class _SilentPush implements PushMessages {
  final _opened = StreamController<RemoteMessage>.broadcast();
  final _foreground = StreamController<RemoteMessage>.broadcast();
  final _tokens = StreamController<String>.broadcast();

  @override
  Stream<RemoteMessage> get onOpened => _opened.stream;

  @override
  Stream<RemoteMessage> get onForeground => _foreground.stream;

  @override
  Stream<String> get onTokenRefresh => _tokens.stream;

  @override
  Future<RemoteMessage?> initialMessage() async => null;

  @override
  Future<String?> token() async => null;

  @override
  Future<PushPermission> permission() async => PushPermission.notAsked;

  @override
  Future<void> ensureChannels() async {}

  void dispose() {
    _opened.close();
    _foreground.close();
    _tokens.close();
  }
}
