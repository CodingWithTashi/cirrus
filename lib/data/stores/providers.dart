import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/journey_state.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../api/auth_api.dart';
import '../api/coach_api.dart';
import '../api/community_api.dart';
import '../api/fake/fake_auth_api.dart';
import '../api/fake/fake_coach_api.dart';
import '../api/fake/fake_community_api.dart';
import '../api/fake/fake_journey_api.dart';
import '../api/fake/fake_server.dart';
import '../api/journey_api.dart';
import '../backend_mode.dart';
import '../network/connectivity.dart';
import '../repositories/api_auth_repository.dart';
import '../repositories/api_coach_repository.dart';
import '../repositories/api_community_repository.dart';
import '../repositories/api_journey_repository.dart';
import '../repositories/firebase_auth_repository.dart';
import '../api/firebase/reminder_scheduler.dart';
import 'reminder_coordinator.dart';
import '../repositories/firebase_coach_repository.dart';
import '../repositories/firebase_community_repository.dart';
import '../repositories/firebase_journey_repository.dart';
import '../repositories/firebase_moderation_repository.dart';
import '../repositories/firebase_panic_repository.dart';
import '../repositories/firebase_server_state_repository.dart';
import '../repositories/firebase_coach_name_repository.dart';
import '../repositories/firebase_testimonials_repository.dart';
import '../repositories/firebase_user_context_repository.dart';
import 'coach_store.dart';
import 'community_store.dart';
import 'journey_store.dart';
import 'moderation_store.dart';
import 'settings_store.dart';
import '../../domain/date_key.dart';

// ---- backend seam -----------------------------------------------------------
// [backendModeProvider] picks who answers the domain contracts: mobile runs
// the real Firebase repositories (auth + journey), while desktop/web/tests
// stay on the fake JSON backend (LP_BACKEND dart-define overrides; tests pin
// fake via fastBackendOverrides). Community/Coach still answer from the fake
// everywhere — their real implementations slot into the same providers later.
// Nothing above these providers (stores, views) changes.

final backendModeProvider = Provider<BackendMode>((_) => resolveBackendMode());

/// The clock. One seam, so "what does this do at 23:59, or on a DST day" is a
/// test rather than a bug report — the position `ReminderScheduler`'s
/// `@visibleForTesting nextOccurrence(slot, now)` already takes, generalized.
///
/// **Not every `DateTime.now()` belongs here.** Id generation, the panic
/// stopwatch, analytics dwell timing and fixture seeding all read the clock
/// and none of them is a calendar decision; routing them through this would
/// double the diff and buy nothing. This is for the reads that decide what day
/// it is, what the user's plan says today, and whether they are old enough.
final nowProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// Simulated network latency; widget tests override this with Duration.zero.
final apiLatencyProvider = Provider<Duration>(
  (_) => const Duration(milliseconds: 350),
);

final fakeServerProvider = Provider<FakeServer>(
  (ref) => FakeServer(
    latency: ref.watch(apiLatencyProvider),
    // Synchronous read on purpose (sync-apply invariant): when the device is
    // offline the fake backend is unreachable, exactly like a real one.
    isOnline: () => ref.read(connectivityProvider),
  ),
);

final authApiProvider = Provider<AuthApi>(
  (ref) => FakeAuthApi(ref.watch(fakeServerProvider)),
);

final journeyApiProvider = Provider<JourneyApi>(
  (ref) => FakeJourneyApi(ref.watch(fakeServerProvider)),
);

final communityApiProvider = Provider<CommunityApi>(
  (ref) => FakeCommunityApi(ref.watch(fakeServerProvider)),
);

