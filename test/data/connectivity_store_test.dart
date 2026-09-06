import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/network/connectivity.dart';

/// The offline pill used to appear on most unlocks and cold starts with the
/// wifi icon lit: one DNS lookup, fired while the radio was still waking,
/// failed, and a single failure was the whole verdict. These pin the rules
/// that replaced it — the OS transport stream disqualifies, the probe
/// qualifies, a lone failure is re-asked rather than believed, and the app
/// stops asking altogether while it is not on screen.
void main() {
  /// Scripted probe answers, consumed in order; `true` once they run out.
  late List<bool> answers;
  late int probes;
  late StreamController<bool> transport;

  /// A hand-completed answer for the one test about an answer in flight.
  Completer<bool>? held;

  /// Set by [finish]. A test that fails before reaching it must still tear
  /// its store down, or the leaked store keeps answering lifecycle events —
  /// and counting probes — during the tests after it.
  late bool finished;

  setUp(() {
    answers = [];
    probes = 0;
    held = null;
    finished = false;
    transport = StreamController<bool>.broadcast();
  });

  ProviderContainer mount({
    Duration? interval = const Duration(seconds: 10),
    bool transportSignal = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        connectivityProbeProvider.overrideWithValue(() {
          probes++;
          final gate = held;
          if (gate != null) {
            held = null;
            return gate.future;
          }
          return Future.value(answers.isEmpty ? true : answers.removeAt(0));
        }),
        connectivityPollIntervalProvider.overrideWithValue(interval),
        connectivityTransportProvider.overrideWithValue(
          transportSignal ? transport.stream : null,
        ),
      ],
    );
    // Kept alive the way the app keeps it: the banner watches it.
    container.listen(connectivityProvider, (_, _) {});
    addTearDown(() {
      if (!finished) container.dispose();
    });
    return container;
  }

  /// Disposed inside the test body, not only in the tearDown above:
  /// flutter_test checks for pending timers before tearDowns run, and the
  /// store owns a periodic one until it is disposed.
  Future<void> finish(WidgetTester tester, ProviderContainer c) async {
    finished = true;
    c.dispose();
    await transport.close();
    await tester.pump();
  }

  bool online(ProviderContainer c) => c.read(connectivityProvider);

  testWidgets('starts online, and one failed probe does not change that', (
    tester,
  ) async {
    answers = [false, true];
    final c = mount();
    await tester.pump();
    expect(online(c), isTrue, reason: 'optimistic on the first frame');
    expect(probes, 1);

    // Re-asked soon, not believed: the second answer is the verdict.
    await tester.pump(ConnectivityStore.retryDelay);
    expect(probes, 2);
    expect(online(c), isTrue);
    await finish(tester, c);
  });

  testWidgets('three straight failures are offline; one success is back', (
    tester,
  ) async {
    answers = [false, false, false, true];
    final c = mount();
    await tester.pump();
    await tester.pump(ConnectivityStore.retryDelay);
    expect(online(c), isTrue, reason: 'two failures are still not a verdict');
    await tester.pump(ConnectivityStore.retryDelay);
    expect(online(c), isFalse);
    expect(probes, 3);

    // Offline, the chain stops: no tight loop of re-asks, only the poll.
    await tester.pump(ConnectivityStore.retryDelay * 3);
    expect(probes, 3);

    // A retry button asks now and one yes is enough.
    await c.read(connectivityProvider.notifier).refresh();
    expect(online(c), isTrue);
    await finish(tester, c);
  });

  testWidgets('the OS saying "no interface" is offline after a beat, and an '
      'interface coming back is verified, not assumed', (tester) async {
    final c = mount();
    await tester.pump();
    expect(probes, 1);

    transport.add(false);
    await tester.pump();
    expect(online(c), isTrue, reason: 'held for the handover grace');
    await tester.pump(ConnectivityStore.transportLossGrace);
    expect(online(c), isFalse);
    expect(probes, 1, reason: 'no probe needed to know there is no network');

    transport.add(true);
    await tester.pump();
    expect(online(c), isFalse, reason: 'an interface is not the internet');
    await tester.pump(ConnectivityStore.transportSettle);
    expect(probes, 2, reason: 'asked the moment it settled, not next poll');
    expect(online(c), isTrue);
    await finish(tester, c);
  });

  testWidgets('a wifi-to-cellular handover never shows the pill', (
    tester,
  ) async {
    final c = mount();
    await tester.pump();

    transport.add(false);
    await tester.pump(const Duration(milliseconds: 300));
    transport.add(true);
    await tester.pump(ConnectivityStore.transportLossGrace);
    expect(online(c), isTrue);
    await tester.pump(const Duration(seconds: 5));
    expect(online(c), isTrue);
    await finish(tester, c);
  });

  testWidgets('a probe answered across a transport change is discarded', (
    tester,
  ) async {
    final gate = Completer<bool>();
    held = gate;
    final c = mount();
    await tester.pump();
    expect(probes, 1, reason: 'the first probe is in flight');

    // The world changed under it: a new interface came up.
    transport.add(true);
    await tester.pump();
    // Its answer arrives late and says no. That was about the old world.
    gate.complete(false);
    answers = [false, false];
    await tester.pump(ConnectivityStore.transportSettle);
    await tester.pump(ConnectivityStore.retryDelay);
    // Two genuine failures since the change; had the stale one counted, this
    // would be the third and the pill would be up.
    expect(probes, 3);
    expect(online(c), isTrue);
    await finish(tester, c);
  });

  testWidgets('backgrounded it stops asking; resumed it re-checks after a '
      'grace, and a lone failure there is still not a verdict', (
    tester,
  ) async {
    final c = mount();
    await tester.pump();
    expect(probes, 1);

    // `AppLifecycleListener` asserts on a skipped state: walk every step.
    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 1));
    expect(probes, 1, reason: 'nothing on screen can show the answer');

    // Unlock. The first lookup fails the way a waking radio does.
    answers = [false, true];
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(probes, 1, reason: 'not before the grace');
    await tester.pump(ConnectivityStore.resumeGrace);
    expect(probes, 2);
    expect(online(c), isTrue);
    await tester.pump(ConnectivityStore.retryDelay);
    expect(probes, 3);
    expect(online(c), isTrue);
    await finish(tester, c);
  });

  testWidgets('a poll that fails inside the handover grace does not jump '
      'the gun', (tester) async {
    // The OS says "none" for a moment between two networks; the grace timer
    // owns that verdict. A poll landing in the window fails (no interface)
    // and used to flip the state on its own — one handover in eight flashed.
    final c = mount();
    await tester.pump();
    transport.add(false);
    await tester.pump();
    answers = [false];
    await c.read(connectivityProvider.notifier).refresh();
    expect(online(c), isTrue, reason: 'the grace has not run out');
    transport.add(true);
    await tester.pump(ConnectivityStore.transportLossGrace);
    expect(online(c), isTrue, reason: 'the handover completed inside it');
    await tester.pump(ConnectivityStore.transportSettle);
    expect(online(c), isTrue);
    await finish(tester, c);
  });

  testWidgets('polls on the interval while in the foreground', (tester) async {
    final c = mount();
    await tester.pump();
    expect(probes, 1);
    await tester.pump(const Duration(seconds: 10));
    expect(probes, 2);
    await tester.pump(const Duration(seconds: 10));
    expect(probes, 3);
    await finish(tester, c);
  });

  testWidgets('with no transport signal the probe alone decides', (
    tester,
  ) async {
    answers = [false, false, false];
    final c = mount(transportSignal: false);
    await tester.pump();
    await tester.pump(ConnectivityStore.retryDelay);
    await tester.pump(ConnectivityStore.retryDelay);
    expect(online(c), isFalse);
    await finish(tester, c);
  });

  testWidgets('a null interval keeps the store silent and online', (
    tester,
  ) async {
    // What `fastBackendOverrides()` relies on: no probe, no OS subscription,
    // no lifecycle listener, no timers.
    answers = [false, false, false];
    final c = mount(interval: null);
    await tester.pump();
    transport.add(false);
    await tester.pump(const Duration(minutes: 1));
    expect(probes, 0);
    expect(online(c), isTrue);
    await c.read(connectivityProvider.notifier).refresh();
    expect(probes, 0, reason: 'refresh is inert when the store is disabled');
    await finish(tester, c);
  });
}
