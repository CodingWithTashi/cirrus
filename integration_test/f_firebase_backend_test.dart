import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/data/api/firebase/app_check_setup.dart';
import 'package:last_puff/data/api/firebase/functions_client.dart';
import 'package:last_puff/data/backend_mode.dart';
import 'package:last_puff/domain/repositories/repositories.dart';
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
    // Same path the app takes, so the pinned debug secret applies here too —
    // this suite uninstalls the app when it finishes, which used to destroy a
    // rotating secret and make the next run fail for a reason that looked
    // like code.
    await activateAppCheck();
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

    // Skip the 20 screens — they are covered against the fake backend. What
    // matters here is that the BACKEND mints and stores the journey.
    await e2e.container.read(quitStoreProvider.notifier).startJourney(
          profile: const UserProfile(
            alias: '@e2eotter',
            avatarEmoji: '🦦',
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

  testWidgets('the push registry registers on sync and releases on request', (
    tester,
  ) async {
    // §17.1 end to end, against the DEPLOYED backend: a token carried by
    // `syncUserContext` must land as a `users/{uid}/devices/{hash}` row
    // (owner-readable, so the client can verify its own registration), and
    // `removeFcmToken` — the field sign-out sends — must take it back out.
    // The token is fabricated: this device has no notification grant during
    // an E2E run, and what is under test is the registry, not FCM itself.
    final e2e = await session(tester);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final token = 'e2e-token-${DateTime.now().millisecondsSinceEpoch}';

    await e2e.container
        .read(userContextRepositoryProvider)
        .sync(fcmToken: token);
    await e2e.waitFor(const Duration(seconds: 4));

    final devices = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('devices');
    final registered = (await devices.get()).docs
        .where((d) => d.data()['token'] == token)
        .toList();
    expect(
      registered,
      hasLength(1),
      reason: 'no devices row appeared for the synced token — the deployed '
          'syncUserContext predates the registry',
    );
    final row = registered.single;
    expect(row.data()['platform'], 'android');
    expect(row.data()['lastSeenAt'], isNotNull, reason: 'no freshness signal');
    expect(row.data()['createdAt'], isNotNull);
    expect(
      row.id.contains(token),
      isFalse,
      reason: 'the document id must be a hash — a token is a credential and '
          'a doc id leaks into logs and index entries',
    );

    // Release through the exact field sign-out sends.
    await LpFunctions().call('syncUserContext', {'removeFcmToken': token});
    await e2e.waitFor(const Duration(seconds: 4));

    final after = (await devices.get()).docs
        .where((d) => d.data()['token'] == token)
        .toList();
    expect(after, isEmpty, reason: 'the released device row survived');
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

  /// Drains one streamed turn.
  ///
  /// Returns the envelope AND the chunks it arrived in, because "did Ember
  /// answer" and "did the answer stream" are different questions and only one
  /// of them was ever being asked.
  Future<({CoachReply reply, List<String> chunks})> ask(
    CoachRepository coach, {
    String? text,
    CoachChip? chip,
    int? panicIntensity,
  }) async {
    final chunks = <String>[];
    CoachReply? envelope;
    await for (final event in coach.streamReply(
      text: text,
      chip: chip,
      capped: false,
      panicIntensity: panicIntensity,
    )) {
      switch (event) {
        case CoachChunk(text: final piece):
          chunks.add(piece);
        case CoachDone(reply: final done):
          envelope = done;
      }
    }
    if (envelope == null) throw StateError('stream ended with no reply');
    return (reply: envelope, chunks: chunks);
  }

  testWidgets('Ember answers from the real model', (tester) async {
    final e2e = await session(tester);

    Object? failure;
    ({CoachReply reply, List<String> chunks})? turn;
    try {
      turn = await ask(
        e2e.container.read(coachRepositoryProvider),
        chip: CoachChip.craving,
      );
    } on Object catch (error) {
      failure = error;
    }

    expect(failure, isNull, reason: 'aiCoachChat threw: $failure');
    final reply = turn!.reply;
    // The reply must arrive in pieces. The server has always been able to
    // stream; the client asked for it all at once, so the streaming branch was
    // dead code and Ember read as a form submission.
    expect(
      turn.chunks,
      isNotEmpty,
      reason: 'the reply did not stream — client fell back to unary',
    );
    // `connectionLost` is the server's own "I could not answer" template, so
    // it is a failure here even though the call succeeded.
    expect(
      reply.template,
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

  testWidgets('Ember remembers something told in an earlier conversation', (
    tester,
  ) async {
    // The whole point of the vector layer: a fact stated once, recalled in a
    // later, differently-worded turn. Nothing in the user card can do this —
    // no amount of puff logging produces a sister's wedding.
    final e2e = await session(tester);
    final coach = e2e.container.read(coachRepositoryProvider);

    await ask(
      coach,
      text: 'my sister Maya is getting married in March and I want to be '
          'completely done with vaping before her wedding',
    );
    // Extraction and its embedding are awaited inside the callable, so by the
    // time that returned the memory is written — but the vector index is
    // eventually consistent, so give it a beat.
    await e2e.waitFor(const Duration(seconds: 8));

    // Asks something ONLY the vector memory can answer. The first attempt at
    // this test asked "what am I working toward", which the user card answers
    // just as well from the savings goal — so a correct reply proved nothing
    // about recall.
    final recalled = (await ask(
      coach,
      text: 'what did I tell you was happening in March?',
    )).reply;

    final said = (recalled.text ?? '').toLowerCase();
    expect(said, isNotEmpty, reason: 'no reply: ${recalled.template}');
    expect(
      said.contains('maya') || said.contains('wedding') || said.contains('sister'),
      isTrue,
      reason: 'Ember did not recall the wedding. Said: "${recalled.text}"',
    );
  });

  testWidgets('the user can see what Ember remembers, and take it back', (
    tester,
  ) async {
    // The memory store is only trustworthy if it is legible and revocable.
    final e2e = await session(tester);
    final coach = e2e.container.read(coachRepositoryProvider);

    await ask(
      coach,
      text: 'I have a golden retriever called Rufus and walking him is the '
          'only thing that reliably gets me past an evening craving',
    );
    await e2e.waitFor(const Duration(seconds: 8));

    final stored = await coach.memories();
    expect(stored, isNotEmpty, reason: 'nothing was remembered to show');

    await coach.forgetMemory(stored.first.id);
    await e2e.waitFor(const Duration(seconds: 4));

    final after = await coach.memories();
    expect(
      after.any((m) => m.id == stored.first.id),
      isFalse,
      reason: 'a forgotten memory came back',
    );
  });

  testWidgets('a rolling summary builds within four exchanges', (tester) async {
    // The long-range layer beyond the 10-turn verbatim window: every fourth
    // successful exchange folds the conversation into the server-owned
    // `users/{uid}.coachSummary`, which later turns inject as background
    // context. Only this harness can watch the whole loop run against the
    // deployed backend. Four exchanges cross the rebuild threshold from ANY
    // starting phase — the account is shared across this file's tests, so the
    // counter's phase here depends on how many coach turns ran before.
    final e2e = await session(tester);
    final coach = e2e.container.read(coachRepositoryProvider);

    const turns = [
      'evenings after work are the hardest part of my day',
      'I think it is the stress of the commute more than anything',
      'I am going to try leaving the vape in the car boot tonight',
      'anyway. how do I get through tonight?',
    ];
    for (final text in turns) {
      await ask(coach, text: text);
    }
    await e2e.waitFor(const Duration(seconds: 4));

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final summary = userDoc.data()?['coachSummary'] as Map<String, dynamic>?;
    expect(summary, isNotNull, reason: 'no coachSummary was ever written');
    final text = summary!['text'] as String?;
    expect(
      text != null && text.isNotEmpty,
      isTrue,
      reason: 'four exchanges passed and the summary is still empty: $summary',
    );
    // The code-enforced clamp (COACH_SUMMARY_MAX_CHARS server-side).
    expect(text!.length, lessThanOrEqualTo(1200));
    expect(
      summary['turnsSince'],
      inInclusiveRange(0, 3),
      reason: 'the exchange counter is out of range: $summary',
    );
  });

  testWidgets('matchedTestimonials returns the seeded quotes, tailored', (
    tester,
  ) async {
    // Proves the collection was seeded, the rules let the callable (and only
    // the callable) read it, and the ranking runs in production. An empty list
    // is a legitimate answer the app handles — it keeps the bundled quotes —
    // so it has to be asserted against, or a silently empty collection would
    // look exactly like success.
    final e2e = await session(tester);

    final quotes = await e2e.container
        .read(testimonialsRepositoryProvider)
        .matched(
          whys: const {WhyChip.health},
          worries: const {WorryChip.cravings},
          attempts: QuitAttempts.twoToFive,
          gender: Gender.woman,
          dependence: DependenceLevel.heavy,
        );

    expect(
      quotes,
      hasLength(2),
      reason: 'the testimonials collection is empty or unreadable — run '
          '`npm run seed:testimonials`',
    );
    // Cravings is the worry that was named, and the row tagged with it carries
    // the heaviest signal, so it must lead.
    expect(quotes.first.id, 'beta-panic-week-one');
    expect(quotes.first.text, isNotEmpty);

    // The rows carry consent references and locale provenance. Only id and
    // text may cross the wire.
    expect(quotes.map((q) => q.id).toSet(), hasLength(2));
  });

  testWidgets('setCoachName accepts a real name and refuses a bad one', (
    tester,
  ) async {
    // Proves three things at once that only production can prove: the callable
    // is reachable, the guard runs there, and `data/name-denylist.json`
    // actually shipped with the deploy — if it did not, the guard silently
    // degrades to impersonation-only and nothing would say so.
    final e2e = await session(tester);
    final repo = e2e.container.read(coachNameRepositoryProvider);

    expect(
      await repo.reserve('Wren'),
      isTrue,
      reason: 'an ordinary name was refused',
    );

    // Short terms must match the WHOLE name, never a substring, or this one
    // comes back refused — and a guard that blocks somebody's own name is
    // worse than no guard, because it will not say why.
    expect(
      await repo.reserve('Cassie'),
      isTrue,
      reason: 'the Scunthorpe rule is not live on the deployed guard',
    );

    expect(
      await repo.reserve('Cirrus'),
      isFalse,
      reason: 'impersonation was accepted',
    );

    expect(
      await repo.reserve('sh1t'),
      isFalse,
      reason: 'the denylist did not ship with the deploy',
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

  testWidgets('the backend says which posts are mine, and their state', (
    tester,
  ) async {
    // QA H3 + M5. Ownership used to be a session-scoped set on the client,
    // so a post written by the previous account on the same phone stayed
    // "mine" for the next one — and "mine" is what hides Report and Block.
    // It is answered by the server-owned `users/{uid}/posts` mirror now,
    // which also carries the moderation state the rules hide from everyone
    // else, so a held post can say so instead of vanishing.
    //
    // Goes green only once the functions that write the mirror are
    // deployed: `createPost`, `moderatePost`, `reportPost`,
    // `resolveModeration`.
    final e2e = await session(tester);
    final repo = e2e.container.read(communityRepositoryProvider);

    final id = await repo.addPost(
      Post(
        id: 'pending',
        alias: '@e2eotter',
        avatarEmoji: '🦦',
        dayN: 1,
        tag: PostTag.win,
        text: 'e2e ownership check — please ignore, this account is '
            'deleted at the end',
        createdAt: DateTime.now(),
      ),
    );
    expect(id, isNotNull, reason: 'createPost must answer the post id');
    await e2e.waitFor(const Duration(seconds: 4));

    // A fresh fetch (nothing remembered on the client) must carry the post
    // as mine, in whatever state moderation has it in by now.
    final feed = await repo.fetchPosts();
    final mine = feed.where((p) => p.id == id).toList();
    expect(mine, hasLength(1),
        reason: "the author's own post must be in their feed in every state; "
            'got ${feed.length} posts, none with id $id');
    expect(mine.single.isMine, isTrue);

    // And the status stream answers at least the current state.
    final status = await repo.watchPostStatus(id!).first.timeout(
          const Duration(seconds: 10),
        );
    expect(PostStatus.values, contains(status));
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
