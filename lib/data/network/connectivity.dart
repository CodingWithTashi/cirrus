import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Answers "can we reach the internet right now?". Injectable so tests and
/// future platforms can stub it.
typedef ConnectivityProbe = Future<bool> Function();

/// Default probe: one DNS lookup against Cloudflare's resolver hostname.
/// Cheap, dependency-free, and fails fast in airplane mode.
Future<bool> dnsConnectivityProbe() async {
  try {
    final result = await InternetAddress.lookup(
      'one.one.one.one',
    ).timeout(const Duration(seconds: 3));
    return result.isNotEmpty;
  } on Object {
    return false;
  }
}

/// The probe the store polls with. Override in tests.
final connectivityProbeProvider = Provider<ConnectivityProbe>(
  (_) => dnsConnectivityProbe,
);

/// How often to re-probe. Override with null in widget tests: the store then
/// never polls (no pending timers, no real DNS) and stays online.
final connectivityPollIntervalProvider = Provider<Duration?>(
  (_) => const Duration(seconds: 5),
);

/// Live device connectivity, `true` = online. Optimistic on first frame (no
/// offline flash at launch), then kept fresh by a periodic probe.
///
/// The state is read *synchronously* by the fake backend before every call —
/// that keeps the FakeServer's sync-apply invariant intact (no async gap
/// between the connectivity gate and the mutation).
class ConnectivityStore extends Notifier<bool> {
  late ConnectivityProbe _probe;
  bool _alive = false;

  @override
  bool build() {
    _probe = ref.watch(connectivityProbeProvider);
    _alive = true;
    ref.onDispose(() => _alive = false);
    final interval = ref.watch(connectivityPollIntervalProvider);
    if (interval != null) {
      final timer = Timer.periodic(interval, (_) => refresh());
      ref.onDispose(timer.cancel);
      unawaited(refresh());
    }
    return true;
  }

  /// Re-probes immediately — retry buttons call this so a fixed connection
  /// is noticed without waiting for the next poll tick.
  Future<void> refresh() async {
    final online = await _probe();
    if (_alive && online != state) state = online;
  }
}

final connectivityProvider = NotifierProvider<ConnectivityStore, bool>(
  ConnectivityStore.new,
);
