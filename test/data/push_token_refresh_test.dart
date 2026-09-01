import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
/// The refresh path now goes through the store, which knows whether there is
/// a session to sync for.
class _RecordingUserContext implements UserContextRepository {
  final synced = <String?>[];

  @override
  Future<void> sync({String? fcmToken}) async => synced.add(fcmToken);

  @override
  Future<void> unregister() async {}
}

void main() {
  late _RecordingUserContext context;

  setUp(() => context = _RecordingUserContext());

  ProviderContainer harness() {
    final c = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
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
