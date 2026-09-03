import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/coach_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/allowances.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';

import '../helpers.dart';

/// `limit_reached` — the walls, as opposed to the doors.
///
/// The eleven gates report `gate_shown`/`gate_tapped`, so a locked surface has
/// always been visible in the funnel. The **server-enforced** limits were not:
/// the coach cap rendered a template, `createPost` threw `permission-denied`,
/// and `panicSession` narrowed the AI option, and none of the three told
/// anybody. "Ran out of coach messages" read exactly like "never opened the
/// coach" — the same row, with opposite fixes.
///
/// These are the wiring tests. `analytics_test.dart` pins the vocabulary; a
/// green vocabulary with a call site that never fires is the failure mode this
/// file exists to catch.
void main() {
  // CommunityPrefs restores through a MethodChannel; without the binding it
  // logs a caught failure per test and buries the real output.
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer container(RecordingAnalytics analytics, {bool premium = false}) {
    final c = ProviderContainer(
      overrides: fastBackendOverrides(analytics: analytics, premium: premium),
    );
    addTearDown(c.dispose);
    return c;
  }

  group('the coach allowance', () {
    /// Spends the free allowance and asks once more. The fake answers the
    /// over-quota turn with `capReached`, exactly as `aiCoachChat` does.
    Future<void> spendAllowance(ProviderContainer c, {required int turns}) async {
      final coach = c.read(coachStoreProvider.notifier);
      for (var i = 0; i < turns; i++) {
        await coach.send('message $i');
      }
    }

    test('the wall is reported with the server\'s own allowance', () async {
      final analytics = RecordingAnalytics();
      final c = container(analytics);

      await spendAllowance(c, turns: LpAllowances.freeCoachMessages);
      // Nothing yet: five messages is using the product, not hitting a wall.
      expect(analytics.propsOfAll('limit_reached'), isEmpty);

      await spendAllowance(c, turns: 1);
      expect(analytics.propsOfAll('limit_reached'), [
        {
          'capability': 'coach',
          'tier': 'free',
          // `used` equals `limit` by definition at a cap, and both come from
          // the reply rather than from the client's own counter.
          'used': LpAllowances.freeCoachMessages,
          'limit': LpAllowances.freeCoachMessages,
        },
      ]);
    });

    test('every refused turn is its own wall, not just the first', () async {
      final analytics = RecordingAnalytics();
      final c = container(analytics);

      await spendAllowance(c, turns: LpAllowances.freeCoachMessages + 3);
      // Three refusals after the allowance ran out. Reporting only the first
      // would understate how hard people push against this cap, which is the
      // one number that says whether 5 is the right cap.
      expect(analytics.propsOfAll('limit_reached'), hasLength(3));
    });

    test('a turn the backend answers is never reported as a wall', () async {
      final analytics = RecordingAnalytics();
      final c = container(analytics, premium: true);

      // A subscriber's allowance is 100; five turns is nowhere near it.
      await spendAllowance(c, turns: 5);
      expect(analytics.propsOfAll('limit_reached'), isEmpty);
    });

    test('the offline path burns no message and reports no wall', () async {
      final analytics = RecordingAnalytics();
      final c = ProviderContainer(
        overrides: fastBackendOverrides(
          analytics: analytics,
          premium: false,
          online: false,
        ),
      );
      addTearDown(c.dispose);

      await c.read(coachStoreProvider.notifier).send('anyone there?');

      // An outage is not an allowance. Reporting it as one would inflate the
      // wall count with our own downtime and send the fix in the wrong
      // direction entirely.
      expect(analytics.propsOfAll('limit_reached'), isEmpty);
      expect(c.read(coachStoreProvider).freeUsedToday, 0);
    });

    test('a silent backend is read as the client tier, never as free', () async {
      // `CoachReply.isFreeTier` is null when the backend did not say — an
      // older build, a stub. Reading that as "free" would file a subscriber
      // who had just spent a hundred messages under the free tier's wall, and
      // the free-wall count is the number that decides whether 5 is right.
      final analytics = RecordingAnalytics();
      final c = ProviderContainer(
        overrides: [
          ...fastBackendOverrides(analytics: analytics, premium: true),
          coachRepositoryProvider.overrideWithValue(const _SilentCappedCoach()),
        ],
      );
      addTearDown(c.dispose);

      await c.read(coachStoreProvider.notifier).send('one more');

      expect(analytics.propsOfAll('limit_reached'), [
        {'capability': 'coach', 'tier': 'premium'},
      ]);
    });
  });

  group('the community allowance', () {
    test('the free post itself is not a wall', () async {
      final analytics = RecordingAnalytics();
      final c = container(analytics);
      c.read(quitStoreProvider.notifier).seedDemoJourney();

      c.read(communityStoreProvider.notifier).addPost(
        text: 'day three and still here',
        tag: PostTag.win,
      );
      await pumpEventQueue();

      // docs/12 §4.1: a free account gets one ordinary post a day. Using it
      // is the product working, not somebody hitting a limit.
      expect(analytics.propsOfAll('limit_reached'), isEmpty);
    });

    test('the post past the allowance is reported as the posting wall', () async {
      final analytics = RecordingAnalytics();
      final c = container(analytics);
      c.read(quitStoreProvider.notifier).seedDemoJourney();
      final store = c.read(communityStoreProvider.notifier);

      store.addPost(text: 'the one I get', tag: PostTag.win);
      await pumpEventQueue();
      store.addPost(text: 'one more thought', tag: PostTag.win);
      await pumpEventQueue();

      expect(analytics.propsOfAll('limit_reached'), [
        // No `used`/`limit`: neither number crosses the wire for this
        // refusal, and the client's guess must not sit in the server's column.
        {'capability': 'community_post', 'tier': 'free'},
      ]);
    });

    test('an SOS is never a wall', () async {
      final analytics = RecordingAnalytics();
      final c = container(analytics);
      c.read(quitStoreProvider.notifier).seedDemoJourney();

      c.read(communityStoreProvider.notifier).addPost(
        text: 'about to cave, talk me down',
        tag: PostTag.sos,
      );
      await pumpEventQueue();

      // The one post a free account has always been able to make. If this ever
      // reports a wall, someone has paywalled a crisis.
      expect(analytics.propsOfAll('limit_reached'), isEmpty);
    });

    test('a rules refusal is moderation, not an allowance', () async {
      final analytics = RecordingAnalytics();
      final c = container(analytics, premium: true);
      c.read(quitStoreProvider.notifier).seedDemoJourney();

      c.read(communityStoreProvider.notifier).addPost(
        text: _slur,
        tag: PostTag.win,
      );
      await pumpEventQueue();

      // Nothing about this post would be allowed at any price, so it is not a
      // conversion signal and must never appear in the wall funnel.
      expect(analytics.propsOfAll('limit_reached'), isEmpty);
    });
  });

  group('the coach cap bubble', () {
    test('carries the enforcing side\'s number, not a literal', () async {
      final analytics = RecordingAnalytics();
      final c = container(analytics);

      for (var i = 0; i < LpAllowances.freeCoachMessages + 1; i++) {
        await c.read(coachStoreProvider.notifier).send('m$i');
      }

      final last = c.read(coachStoreProvider).messages.last;
      expect(last.template, CoachTemplate.capReached);
      // The generic reply card also has a `limit` — the day's PUFF allowance.
      // Sending that one here would make the cap bubble quote the taper curve
      // at somebody who ran out of messages.
      expect(last.args['limit'], LpAllowances.freeCoachMessages);
      expect(last.args.containsKey('today'), isFalse);
    });

    test('the store\'s caps stay a fallback, never the authority', () {
      // Documented mirrors of the two server params. If either drifts from
      // `functions/.env.alastpuff` the copy quotes a cap nobody enforces.
      expect(CoachStore.freeDailyCap, LpAllowances.freeCoachMessages);
      expect(CoachStore.premiumDailyCap, 100);
    });
  });
}

/// Split so the literal never appears in a grep of the source.
const _slur = 'you ${'ret'}${'ard'}';

/// A cap reply from a backend that never says which allowance it enforced —
/// the shape an older build sends.
class _SilentCappedCoach implements CoachRepository {
  const _SilentCappedCoach();

  @override
  Stream<CoachEvent> streamReply({
    String? text,
    CoachChip? chip,
    required bool capped,
    int? panicIntensity,
  }) async* {
    yield const CoachDone(CoachReply(template: CoachTemplate.capReached));
  }

  @override
  Future<List<CoachMessage>> history() async => const [];

  @override
  Future<List<CoachMemory>> memories() async => const [];

  @override
  Future<void> seedMemories() async {}

  @override
  Future<void> forgetMemory(String id) async {}
}
