import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/journey_state.dart';
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
import '../repositories/firebase_journey_repository.dart';
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

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => ApiCommunityRepository(ref.watch(communityApiProvider)),
);

final coachRepositoryProvider = Provider<CoachRepository>(
  (ref) => ApiCoachRepository(ref.watch(coachApiProvider)),
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

final settingsStoreProvider = NotifierProvider<SettingsStore, SettingsState>(
  SettingsStore.new,
);
