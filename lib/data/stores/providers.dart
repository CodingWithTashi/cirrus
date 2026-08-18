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
import '../network/connectivity.dart';
import '../repositories/api_auth_repository.dart';
import '../repositories/api_coach_repository.dart';
import '../repositories/api_community_repository.dart';
import '../repositories/api_journey_repository.dart';
import 'coach_store.dart';
import 'community_store.dart';
import 'journey_store.dart';
import 'settings_store.dart';

// ---- backend seam -----------------------------------------------------------
// This block is the swap point for a real backend:
//  * REST: replace the Fake*Api bodies with an http client — same Api
//    interfaces, same JSON.
//  * Firebase: replace either the Api bodies (Firestore/Auth adapters) or the
//    Api*Repository bodies — same domain contracts.
// Nothing above these providers (stores, views) changes.

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
  (ref) => ApiAuthRepository(ref.watch(authApiProvider)),
);

final journeyRepositoryProvider = Provider<JourneyRepository>(
  (ref) => ApiJourneyRepository(ref.watch(journeyApiProvider)),
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
