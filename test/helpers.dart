import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:last_puff/data/network/connectivity.dart';
import 'package:last_puff/data/stores/providers.dart';

/// Standard test overrides for anything that pumps the app or wires the fake
/// backend: instant fake network + no connectivity polling (no pending
/// timers, no real DNS lookups). Pass `online: false` to simulate airplane
/// mode — every backend call then throws [NoConnectionException].
List<Override> fastBackendOverrides({bool online = true}) => [
  apiLatencyProvider.overrideWithValue(Duration.zero),
  connectivityPollIntervalProvider.overrideWithValue(null),
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
