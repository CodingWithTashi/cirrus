import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:last_puff/data/backend_mode.dart';
import 'package:last_puff/data/network/connectivity.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/data/stores/settings_store.dart';
import 'package:last_puff/features/onboarding/onboarding_view_model.dart';

/// Standard test overrides for anything that pumps the app or wires the fake
/// backend: pinned to the fake backend (the test platform reports android,
/// which would otherwise select Firebase), instant fake network + no
/// connectivity polling (no pending timers, no real DNS lookups). Pass
/// `online: false` to simulate airplane mode — every backend call then
/// throws [NoConnectionException].
///
/// Settings restore is off: tests assert against the documented defaults, not
/// against whatever the host machine's shared_preferences last held.
List<Override> fastBackendOverrides({bool online = true, DateTime? now}) => [
  backendModeProvider.overrideWithValue(BackendMode.fake),
  apiLatencyProvider.overrideWithValue(Duration.zero),
  connectivityPollIntervalProvider.overrideWithValue(null),
  settingsStoreProvider.overrideWith(() => SettingsStore(restore: false)),
  // Same reason as settings: assert against the documented defaults, not
  // against whatever draft the host machine's shared_preferences last held.
  onboardingProvider.overrideWith(() => OnboardingViewModel(restore: false)),
  // Without this every widget test fails on a pending timer.
  dayClockProvider.overrideWith(() => DayClock(tick: false)),
  if (now != null) nowProvider.overrideWithValue(() => now),
  if (!online) connectivityProvider.overrideWith(ToggleConnectivity.new),
];

/// Starts offline; tests flip it with `set(true)` to simulate the connection
/// coming back (retry-path coverage).
class ToggleConnectivity extends ConnectivityStore {
  @override
  bool build() => false;

  // ignore: use_setters_to_change_properties
  void set(bool online) => state = online;
}
