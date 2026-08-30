import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:last_puff/data/backend_mode.dart';
import 'package:last_puff/data/network/connectivity.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/analytics/analytics.dart';
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
///
/// Pass [analytics] to capture the events a flow emits; without it the pinned
/// fake backend already resolves the seam to `NoopAnalytics`, so no vendor SDK
/// is ever constructed under `flutter test`.
List<Override> fastBackendOverrides({
  bool online = true,
  DateTime? now,
  AnalyticsSink? analytics,
}) => [
  if (analytics != null) analyticsProvider.overrideWithValue(analytics),
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

/// An [AnalyticsSink] that sends nothing and remembers everything, so a test
/// can assert on the funnel a flow actually emits. The static class this seam
/// replaced could not be observed at all.
class RecordingAnalytics implements AnalyticsSink {
  final List<AnalyticsEvent> events = [];
  final List<String> screens = [];
  final List<String> identified = [];
  int resets = 0;

  /// Event names in order — what most assertions actually want.
  List<String> get names => [for (final e in events) e.name];

  Map<String, Object>? propsOf(String name) {
    for (final e in events) {
      if (e.name == name) return e.props;
    }
    return null;
  }

  @override
  void track(AnalyticsEvent event) => events.add(event);

  @override
  void screenViewed(String name) => screens.add(name);

  @override
  void identify(String userId) => identified.add(userId);

  @override
  void reset() => resets++;
}