final coachApiProvider = Provider<CoachApi>(
  (ref) => FakeCoachApi(ref.watch(fakeServerProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => switch (ref.watch(backendModeProvider)) {
    BackendMode.fake => ApiAuthRepository(ref.watch(authApiProvider)),
    BackendMode.firebase => FirebaseAuthRepository(),
  },
);

final journeyRepositoryProvider = Provider<JourneyRepository>(
  (ref) => switch (ref.watch(backendModeProvider)) {
    BackendMode.fake => ApiJourneyRepository(ref.watch(journeyApiProvider)),
    BackendMode.firebase => FirebaseJourneyRepository(),
  },
);

/// Device facts for the server-owned user document. Switched like auth and
/// journey — the fake backend has nothing to sync to.
final userContextRepositoryProvider = Provider<UserContextRepository>(
  (ref) => switch (ref.watch(backendModeProvider)) {
    BackendMode.fake => const NoopUserContextRepository(),
    BackendMode.firebase => FirebaseUserContextRepository(),
  },
);

/// What this person calls their coach, or null if they never renamed it.
///
/// Null rather than 'Ember' on purpose: the default is an ARB string, so no
/// brand word is hardcoded in Dart and every read site reads
/// `ref.watch(coachNameProvider) ?? l10n.coachName`. Watched, not read, so a
/// rename in Settings redraws the chat header and the memories screen at once.
final coachNameProvider = Provider<String?>(
  (ref) => ref.watch(quitStoreProvider)?.profile.coachName,
);

/// The validated, server-owned coach name. See [CoachNameRepository].
final coachNameRepositoryProvider = Provider<CoachNameRepository>(
  (ref) => switch (ref.watch(backendModeProvider)) {
    BackendMode.fake => const NoopCoachNameRepository(),
    BackendMode.firebase => FirebaseCoachNameRepository(),
  },
);

/// Tailored beta-tester quotes for the D3 rating ask. The fake backend has no
/// testimonial store, so the screen keeps its bundled quotes — which is also
/// what a real user sees offline, so both paths are exercised daily.
final testimonialsRepositoryProvider = Provider<TestimonialsRepository>(
  (ref) => switch (ref.watch(backendModeProvider)) {
    BackendMode.fake => const NoopTestimonialsRepository(),
    BackendMode.firebase => FirebaseTestimonialsRepository(),
  },
);

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => switch (ref.watch(backendModeProvider)) {
    BackendMode.fake => ApiCommunityRepository(ref.watch(communityApiProvider)),
    BackendMode.firebase => FirebaseCommunityRepository(),
  },
);

/// Craving sessions. The fake backend has no entitlement to read, so it
/// answers "AI available" rather than inventing a quota.
final panicRepositoryProvider = Provider<PanicRepository>(
  (ref) => switch (ref.watch(backendModeProvider)) {
    BackendMode.fake => const NoopPanicRepository(),
    BackendMode.firebase => FirebasePanicRepository(),
  },
);

/// The founder's review queue. Hidden entirely on the fake backend, which
/// has no moderation collection and no auth claims to check.
final moderationRepositoryProvider = Provider<ModerationRepository>(
  (ref) => switch (ref.watch(backendModeProvider)) {
    BackendMode.fake => const NoopModerationRepository(),
    BackendMode.firebase => FirebaseModerationRepository(),
  },
);

/// Whether to show the moderation entry point at all. A UI gate only — the
/// callables check the same claim themselves and answer `not-found` to
/// everyone else.
final isModeratorProvider = FutureProvider<bool>(
  (ref) => ref.watch(moderationRepositoryProvider).isModerator(),
);

/// Read side of the server-owned user document: nightly taper advice and the
/// weekly AI report today, the entitlement mirror next.
final serverStateRepositoryProvider = Provider<ServerStateRepository>(
  (ref) => switch (ref.watch(backendModeProvider)) {
    BackendMode.fake => const NoopServerStateRepository(),
    BackendMode.firebase => FirebaseServerStateRepository(),
  },
);

final coachRepositoryProvider = Provider<CoachRepository>(
  (ref) => switch (ref.watch(backendModeProvider)) {
    BackendMode.fake => ApiCoachRepository(ref.watch(coachApiProvider)),
    BackendMode.firebase => FirebaseCoachRepository(),
  },
);

// ---- view-model layer -------------------------------------------------------
// Composition root of the stores. Views read state through these providers
// and issue commands through the `.notifier`.

final quitStoreProvider = NotifierProvider<JourneyStore, JourneyState?>(
  JourneyStore.new,
);

/// Today's date, as a local midnight, ticked over when the day actually turns.
///
/// Exists because `todayProvider` used to recompute only when the journey
/// mutated, so an app left open overnight showed yesterday's day number, limit
/// and streak until the user happened to tap something.
///
/// The timer targets the next CALENDAR midnight via [LpDate.addDays], never
/// `Timer.periodic(Duration(days: 1))` — the latter drifts an hour every DST
/// change, which is the same class of bug that used to zero the streak.
class DayClock extends Notifier<DateTime> {
  /// Tests pin this off, the way `SettingsStore({restore})` is pinned off:
  /// a live timer in a provider fails every widget test with a pending timer.
  DayClock({bool tick = true}) : _tick = tick;

  final bool _tick;
  Timer? _timer;

  @override
  DateTime build() {
    ref.onDispose(() => _timer?.cancel());
    if (_tick) _schedule();
    return LpDate.dayStart(ref.read(nowProvider)());
  }

  void _schedule() {
    final now = ref.read(nowProvider)();
    final next = LpDate.addDays(LpDate.dayStart(now), 1);
    // A second past midnight, so a clock that fires marginally early does not
    // land back on the day it just left.
    _timer = Timer(next.difference(now) + const Duration(seconds: 1), () {
      state = LpDate.dayStart(ref.read(nowProvider)());
      _schedule();
    });
  }

  /// Called on app resume. A process Android froze overnight has timers that
  /// fire late or not at all, so the timer alone is not enough.
  void refresh() {
    _timer?.cancel();
    state = LpDate.dayStart(ref.read(nowProvider)());
    if (_tick) _schedule();
  }
}

final dayClockProvider = NotifierProvider<DayClock, DateTime>(DayClock.new);

/// Derived, recomputed on every journey mutation AND when the day turns.
final todayProvider = Provider<TodaySnapshot?>((ref) {
  final journey = ref.watch(quitStoreProvider);
  // Watched for the dependency, not the value: it is what makes an app left
  // open overnight stop showing yesterday.
  ref.watch(dayClockProvider);
  return journey == null
      ? null
      : TodaySnapshot.of(journey, ref.watch(nowProvider)());
});

final communityStoreProvider = NotifierProvider<CommunityStore, CommunityState>(
  CommunityStore.new,
);

final coachStoreProvider = NotifierProvider<CoachStore, CoachState>(
  CoachStore.new,
);

/// Keeps the device notification schedule in step with the journey. Only the
/// real backend schedules anything — the fake one has no device to talk to
/// and tests must not touch the platform channel.
final reminderCoordinatorProvider = Provider<ReminderCoordinator?>(
  (ref) => switch (ref.watch(backendModeProvider)) {
    BackendMode.fake => null,
    BackendMode.firebase => ReminderCoordinator(ReminderScheduler()),
  },
);

/// The most recent weekly AI report, or null when the cron has not produced
/// one (free tier, a short week, a skipped model outage, or the fake backend).
///
/// A `FutureProvider` rather than store state: it is read by exactly one
/// screen, it is never mutated, and `ref.invalidate` is the whole refresh
/// story. Auto-disposal keeps it from pinning a stale week in memory for a
/// session that stays open past Sunday.
final weeklyInsightProvider = FutureProvider.autoDispose<WeeklyInsight?>(
  (ref) => ref.watch(serverStateRepositoryProvider).latestInsight(),
);

final moderationStoreProvider =
    NotifierProvider.autoDispose<ModerationStore, ModerationState>(
      ModerationStore.new,
    );

/// What Ember remembers about this user.
///
/// Auto-disposed and re-fetched on open rather than cached in a store: it is
/// read by one screen, invalidated by exactly one action (forgetting), and a
/// stale list here would show someone a disclosure they had already deleted.
final coachMemoriesProvider = FutureProvider.autoDispose<List<CoachMemory>>(
  (ref) => ref.watch(coachRepositoryProvider).memories(),
);

final settingsStoreProvider = NotifierProvider<SettingsStore, SettingsState>(
  SettingsStore.new,
);
