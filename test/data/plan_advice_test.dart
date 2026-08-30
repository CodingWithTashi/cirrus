import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/api/fake/fake_server.dart';
import 'package:last_puff/data/backend_mode.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';

/// The nightly adaptive layer, client side (docs/03 §3.3).
///
/// `taperRecalc` writes a verdict into the server-owned `users/{uid}` document
/// just after the user's local midnight; the app reads it and folds it into
/// its own journey. Everything worth testing here is a guard: applying it on
/// the wrong day, or applying it twice, are both silently wrong rather than
/// loud, and both change the number the user is held to.
void main() {
  late FakeServer server;
  late _StubServerState stub;

  setUp(() {
    server = FakeServer(latency: Duration.zero);
    stub = _StubServerState();
  });

  ProviderContainer harness() {
    final container = ProviderContainer(
      overrides: [
        backendModeProvider.overrideWithValue(BackendMode.fake),
        fakeServerProvider.overrideWithValue(server),
        serverStateRepositoryProvider.overrideWithValue(stub),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// A signed-in day-12 journey (the seeded demo account).
  Future<ProviderContainer> signedIn() async {
    final c = harness();
    await c
        .read(quitStoreProvider.notifier)
        .logIn(email: 'maya@quitmail.com', password: 'secret1');
    expect(c.read(quitStoreProvider), isNotNull);
    return c;
  }

  PlanAdvice adviceFor(
    DateTime day, {
    int limit = 91,
    PlanAdherence adherence = PlanAdherence.struggling,
    int stretchDelta = 0,
  }) => PlanAdvice(
    forDay: JourneyState.dateKey(day),
    limit: limit,
    adherence: adherence,
    stretchDelta: stretchDelta,
  );

  test("today's advice becomes the limit the whole app reads", () async {
    final c = await signedIn();
    final curveLimit = c.read(todayProvider)!.limit;

    c.read(quitStoreProvider.notifier).applyPlanAdvice(
      adviceFor(DateTime.now(), limit: curveLimit + 20),
    );

    // TodaySnapshot, the day log written by the next puff, and the Plan
    // screen all read through JourneyState.limitOn — one answer, not three.
    expect(c.read(todayProvider)!.limit, curveLimit + 20);
    expect(c.read(quitStoreProvider)!.limitOn(DateTime.now()), curveLimit + 20);
  });

  test("a fresh day's log is created against the advised line", () async {
    final c = await signedIn();
    final store = c.read(quitStoreProvider.notifier);
    // Drop today's log to reproduce the state every user wakes up in: the
    // cron has written a verdict overnight and no puff has been logged yet.
    // The limit logPuff stamps into the new log is what the over-limit test,
    // the streak chain and the slip flow read for the rest of the day.
    final journey = c.read(quitStoreProvider)!;
    store.replaceForTest(
      journey.copyWith(
        days: {...journey.days}..remove(JourneyState.dateKey(DateTime.now())),
      ),
    );
    store.applyPlanAdvice(adviceFor(DateTime.now(), limit: 7));

    store.logPuff();
    expect(c.read(quitStoreProvider)!.logFor(DateTime.now())!.limit, 7);
  });

  test('advice never rewrites a day already logged against the curve', () async {
    final c = await signedIn();
    final store = c.read(quitStoreProvider.notifier);
    final logged = c.read(quitStoreProvider)!.logFor(DateTime.now())!.limit;

    store.applyPlanAdvice(adviceFor(DateTime.now(), limit: 7));
    store.logPuff();

    // The stored log keeps the limit it was opened with — history is not
    // retroactively re-judged — while TodaySnapshot shows the live advice.
    expect(c.read(quitStoreProvider)!.logFor(DateTime.now())!.limit, logged);
    expect(c.read(todayProvider)!.limit, 7);
  });

  test("yesterday's advice is refused — it describes a limit that is gone", () async {
    final c = await signedIn();
    final before = c.read(todayProvider)!.limit;

    c.read(quitStoreProvider.notifier).applyPlanAdvice(
      adviceFor(DateTime.now().subtract(const Duration(days: 1)), limit: 5),
    );

    expect(c.read(todayProvider)!.limit, before);
    expect(c.read(quitStoreProvider)!.planAdvice, isNull);
  });

  test('a stretch applies once, however many times advice is re-read', () async {
    final c = await signedIn();
    final store = c.read(quitStoreProvider.notifier);
    final freedomBefore = c.read(quitStoreProvider)!.plan.freedomDate;

    final advice = adviceFor(DateTime.now(), stretchDelta: 1);
    store.applyPlanAdvice(advice);
    final freedomAfter = c.read(quitStoreProvider)!.plan.freedomDate;
    expect(freedomAfter, freedomBefore.add(const Duration(days: 1)));

    // Every launch re-reads the same document. Re-applying would push Freedom
    // Day back a day per app open — the failure this guard exists for.
    store.applyPlanAdvice(advice);
    store.applyPlanAdvice(advice);
    expect(c.read(quitStoreProvider)!.plan.freedomDate, freedomAfter);
  });

  test('adjusting the plan drops advice built on the old curve', () async {
    final c = await signedIn();
    final store = c.read(quitStoreProvider.notifier);
    store.applyPlanAdvice(adviceFor(DateTime.now(), limit: 91));
    expect(c.read(quitStoreProvider)!.planAdvice, isNotNull);

    store.adjustPlan(paceDays: 60);
    expect(c.read(quitStoreProvider)!.planAdvice, isNull);
  });

  test('pullPlanAdvice folds the server verdict in without being awaited', () async {
    final c = await signedIn();
    stub.advice = adviceFor(DateTime.now(), limit: 42);

    c.read(quitStoreProvider.notifier).pullPlanAdvice();
    // Fire-and-forget: one microtask turn is all the caller ever gives it.
    await Future<void>.delayed(Duration.zero);

    expect(c.read(todayProvider)!.limit, 42);
  });

  test('a failed pull leaves the raw curve standing', () async {
    final c = await signedIn();
    final before = c.read(todayProvider)!.limit;
    stub.failure = const NoConnectionException();

    c.read(quitStoreProvider.notifier).pullPlanAdvice();
    await Future<void>.delayed(Duration.zero);

    expect(c.read(todayProvider)!.limit, before);
  });

  test('signing in pulls the verdict on the way through', () async {
    stub.advice = adviceFor(DateTime.now(), limit: 33);
    final c = await signedIn();
    await Future<void>.delayed(Duration.zero);

    expect(c.read(todayProvider)!.limit, 33);
  });
}

/// Stands in for `users/{uid}`. The fake backend has no such document, so the
/// real seam is overridden rather than simulated.
class _StubServerState implements ServerStateRepository {
  PlanAdvice? advice;
  WeeklyInsight? insight;
  Object? failure;

  @override
  Future<PlanAdvice?> planAdvice() async {
    if (failure != null) throw failure!;
    return advice;
  }

  @override
  Future<WeeklyInsight?> latestInsight() async {
    if (failure != null) throw failure!;
    return insight;
  }
}
