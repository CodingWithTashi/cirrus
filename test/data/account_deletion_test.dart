import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/api/fake/fake_auth_api.dart';
import 'package:last_puff/data/api/fake/fake_server.dart';
import 'package:last_puff/data/backend_mode.dart';
import 'package:last_puff/data/repositories/api_auth_repository.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/repositories/repositories.dart';

/// Account deletion (App Store 5.1.1(v), docs/03 §11).
///
/// Every other mutation in `JourneyStore` is optimistic and may fail silently
/// — the offline banner tells that story and the write retries later. Erasure
/// is the exception, and these tests are what stops it drifting back to the
/// optimistic pattern: a deletion that failed while the UI said it succeeded
/// is a broken promise, not a sync delay.
void main() {
  late FakeServer server;

  setUp(() => server = FakeServer(latency: Duration.zero));

  ProviderContainer harness({bool deletionFails = false}) {
    final container = ProviderContainer(
      overrides: [
        backendModeProvider.overrideWithValue(BackendMode.fake),
        fakeServerProvider.overrideWithValue(server),
        if (deletionFails)
          authRepositoryProvider.overrideWithValue(
            _FailingDelete(ApiAuthRepository(FakeAuthApi(server))),
          ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a confirmed deletion clears the session and the backend', () async {
    final c = harness();
    final store = c.read(quitStoreProvider.notifier);
    await store.logIn(email: 'maya@quitmail.com', password: 'secret1');
    store.logPuff();
    final marked = c.read(quitStoreProvider)!.logFor(DateTime.now())!.puffs;

    await store.deleteAccount();
    expect(c.read(quitStoreProvider), isNull);
    // Nothing to restore: the stored document is gone, not merely forgotten
    // locally.
    await store.restoreSession();
    expect(c.read(quitStoreProvider), isNull);

    // The demo shim re-seeds a pristine day-12 journey for any email on first
    // sign-in, so the proof that the old one was destroyed is that the puff
    // logged above is not in it.
    await store.logIn(email: 'maya@quitmail.com', password: 'secret1');
    expect(
      c.read(quitStoreProvider)!.logFor(DateTime.now())!.puffs,
      isNot(marked),
    );
  });

  group('the milestone ledger is per account, not per phone', () {
    // It lives in device-scoped SharedPreferences with no uid in the key, and
    // a badge marked settled makes the planner answer null for ever. So
    // without a reset the next person to sign in on a shared phone inherits
    // this account's settled badges and never gets a single celebration.
    test('signing out forgets it', () async {
      final c = harness();
      final store = c.read(quitStoreProvider.notifier);
      final settings = c.read(settingsStoreProvider.notifier);
      await store.logIn(email: 'maya@quitmail.com', password: 'secret1');

      settings.adoptMilestones({'spark'});
      settings.markMilestonesCelebrated('weekFlame', {'spark', 'weekFlame'});
      expect(c.read(settingsStoreProvider).celebratedMilestones, isNotEmpty);

      store.signOut();

      final after = c.read(settingsStoreProvider);
      expect(after.celebratedMilestones, isEmpty);
      expect(after.armedMilestone, isNull);
      expect(
        after.milestonesAdopted,
        isFalse,
        reason: 'the next account adopts its own history, it does not inherit',
      );
    });

    test('deleting the account forgets it too', () async {
      final c = harness();
      final store = c.read(quitStoreProvider.notifier);
      final settings = c.read(settingsStoreProvider.notifier);
      await store.logIn(email: 'maya@quitmail.com', password: 'secret1');
      settings.adoptMilestones({'spark', 'weekFlame'});

      await store.deleteAccount();

      expect(c.read(settingsStoreProvider).celebratedMilestones, isEmpty);
      expect(c.read(settingsStoreProvider).milestonesAdopted, isFalse);
    });
  });

  test('a failed deletion throws and leaves the session standing', () async {
    final c = harness(deletionFails: true);
    final store = c.read(quitStoreProvider.notifier);
    await store.logIn(email: 'maya@quitmail.com', password: 'secret1');
    final journey = c.read(quitStoreProvider);
    expect(journey, isNotNull);

    await expectLater(
      store.deleteAccount(),
      throwsA(isA<NoConnectionException>()),
    );

    // The account still exists, so the session must survive: signing the user
    // out here would strand them on the auth screen believing their data was
    // erased when none of it was, with no way to retry.
    expect(c.read(quitStoreProvider), same(journey));
  });
}

/// Succeeds at everything except erasure — the shape of an offline device, or
/// of the `deleteUserData` callable rejecting the request.
class _FailingDelete implements AuthRepository {
  _FailingDelete(this._inner);

  final AuthRepository _inner;

  @override
  Future<void> deleteAccount() async => throw const NoConnectionException();

  @override
  Future<String?> currentUserId() => _inner.currentUserId();

  @override
  Future<String?> ensureSessionId() => _inner.ensureSessionId();

  @override
  Future<JourneyState?> restoreSession() => _inner.restoreSession();

  @override
  Future<JourneyState?> signInWithEmail({
    required String email,
    required String password,
  }) => _inner.signInWithEmail(email: email, password: password);

  @override
  Future<JourneyState?> signInWithApple() => _inner.signInWithApple();

  @override
  Future<JourneyState?> signInWithGoogle() => _inner.signInWithGoogle();

  @override
  Future<void> register({required String email, required String password}) =>
      _inner.register(email: email, password: password);

  @override
  Future<void> requestPasswordReset(String email) =>
      _inner.requestPasswordReset(email);

  @override
  Future<void> signOut() => _inner.signOut();
}
