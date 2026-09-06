import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener, WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Answers "can we reach the internet right now?". Injectable so tests and
/// future platforms can stub it.
typedef ConnectivityProbe = Future<bool> Function();

/// Default probe: a DNS lookup against two independent resolvers' hostnames,
/// in parallel — the first to answer wins, and only both failing counts as a
/// failure. Cheap, dependency-free, and instant in airplane mode (no route,
/// so the lookups fail at once rather than waiting out the timeout).
///
/// Two hosts because one resolver being slow or blocked on a network is a
/// fact about that resolver, not about the connection.
Future<bool> dnsConnectivityProbe() =>
    _anyResolves(const ['one.one.one.one', 'dns.google'], _probeTimeout);

const Duration _probeTimeout = Duration(seconds: 3);

Future<bool> _anyResolves(List<String> hosts, Duration timeout) {
  final completer = Completer<bool>();
  var pending = hosts.length;
  for (final host in hosts) {
    // `then<void>` with its own `onError`, not `catchError`: a `catchError`
    // handler has to return a `List<InternetAddress>`, and one that returns
    // nothing completes the chain with a TypeError that escapes as an
    // unhandled async error on every failed lookup.
    InternetAddress.lookup(host)
        .then<void>((addresses) {
          if (addresses.isNotEmpty && !completer.isCompleted) {
            completer.complete(true);
          }
        }, onError: (Object _) {})
        .whenComplete(() {
          if (--pending == 0 && !completer.isCompleted) {
            completer.complete(false);
          }
        });
  }
  return completer.future.timeout(timeout, onTimeout: () => false);
}

/// The probe the store polls with. Override in tests.
final connectivityProbeProvider = Provider<ConnectivityProbe>(
  (_) => dnsConnectivityProbe,
);

/// The OS's own word on whether any network interface is up — `true` when
/// some transport exists (wifi, cellular, ethernet, VPN…), `false` when none
/// does. Event-driven, so airplane mode is known the instant it is switched
/// on, with no probe to wait for. Null means "no such signal here": the
/// store then relies on the probe alone.
///
/// A transport is not the internet — a wifi with no uplink still reports
/// `true` — which is why this only ever *disqualifies* a connection. The
/// probe is what qualifies one.
final connectivityTransportProvider = Provider<Stream<bool>?>((_) {
  try {
    return Connectivity().onConnectivityChanged.map(_hasTransport);
  } on Object {
    // A platform without the plugin (or a test binding without channels):
    // the probe alone decides, exactly as before the signal existed.
    return null;
  }
});

