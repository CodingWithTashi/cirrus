import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/journey_state.dart';
import 'coach_store.dart';
import 'community_store.dart';
import 'journey_store.dart';
import 'settings_store.dart';

/// Composition root of the data layer. Views read state through these
/// providers and issue commands through the `.notifier` (typed against the
/// domain repository interfaces).
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
