/// `syncUserContext` is the least visible call in the app and one of the most
/// load-bearing: it creates `users/{uid}`, which both nightly crons page over,
/// and it is the push registry's only door.
///
/// It had no Dart coverage at all, and two bugs lived in that gap.
///
/// 1. **Sign-out released nothing.** The token went into the registry and only
///    ever came back out when a send to it failed, so the next person to use a
///    shared phone received the previous account's pushes.
/// 2. **Resume never re-synced.** `syncUserContext`'s own docstring says to
///    call it "on sign-in, on resume, and whenever the device timezone
///    changes", but the resume listener only pulled plan advice — so granting
///    notifications later from OS Settings, or flying to another timezone, did
///    not reach the server until the next cold session.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/data/seed/seed_data.dart';
import 'package:last_puff/domain/repositories/repositories.dart';

import '../helpers.dart';

/// Records what was called, in order, across both repositories — the ordering
/// is the whole point of the sign-out case.
final _calls = <String>[];

class _RecordingUserContext implements UserContextRepository {
  /// Held open by a test that wants to observe what happens *while* the
  /// release is still in flight.
  Completer<void>? gate;

  /// Set to make the sync fail, the way an App Check refusal does.
  Object? syncThrows;

  @override
  Future<void> sync({String? fcmToken}) async {
    _calls.add('sync');
    final failure = syncThrows;
    if (failure != null) throw failure;
  }

  @override
  Future<void> unregister() async {
    _calls.add('unregister');
    await gate?.future;
  }
}

class _RecordingAuth implements AuthRepository {
  /// Set to make the next registration fail, the way a taken address does.
  Object? registerThrows;

  /// What a session lookup finds. Null means there is nothing to restore.
  JourneyState? restored;

  @override
  Future<void> signOut() async => _calls.add('auth.signOut');

  @override
  Future<String?> currentUserId() async => 'uid-1';

  @override
  Future<String?> ensureSessionId() async => 'uid-1';

  @override
  Future<JourneyState?> restoreSession() async {
    _calls.add('auth.restoreSession');
    return restored;
  }

  @override
  Future<JourneyState?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _calls.add('auth.signInWithEmail');
    return restored;
  }

  @override
  Future<JourneyState?> signInWithApple() async => null;

  @override
  Future<JourneyState?> signInWithGoogle() async => null;

  @override
  Future<void> register({
    required String email,
    required String password,
  }) async {
    _calls.add('auth.register');
    final failure = registerThrows;
    if (failure != null) throw failure;
  }

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> deleteAccount() async => _calls.add('auth.deleteAccount');
}

