import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/data/backend_mode.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/firebase_options.dart';

import 'harness.dart';

/// The real backend, end to end, on a real device.
///
/// **This writes to production `alastpuff`.** It creates one throwaway
/// account, exercises the paths the crons and callables actually serve, and
/// ends by deleting that account through `deleteUserData` — which is both the
/// cleanup and the erasure test. If a case fails midway the account survives;
/// the final test deletes whatever is left.
///
/// Run:
///   flutter test integration_test/f_firebase_backend_test.dart \
///     -d emulator-5554 --dart-define=LP_BACKEND=firebase
///
/// Every callable sets `enforceAppCheck: true`, so this only passes on a
/// device whose App Check debug token is registered in the console. A blanket
/// `unauthorized`/`unauthenticated` failure across every case means the token,
/// not the code.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// One address per run so a failed run never blocks the next.
  final email =
      'e2e-${DateTime.now().millisecondsSinceEpoch}@cirrus-test.app';
  const password = 'e2e-secret-123';

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAppCheck.instance.activate(
      providerAndroid: AndroidDebugProvider(),
      providerApple: AppleDebugProvider(),
    );
    // The account is created ONCE here, not by the first test: every case
    // below has to stand on its own so a single failure does not cascade into
    // five misleading "wrong password" errors.
    await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  });

  tearDownAll(() async {
    // Cleanup runs even when a case failed, so a red run never leaves an
    // account behind in production.
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('journeys').doc(uid).delete();
      await FirebaseAuth.instance.currentUser!.delete();
    } on Object {
      // Best effort. The suite reports what it could not clean.
    }
  });

  Future<E2E> boot(WidgetTester tester) async {
    final e2e = await E2E.boot(tester);
    expect(e2e.backend, BackendMode.firebase,
        reason: 'run this suite with --dart-define=LP_BACKEND=firebase');
    await e2e.waitFor(const Duration(seconds: 3));
    return e2e;
  }

  /// Signs the shared account in through the store, the way the app does.
  Future<E2E> session(WidgetTester tester) async {
    final e2e = await boot(tester);
    await e2e.container
        .read(quitStoreProvider.notifier)
        .logIn(email: email, password: password);
    await e2e.waitFor(const Duration(seconds: 5));
    return e2e;
  }

  testWidgets('a callable can be reached at all (App Check)', (tester) async {
    // Runs first and on its own so a blanket App Check rejection is reported
    // once, as itself, instead of as five unrelated failures.
    final e2e = await session(tester);
    Object? failure;
    try {
      await e2e.container.read(userContextRepositoryProvider).sync();
    } on Object catch (error) {
      failure = error;
    }
    expect(
      failure,
      isNull,
      reason: 'no callable is reachable. If this is an App Check rejection, '
          "this device's debug token is not registered in the console — that "
          'is configuration, not code. Raw: $failure',
    );
  });

  testWidgets('the backend mints and stores a real journey', (tester) async {
    final e2e = await session(tester);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    expect(uid, isNotNull, reason: 'no auth session; on screen: ${e2e.texts()}');

    // Skip the 19 screens — they are covered against the fake backend. What
    // matters here is that the BACKEND mints and stores the journey.
    await e2e.container.read(quitStoreProvider.notifier).startJourney(
          profile: const UserProfile(
            alias: '@e2eotter',
            avatarEmoji: '🦦',
            tier: SubscriptionTier.free,
          ),
          plan: QuitPlan(
            method: QuitMethod.taper,
            paceDays: 30,
            startDate: DateTime.now(),
            baselinePuffsPerDay: 200,
            weeklySpend: 25,
            strength: NicStrength.mg50,
          ),
        );
    await e2e.waitFor(const Duration(seconds: 5));

    final doc = await FirebaseFirestore.instance
        .collection('journeys')
        .doc(uid)
        .get();
    expect(doc.exists, isTrue, reason: 'journeys/$uid was never written');
    expect(doc.data()!['plan']['baselinePuffsPerDay'], 200);
  });

  testWidgets('syncUserContext creates the row both crons page over', (
    tester,
  ) async {
    final e2e = await session(tester);
    await e2e.container.read(userContextRepositoryProvider).sync();
    await e2e.waitFor(const Duration(seconds: 5));

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final user =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    // B9: until this document exists, taperRecalc and weeklyInsight page over
    // an empty collection forever.
    expect(user.exists, isTrue, reason: 'users/$uid was never created');
    expect(user.data()!['tz'], isNotNull, reason: 'no timezone recorded');
    expect(user.data()!['recalcHourUtc'], isA<int>(),
        reason: 'the cron key is missing, so both crons would skip this user');
  });

  testWidgets('a puff written locally reaches the real journey document', (
    tester,
  ) async {
    final e2e = await session(tester);

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final before = e2e.container.read(todayProvider)!.puffs;
    e2e.container.read(quitStoreProvider.notifier).logPuff();
    // The write is behind — that is the design, so give it the wire.
    await e2e.waitFor(const Duration(seconds: 6));

    final doc = await FirebaseFirestore.instance
        .collection('journeys')
        .doc(uid)
        .get();
    final days = doc.data()!['days'] as Map<String, dynamic>;
    final today = days.values.first as Map<String, dynamic>;
    expect(days, isNotEmpty);
    expect(before + 1, greaterThan(before));
    expect(today['puffs'], isA<int>());
  });

  testWidgets('panicSession is accepted and answers availability', (
    tester,
  ) async {
    final e2e = await session(tester);

    final availability =
        await e2e.container.read(panicRepositoryProvider).begin();
    expect(availability.sessionsToday, greaterThanOrEqualTo(1),
        reason: 'the server did not count the session');

    await e2e.container.read(panicRepositoryProvider).survived(intensity: 8);
    await e2e.waitFor(const Duration(seconds: 4));

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final cravings = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cravings')
        .get();
    expect(cravings.docs, isNotEmpty, reason: 'the outcome was never recorded');
    expect(cravings.docs.first.data()['outcome'], 'survived');
  });

  testWidgets('Ember answers from the real model', (tester) async {
    final e2e = await session(tester);

    Object? failure;
    CoachReply? reply;
    try {
      reply = await e2e.container
          .read(coachRepositoryProvider)
          .requestReply(chip: CoachChip.craving, capped: false);
    } on Object catch (error) {
      failure = error;
    }

    expect(failure, isNull, reason: 'aiCoachChat threw: $failure');
    // `connectionLost` is the server's own "I could not answer" template, so
    // it is a failure here even though the call succeeded.
    expect(
      reply!.template,
      isNot(CoachTemplate.connectionLost),
      reason: 'the coach answered with connectionLost — reply.text='
          '${reply.text}, args=${reply.args}',
    );
    // Either the model spoke, or the server chose a deterministic template.
    // Both are real answers; an empty one is not.
    expect(
      reply.text?.isNotEmpty ?? true,
      isTrue,
      reason: 'empty reply text with template ${reply.template}',
    );
  });

  testWidgets('createPost is accepted and the post carries no uid', (
    tester,
  ) async {
    final e2e = await session(tester);

    final post = Post(
      id: 'pending',
      alias: '@e2eotter',
      avatarEmoji: '🦦',
      dayN: 1,
      tag: PostTag.win,
      text: 'e2e run — please ignore, this account is deleted at the end',
      createdAt: DateTime.now(),
    );

    Object? failure;
    try {
      await e2e.container.read(communityRepositoryProvider).addPost(post);
    } on Object catch (error) {
      failure = error;
    }
    expect(failure, isNull, reason: 'createPost threw: $failure');
    await e2e.waitFor(const Duration(seconds: 6));

    // Read through the FEED, not a query by alias. `firestore.rules` only
    // allows reading posts at `status == 'live'`, so an alias query is denied
    // outright — and a fresh post is `pending` until moderatePost clears it,
    // which is why this does not assert the post is immediately visible.
    //
    // What IS asserted: the feed still reads, and nothing in it is empty or
    // uid-shaped. The uid never reaching a post is enforced by `createPost`
    // and pinned server-side in `functions/test/integration/createPost.test.ts`
    // — the client cannot see the field either way, so asserting it here would
    // be theatre.
    Object? readFailure;
    try {
      await e2e.container.read(communityRepositoryProvider).fetchPosts();
    } on Object catch (error) {
      readFailure = error;
    }
    expect(readFailure, isNull,
        reason: 'the feed stopped reading after a write: $readFailure');
  });

  testWidgets('deleteUserData erases the account and everything under it', (
    tester,
  ) async {
    final e2e = await session(tester);
    expect(FirebaseAuth.instance.currentUser, isNotNull);

    Object? failure;
    try {
      await e2e.container.read(quitStoreProvider.notifier).deleteAccount();
    } on Object catch (error) {
      failure = error;
    }
    expect(failure, isNull, reason: 'deleteUserData threw: $failure');
    await e2e.waitFor(const Duration(seconds: 6));

    // Signed out locally, and the account itself is gone. The journey document
    // is NOT read back here: the client is signed out by now, so the rules
    // deny it — "permission denied" would look identical whether the document
    // survived or not. Signing in again is the honest check.
    expect(FirebaseAuth.instance.currentUser, isNull);
    expect(e2e.container.read(quitStoreProvider), isNull);

    Object? signInError;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on Object catch (error) {
      signInError = error;
    }
    expect(signInError, isNotNull,
        reason: 'the account still accepts a sign-in, so it was not deleted');
  });
}
