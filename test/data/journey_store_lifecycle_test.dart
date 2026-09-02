import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/api/fake/fake_server.dart';
import 'package:last_puff/data/backend_mode.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';

/// End-to-end store → repository → fake API lifecycle. Containers share one
/// FakeServer to prove the write-behind JSON actually round-trips: what one
/// "app session" mutates, the next login restores.
void main() {
  late FakeServer server;

  setUp(() => server = FakeServer(latency: Duration.zero));

  ProviderContainer harness() {
    final container = ProviderContainer(
      overrides: [
        backendModeProvider.overrideWithValue(BackendMode.fake),
        fakeServerProvider.overrideWithValue(server),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('logIn populates the journey; wrong password leaves it null', () async {
    final c = harness();
    final store = c.read(quitStoreProvider.notifier);

    await expectLater(
      store.logIn(email: 'maya@quitmail.com', password: '123'),
      throwsA(isA<InvalidCredentialsException>()),
    );
    expect(c.read(quitStoreProvider), isNull);

    expect(
      await store.logIn(email: 'maya@quitmail.com', password: 'secret1'),
      isTrue,
    );
    final journey = c.read(quitStoreProvider);
    expect(journey, isNotNull);
    expect(journey!.plan.dayNumber(DateTime.now()), 12);
  });

  test('signInWithGoogle onboards first, restores after', () async {
    final c = harness();
    final store = c.read(quitStoreProvider.notifier);
    expect(await store.signInWithGoogle(), isFalse);
    expect(c.read(quitStoreProvider), isNull);

    // Onboarding completes → the backend creates the journey.
    await store.startJourney(
      profile: const UserProfile(
        alias: '@bravewolf42',
        avatarEmoji: '🐺',
      ),
      plan: QuitPlan(
        method: QuitMethod.taper,
        paceDays: 30,
        startDate: DateTime(2026, 8, 18),
        baselinePuffsPerDay: 200,
        weeklySpend: 45,
        strength: NicStrength.mg50,
      ),
    );
    store.signOut();

    // A second app session: the Google account's journey comes back.
    final c2 = harness();
    expect(
      await c2.read(quitStoreProvider.notifier).signInWithGoogle(),
      isTrue,
    );
    expect(c2.read(quitStoreProvider)?.profile.alias, '@bravewolf42');
  });

  test('signInWithApple onboards first, restores after', () async {
    final c = harness();
    final store = c.read(quitStoreProvider.notifier);
    expect(await store.signInWithApple(), isFalse);
    expect(c.read(quitStoreProvider), isNull);

    // Onboarding completes → the backend creates the journey.
    await store.startJourney(
      profile: const UserProfile(
        alias: '@calmotter7',
        avatarEmoji: '🦦',
      ),
      plan: QuitPlan(
        method: QuitMethod.taper,
        paceDays: 30,
        startDate: DateTime(2026, 8, 18),
        baselinePuffsPerDay: 200,
        weeklySpend: 45,
        strength: NicStrength.mg50,
      ),
    );
    store.signOut();

    // A second app session: the Apple account's journey comes back.
    final c2 = harness();
    expect(await c2.read(quitStoreProvider.notifier).signInWithApple(), isTrue);
    expect(c2.read(quitStoreProvider)?.profile.alias, '@calmotter7');
  });

  test('mutations sync write-behind and survive logout → login', () async {
    final c1 = harness();
    final store1 = c1.read(quitStoreProvider.notifier);
    await store1.logIn(email: 'maya@quitmail.com', password: 'secret1');

    final puffsBefore = c1.read(todayProvider)!.puffs;
    store1
      ..logPuff()
      ..recordCravingSurvived();
    expect(c1.read(todayProvider)!.puffs, puffsBefore + 1);
    await pumpEventQueue(); // flush the unawaited saves

    store1.signOut();
    expect(c1.read(quitStoreProvider), isNull);

    // A second app session against the same backend.
    final c2 = harness();
    await c2
        .read(quitStoreProvider.notifier)
        .logIn(email: 'maya@quitmail.com', password: 'secret1');
    final restored = c2.read(quitStoreProvider)!;
    expect(c2.read(todayProvider)!.puffs, puffsBefore + 1);
    expect(restored.cravingsSurvivedTotal, 24); // seeded 23 + 1
  });

  test('startJourney creates a fresh day-1 journey on the backend', () async {
    final c = harness();
    final store = c.read(quitStoreProvider.notifier);
    await store.register(email: 'new@user.com', password: 'goodpass');

    await store.startJourney(
      profile: const UserProfile(
        alias: '@bravewolf42',
        avatarEmoji: '🐺',
        email: 'new@user.com',
      ),
      plan: QuitPlan(
        method: QuitMethod.taper,
        paceDays: 30,
        startDate: DateTime(2026, 8, 18),
        baselinePuffsPerDay: 200,
        weeklySpend: 45,
        strength: NicStrength.mg50,
      ),
    );

    final journey = c.read(quitStoreProvider)!;
    expect(journey.profile.alias, '@bravewolf42');
    expect(journey.days, hasLength(1));
    expect(journey.days.values.single.puffs, 0);
    // A day-1 journey holds ONLY what the user gave us. It used to arrive
    // with a savings goal ("Tokyo flight, \$1300") nobody chose, rendered
    // everywhere as the user's own — the same failure as an invented stat.
    expect(journey.goals, isEmpty);
    expect(journey.earnedBadges, isEmpty);

    // And it persists: restoreSession in a new session finds it.
    final c2 = harness();
    await c2.read(quitStoreProvider.notifier).restoreSession();
    expect(c2.read(quitStoreProvider)?.profile.alias, '@bravewolf42');
  });

  test('restoreSession never clobbers a live journey', () async {
    final c = harness();
    final store = c.read(quitStoreProvider.notifier);
    store.seedDemoJourney();
    final seeded = c.read(quitStoreProvider);

    await store.restoreSession();
    expect(identical(c.read(quitStoreProvider), seeded), isTrue);
  });

  test('seedDemoJourney plants the journey on the fake backend', () async {
    final c = harness();
    c.read(quitStoreProvider.notifier).seedDemoJourney();
    await pumpEventQueue();
    expect(server.journeyJsonForCurrentSession(), isNotNull);
  });
}