void main() {
  late _RecordingUserContext context;
  late _RecordingAuth auth;

  setUp(() {
    _calls.clear();
    context = _RecordingUserContext();
    auth = _RecordingAuth();
  });

  List<Override> overrides() => [
    ...fastBackendOverrides(),
    userContextRepositoryProvider.overrideWithValue(context),
    authRepositoryProvider.overrideWithValue(auth),
  ];

  group('sign-out releases the device', () {
    test('unregisters before the credential goes', () async {
      final container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);
      container.read(quitStoreProvider.notifier).seedDemoJourney();

      container.read(quitStoreProvider.notifier).signOut();
      await pumpEventQueue();

      // A callable carries the caller's ID token, so releasing the device
      // after `signOut` would arrive unauthenticated and do nothing at all.
      expect(_calls, ['unregister', 'auth.signOut']);
    });

    test('signs out anyway when the release is still in flight', () async {
      // The release is best effort. A backend that hangs must not leave
      // someone who tapped "sign out" still signed in — least of all on the
      // shared phone this whole feature exists for.
      context.gate = Completer<void>();
      final container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);
      container.read(quitStoreProvider.notifier).seedDemoJourney();

      container.read(quitStoreProvider.notifier).signOut();
      await pumpEventQueue();

      expect(container.read(quitStoreProvider), isNull, reason: 'local state');
      context.gate!.complete();
      await pumpEventQueue();
      expect(_calls, ['unregister', 'auth.signOut']);
    });

    test('clears local state immediately, without waiting on the network', () {
      context.gate = Completer<void>();
      final container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);
      container.read(quitStoreProvider.notifier).seedDemoJourney();

      container.read(quitStoreProvider.notifier).signOut();

      expect(container.read(quitStoreProvider), isNull);
      context.gate!.complete();
    });
  });

  group('every path that establishes a session syncs', () {
    // `users/{uid}` is written by `syncUserContext` and NOWHERE else, so the
    // rule this group enforces is one line: a session established without a
    // sync is an account the server cannot see. No timezone, no locale and no
    // `recalcHourUtc`, so both nightly crons page straight past it; no device
    // row, so nothing can push to it — not even the nudge that would bring
    // the user back to finish onboarding.
    //
    // Registering was the one path that skipped it, which is why a freshly
    // registered account had an empty Firestore.

    test('registering creates the row the server needs', () async {
      final container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);

      await container
          .read(quitStoreProvider.notifier)
          .register(email: 'new@cirrus.app', password: 'secret123');
      await pumpEventQueue();

      expect(_calls, ['auth.register', 'sync']);
    });

    test('registering binds analytics to the new account', () async {
      // The same gap, a different cost: without this every registration looks
      // like a brand-new anonymous device and the funnel counts one person
      // twice.
      final analytics = RecordingAnalytics();
      final container = ProviderContainer(
        overrides: [
          ...overrides(),
          analyticsProvider.overrideWithValue(analytics),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(quitStoreProvider.notifier)
          .register(email: 'new@cirrus.app', password: 'secret123');
      await pumpEventQueue();

      expect(analytics.identified, ['uid-1']);
    });

    test('a refused registration syncs nothing', () async {
      // A taken address is not a session. Syncing for one would create a
      // `users/{uid}` row for a uid that does not exist.
      auth.registerThrows = EmailAlreadyInUseException();
      final container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(quitStoreProvider.notifier)
            .register(email: 'taken@cirrus.app', password: 'secret123'),
        throwsA(isA<EmailAlreadyInUseException>()),
      );
      await pumpEventQueue();

      expect(_calls, ['auth.register']);
    });

    test('a failing sync does not fail the registration', () async {
      // The user is standing in front of onboarding. A backend that cannot be
      // reached costs a cron cycle, never the account they just made. App
      // Check is the realistic cause and it fails every callable at once.
      context.syncThrows = StateError('App Check refused the token');
      final container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(quitStoreProvider.notifier)
            .register(email: 'new@cirrus.app', password: 'secret123'),
        completes,
      );
      await pumpEventQueue();
    });

    test('signing in syncs', () async {
      final container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);

      await container
          .read(quitStoreProvider.notifier)
          .logIn(email: 'a@b.c', password: 'secret123');
      await pumpEventQueue();

      expect(_calls, contains('sync'));
    });

    test('a restored session syncs', () async {
      auth.restored = SeedData.journey(DateTime(2026, 8, 30));
      final container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);

      await container.read(quitStoreProvider.notifier).restoreSession();
      await pumpEventQueue();

      expect(_calls, contains('sync'));
    });

    test('a launch with no session to restore syncs nothing', () async {
      // The other half of the rule. There is no uid here, so there is nothing
      // to create a row for, and creating one would leave an empty document
      // in front of both crons forever.
      final container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);

      await container.read(quitStoreProvider.notifier).restoreSession();
      await pumpEventQueue();

      expect(_calls, ['auth.restoreSession']);
    });
  });

  group('resume re-syncs', () {
    Future<ProviderContainer> pumpApp(WidgetTester tester) async {
      final container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const LastPuffApp(),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      return container;
    }

    void resume(WidgetTester tester) {
      // AppLifecycleListener fires onResume on the transition INTO resumed,
      // so the app has to leave first.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }

    testWidgets('a resumed app pushes its context again', (tester) async {
      final container = await pumpApp(tester);
      container.read(quitStoreProvider.notifier).seedDemoJourney();
      await tester.pumpAndSettle();
      _calls.clear();

      resume(tester);
      // `pump`, never `pumpEventQueue`: inside the widget binding's fake async
      // zone the latter waits on a queue the app keeps feeding, and hangs to
      // the ten-minute timeout.
      await tester.pump();

      expect(_calls, contains('sync'));
    });

    testWidgets('a signed-out resume syncs nothing', (tester) async {
      // Without the session guard this minted a fresh FCM token and burned a
      // refused callable on every foreground transition of the sign-in
      // screen — a wasted round trip that also looked like an auth failure in
      // every log it touched.
      await pumpApp(tester);
      _calls.clear();

      resume(tester);
      await tester.pump();

      expect(_calls, isNot(contains('sync')));
    });
  });

  group('account deletion releases the device', () {
    test('deleting the account deletes the local token too', () async {
      // The server rows die with `recursiveDelete`; this is the local half.
      // Without it the device keeps a live FCM token bound to an account that
      // no longer exists.
      final container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);
      container.read(quitStoreProvider.notifier).seedDemoJourney();

      await container.read(quitStoreProvider.notifier).deleteAccount();
      await pumpEventQueue();

      expect(_calls, ['auth.deleteAccount', 'unregister']);
      expect(container.read(quitStoreProvider), isNull);
    });
  });
}
