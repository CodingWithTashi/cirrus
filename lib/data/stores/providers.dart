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
import '../repositories/firebase_panic_repository.dart';
import '../repositories/firebase_server_state_repository.dart';
import '../repositories/firebase_user_context_repository.dart';
import 'coach_store.dart';
import 'community_store.dart';
import 'journey_store.dart';
import 'settings_store.dart';

// ---- backend seam -----------------------------------------------------------
// [backendModeProvider] picks who answers the domain contracts: mobile runs
// the real Firebase repositories (auth + journey), while desktop/web/tests
// stay on the fake JSON backend (LP_BACKEND dart-define overrides; tests pin
// fake via fastBackendOverrides). Community/Coach still answer from the fake
// everywhere — their real implementations slot into the same providers later.
// Nothing above these providers (stores, views) changes.

final backendModeProvider = Provider<BackendMode>((_) => resolveBackendMode());

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

/// Derived, recomputed on every journey mutation.
final todayProvider = Provider<TodaySnapshot?>((ref) {
  final journey = ref.watch(quitStoreProvider);
  return journey == null ? null : TodaySnapshot.of(journey, DateTime.now());
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

final settingsStoreProvider = NotifierProvider<SettingsStore, SettingsState>(
  SettingsStore.new,
);
