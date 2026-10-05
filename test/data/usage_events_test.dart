import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/api/fake/fake_server.dart';
import 'package:last_puff/data/network/connectivity.dart';
import 'package:last_puff/data/stores/coach_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';

import '../helpers.dart';

/// The front door, the coach and the community — the three places the
/// Oct 5 2026 dashboard read could only answer with "the screen was opened".
///
/// Nine of thirty-two real people never reached the first onboarding question,
/// and nothing said whether they left the sign-in screen or were turned away
/// by it. Six people opened the coach and eight the community, and nothing
/// said whether any of them said a word.
///
/// These are the wiring tests; `analytics_test.dart` pins the names.
void main() {
  // CommunityPrefs restores through a MethodChannel (see limit_reached_test).
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer container(
    RecordingAnalytics analytics, {
    bool online = true,
    List<Override> extra = const [],
  }) {
    final c = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(analytics: analytics, online: online),
        ...extra,
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('sign-in', () {
    test('an existing account is a returning sign-in', () async {
      final analytics = RecordingAnalytics();
      final c = container(analytics);

      final restored = await c
          .read(quitStoreProvider.notifier)
          .logIn(email: FakeServer.demoEmail, password: 'hunter22');

      expect(restored, isTrue);
      expect(analytics.propsOfAll('sign_in_completed'), [
        {'method': 'email', 'returning': 'true'},
      ]);
    });

    test('a new account is not a returning one, by either door', () async {
      final analytics = RecordingAnalytics();
      final c = container(analytics);
      final store = c.read(quitStoreProvider.notifier);

      await store.register(email: 'new@quitmail.com', password: 'hunter22');
      await store.signInWithApple();

      expect(analytics.propsOfAll('sign_in_completed'), [
        {'method': 'email_register', 'returning': 'false'},
        {'method': 'apple', 'returning': 'false'},
      ]);
    });

    test('a refusal is reported by its taxonomy name and still thrown', () async {
      final analytics = RecordingAnalytics();
      final c = container(analytics);
      final store = c.read(quitStoreProvider.notifier);

      await expectLater(
        store.logIn(email: FakeServer.demoEmail, password: 'nope'),
        throwsA(isA<InvalidCredentialsException>()),
      );
      await expectLater(
        store.register(email: FakeServer.demoEmail, password: 'hunter22'),
        throwsA(isA<EmailAlreadyInUseException>()),
      );

      expect(analytics.propsOfAll('sign_in_failed'), [
        {'method': 'email', 'code': 'invalid_credentials'},
        {'method': 'email_register', 'code': 'email_in_use'},
      ]);
      // A refused attempt is not a session.
      expect(analytics.names, isNot(contains('sign_in_completed')));
    });

    test('no connection is its own code, not a wrong password', () async {
      final analytics = RecordingAnalytics();
      final c = container(analytics, online: false);

      await expectLater(
        c
            .read(quitStoreProvider.notifier)
            .logIn(email: FakeServer.demoEmail, password: 'hunter22'),
        throwsA(isA<NoConnectionException>()),
      );

      expect(analytics.propsOfAll('sign_in_failed'), [
        {'method': 'email', 'code': 'offline'},
      ]);
    });

    test('a dismissed sheet is a cancel, never a failure', () async {
      final analytics = RecordingAnalytics();
      final c = container(
        analytics,
        extra: [authRepositoryProvider.overrideWithValue(_DismissedSheet())],
      );

      await expectLater(
        c.read(quitStoreProvider.notifier).signInWithGoogle(),
        throwsA(isA<SignInCancelledException>()),
      );

      expect(analytics.propsOfAll('sign_in_cancelled'), [
        {'method': 'google'},
      ]);
      expect(analytics.names, isNot(contains('sign_in_failed')));
    });
  });

  group('the coach', () {
    test('typed words and a chip are told apart, and so is a craving', () async {
      final analytics = RecordingAnalytics();
      final c = container(analytics);
      final coach = c.read(coachStoreProvider.notifier);

      await coach.send('rough morning');
      await coach.sendChip(CoachChip.values.first, panicIntensity: 8);

      expect(analytics.propsOfAll('coach_message_sent'), [
        {'kind': 'typed', 'panic': 'false'},
        {'kind': 'chip', 'panic': 'true'},
      ]);
    });

    test('an empty message is nothing said', () async {
      final analytics = RecordingAnalytics();
      final c = container(analytics);

      await c.read(coachStoreProvider.notifier).send('   ');

      expect(analytics.names, isNot(contains('coach_message_sent')));
    });

    test('a retry re-asks the same message and is not counted again', () async {
      final analytics = RecordingAnalytics();
      final c = container(analytics, online: false);
      final coach = c.read(coachStoreProvider.notifier);

      await coach.send('anyone there?');
      // The ask is counted even though nothing answered: the person tried.
      expect(analytics.propsOfAll('coach_message_sent'), hasLength(1));
      expect(
        CoachStore.isFailure(c.read(coachStoreProvider).messages.last),
        isTrue,
      );

      await coach.retryLast();
      expect(analytics.propsOfAll('coach_message_sent'), hasLength(1));
    });
  });

  group('the community', () {
    test('a post the backend took is reported with its tag', () async {
      final analytics = RecordingAnalytics();
      final c = container(analytics);
      c.read(quitStoreProvider.notifier).seedDemoJourney();

      c
          .read(communityStoreProvider.notifier)
          .addPost(text: 'day three and still here', tag: PostTag.win);
      await pumpEventQueue();

      expect(analytics.propsOfAll('community_post_created'), [
        {'tag': 'win'},
      ]);
    });

    test('a post that never left the phone reached nobody', () async {
      final analytics = RecordingAnalytics();
      final c = container(analytics, online: false);
      c.read(quitStoreProvider.notifier).seedDemoJourney();

      c
          .read(communityStoreProvider.notifier)
          .addPost(text: 'day three and still here', tag: PostTag.win);
      await pumpEventQueue();

      expect(analytics.names, isNot(contains('community_post_created')));
    });

    test('a reply is reported, and says whether it answered an SOS', () async {
      final analytics = RecordingAnalytics();
      final c = container(analytics);
      c.read(quitStoreProvider.notifier).seedDemoJourney();
      final store = c.read(communityStoreProvider.notifier);
      await pumpEventQueue();
      final posts = c.read(communityStoreProvider).posts;
      final sos = posts.firstWhere((p) => p.tag == PostTag.sos);
      final other = posts.firstWhere((p) => p.tag != PostTag.sos);

      expect(await store.addReply(sos.id, 'you have got this'), isTrue);
      expect(await store.addReply(other.id, 'well done, truly'), isTrue);

      expect(analytics.propsOfAll('community_reply_created'), [
        {'sos': 'true'},
        {'sos': 'false'},
      ]);
    });

    test('a reply kept on this phone alone answered nobody', () async {
      final analytics = RecordingAnalytics();
      final c = container(analytics, online: false);
      final wire = c.read(connectivityProvider.notifier) as ToggleConnectivity
        ..set(true);
      c.read(quitStoreProvider.notifier).seedDemoJourney();
      final store = c.read(communityStoreProvider.notifier);
      await pumpEventQueue();
      final post = c.read(communityStoreProvider).posts.first;

      // The connection goes after the feed has loaded. The reply stays in the
      // thread — that is the local-first stance — and is still not an event.
      wire.set(false);
      expect(await store.addReply(post.id, 'you have got this'), isTrue);

      expect(analytics.names, isNot(contains('community_reply_created')));
    });
  });
}

/// A native Apple/Google sheet the person closed.
class _DismissedSheet implements AuthRepository {
  @override
  Future<JourneyState?> signInWithGoogle() async =>
      throw const SignInCancelledException();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