bool _hasTransport(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

/// How often to re-probe while the app is in the foreground. Override with
/// null in widget tests: the store then never polls, never subscribes to the
/// OS and never touches the lifecycle (no pending timers, no real DNS), and
/// stays online.
///
/// Ten seconds rather than the five it used to be: the OS transport stream
/// now catches the common changes the instant they happen, so the poll only
/// has to notice the rare "connected to a wifi that goes nowhere".
final connectivityPollIntervalProvider = Provider<Duration?>(
  (_) => const Duration(seconds: 10),
);

/// Live device connectivity, `true` = online. Optimistic on first frame (no
/// offline flash at launch), then kept honest by three signals: the OS
/// transport stream, a reachability probe, and the app lifecycle.
///
/// **A single failed probe never flips it.** The banner used to appear on
/// every unlock and on most cold starts with the wifi icon lit in the status
/// bar — the first lookup after resume runs while the radio is still waking
/// and fails for a reason that has nothing to do with connectivity; the next
/// poll five seconds later passed and the pill slid away again. Now going
/// offline takes either the OS saying there is no interface at all (held for
/// [transportLossGrace], because a wifi→cellular handover reports `none` for
/// a moment in between) or [failuresToGoOffline] straight probe failures,
/// re-asked [retryDelay] apart. Coming back online takes one success, and it
/// is asked for the moment a transport appears or the app resumes — never
/// left to the next poll.
///
/// The state is read *synchronously* by the fake backend before every call —
/// that keeps the FakeServer's sync-apply invariant intact (no async gap
/// between the connectivity gate and the mutation).
class ConnectivityStore extends Notifier<bool> {
  /// Consecutive probe failures, with a transport up, before "offline".
  static const int failuresToGoOffline = 3;

  /// How soon a failed probe is re-asked while the count is still short.
  static const Duration retryDelay = Duration(milliseconds: 1500);

  /// How long the OS's `none` must hold before it counts. Real airplane mode
  /// shows the pill this much later; a handover never shows it at all.
  static const Duration transportLossGrace = Duration(milliseconds: 1200);

  /// The beat between an interface appearing and asking whether it reaches
  /// anything: DHCP and the resolver need a moment after the OS says "up".
  static const Duration transportSettle = Duration(milliseconds: 600);

  /// The beat after resume before the first probe, for the same reason.
  static const Duration resumeGrace = Duration(milliseconds: 800);

  late ConnectivityProbe _probe;
  Duration? _interval;
  bool _alive = false;
  Timer? _poll;
  Timer? _pending;
  StreamSubscription<bool>? _transport;
  AppLifecycleListener? _lifecycle;

  /// Straight probe failures since the last success or reset.
  int _failures = 0;

  /// Bumped on every transport event, resume and background: a probe that
  /// was in flight across one of those answered a question about a world
  /// that no longer exists, and its answer is dropped.
  int _generation = 0;

  /// The OS's last word. Optimistic until it speaks.
  bool _hasTransport = true;

  @override
  bool build() {
    _probe = ref.watch(connectivityProbeProvider);
    _interval = ref.watch(connectivityPollIntervalProvider);
    _alive = true;
    ref.onDispose(() {
      _alive = false;
      _poll?.cancel();
      _pending?.cancel();
      _transport?.cancel().ignore();
      _lifecycle?.dispose();
    });
    if (_interval != null) {
      // The two OS signals need a Flutter binding: the transport stream is
      // an event channel and the listener registers with `WidgetsBinding`.
      // A plain `test()` that wires the fake backend without
      // `fastBackendOverrides()` has neither, and an event channel touched
      // without a binding fails inside an async `onListen`/`onCancel` whose
      // future the broadcast controller discards — an uncaught error no
      // try/catch here can reach. So: no binding, no subscription, and the
      // probe alone decides, exactly as before the signals existed.
      if (_hasBinding()) {
        _transport = ref
            .watch(connectivityTransportProvider)
            ?.listen(_onTransport, onError: (Object _) {});
        _lifecycle = AppLifecycleListener(
          onResume: _onResume,
          onHide: _onBackground,
        );
      }
      _startPolling();
      unawaited(refresh());
    }
    return true;
  }

  /// Whether `WidgetsFlutterBinding.ensureInitialized()` has run. The getter
  /// throws until it has (a `FlutterError` in debug, a null check in
  /// release), and that is the only way to ask without initialising one.
  static bool _hasBinding() {
    try {
      // ignore: unnecessary_statements
      WidgetsBinding.instance;
      return true;
    } on Object {
      return false;
    }
  }

  /// Re-probes now. One success is enough to come back online, so a retry
  /// button gets its answer without waiting for the next poll; a failure
  /// counts toward the threshold like any other.
  Future<void> refresh() async {
    // Inert when disabled (tests, `fastBackendOverrides`): no DNS, ever.
    if (!_alive || _interval == null) return;
    final generation = _generation;
    final online = await _probe();
    if (!_alive || generation != _generation) return;
    if (online) {
      _failures = 0;
      _set(true);
      return;
    }
    if (!_hasTransport) {
      // The OS already said why, and its verdict is on the handover grace
      // timer. A poll that happens to fail inside that window must not jump
      // the gun, or one handover in eight would still flash the pill.
      return;
    }
    _failures++;
    if (_failures >= failuresToGoOffline) {
      _set(false);
      return;
    }
    // Ask again soon rather than at the next poll: one failed lookup is what
    // a waking radio looks like, not what offline looks like.
    _schedule(retryDelay, refresh);
  }

  void _onTransport(bool hasTransport) {
    if (!_alive) return;
    _hasTransport = hasTransport;
    _generation++;
    _pending?.cancel();
    if (!hasTransport) {
      // Provisional: a handover reports `none` between the two networks.
      _schedule(transportLossGrace, () {
        if (_hasTransport) return;
        _failures = failuresToGoOffline;
        _set(false);
      });
      return;
    }
    // An interface came up. Whether it reaches anything is the probe's call,
    // made after a beat — and made now, not at the next poll, so a restored
    // connection is noticed in under a second.
    _failures = 0;
    _schedule(transportSettle, refresh);
  }

  void _onResume() {
    if (!_alive) return;
    _generation++;
    _failures = 0;
    _pending?.cancel();
    _startPolling();
    _schedule(resumeGrace, refresh);
  }

  /// Backgrounded: nothing on screen can show the answer, so stop asking.
  /// A probe already in flight is dropped too — its answer belongs to the
  /// moment the app was being put away.
  void _onBackground() {
    if (!_alive) return;
    _generation++;
    _poll?.cancel();
    _poll = null;
    _pending?.cancel();
    _pending = null;
  }

  void _startPolling() {
    _poll?.cancel();
    final interval = _interval;
    if (interval == null) return;
    _poll = Timer.periodic(interval, (_) => refresh());
  }

  /// One follow-up at a time: a newer reason to ask replaces an older one.
  void _schedule(Duration after, void Function() action) {
    _pending?.cancel();
    _pending = Timer(after, () {
      _pending = null;
      if (_alive) action();
    });
  }

  void _set(bool online) {
    if (_alive && online != state) state = online;
  }
}

final connectivityProvider = NotifierProvider<ConnectivityStore, bool>(
  ConnectivityStore.new,
);
