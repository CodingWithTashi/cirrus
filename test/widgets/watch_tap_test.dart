import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/data/api/widget_store.dart';
import 'package:last_puff/data/stores/pending_puffs.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/data/stores/widget_coordinator.dart';
import 'package:last_puff/data/stores/widget_mirror.dart';

import '../helpers.dart';

/// A tap from the wrist while the phone app is already open.
///
/// The outbox used to be drained on resume and on launch only — all a launcher
/// widget needs, since nobody taps one while the app is on screen. A watch can
/// hand the phone a tap between those two moments, and until Sep 8 2026 that
/// tap sat in the outbox: Home said zero, the wrist said one, and closing and
/// reopening the app was what "fixed" it (docs/10 §36). These cases play the
/// native relay the way it really runs — outbox first, signal second — against
/// the real app, with no lifecycle event of any kind.
void main() {
  final now = DateTime(2026, 9, 8, 14, 0);

  Future<(ProviderContainer, MemoryWidgetStore)> open(WidgetTester tester) async {
    final store = MemoryWidgetStore();
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(now: now),
        widgetCoordinatorProvider.overrideWithValue(WidgetCoordinator(store)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    await tester.pumpAndSettle();
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pumpAndSettle();
    return (container, store);
  }

  /// What `CirrusWatchLink` does when a batch lands: append, then announce.
  void relay(MemoryWidgetStore store, {required int seq, required int delta}) {
    final queued = PendingPuffs.decode(store.values[PendingPuffs.outboxKey]);
    store.values[PendingPuffs.outboxKey] = PendingPuffs.encode([
      ...queued,
      PendingPuff(
        id: 'w$seq',
        seq: seq,
        at: now.subtract(const Duration(minutes: 1)),
        delta: delta,
      ),
    ]);
    store.watchTapsController.add(1);
  }

  int puffs(ProviderContainer c) => c.read(todayProvider)!.puffs;

  Map<String, dynamic> mirrorIn(MemoryWidgetStore store) =>
      jsonDecode(store.values[WidgetMirror.key]!) as Map<String, dynamic>;

  testWidgets('reaches Home the moment it lands, with no resume in between', (
    tester,
  ) async {
    final (c, store) = await open(tester);
    final before = puffs(c);
    final syncsBefore = store.watchSyncs;

    relay(store, seq: 1, delta: 1);
    await tester.pumpAndSettle();

    expect(puffs(c), before + 1, reason: 'Home counted the wrist tap');
    expect(store.values[PendingPuffs.cursorKey], '1');
    expect(
      mirrorIn(store)['puffs'],
      before + 1,
      reason: 'the mirror the wrist reads carries the tap as counted',
    );
    expect(
      store.watchSyncs,
      greaterThan(syncsBefore),
      reason: 'and it was pushed back to the wrist, so its pending dot clears',
    );
  });

  testWidgets('a − from the wrist takes one off just as fast', (tester) async {
    final (c, store) = await open(tester);
    final before = puffs(c);
    expect(before, greaterThan(0), reason: 'the demo day has puffs to undo');

    relay(store, seq: 1, delta: -1);
    await tester.pumpAndSettle();

    expect(puffs(c), before - 1);
    expect(store.values[PendingPuffs.cursorKey], '1');
  });

  testWidgets('taps landing back to back each count exactly once', (
    tester,
  ) async {
    final (c, store) = await open(tester);
    final before = puffs(c);

    // Three relays with no pump between them: the second and third arrive
    // while the first drain is in flight, which is exactly the window the
    // coalescing follow-up exists for.
    relay(store, seq: 1, delta: 1);
    relay(store, seq: 2, delta: 1);
    relay(store, seq: 3, delta: 1);
    await tester.pumpAndSettle();

    expect(puffs(c), before + 3);
    expect(store.values[PendingPuffs.cursorKey], '3');
  });

  testWidgets('the signal is what does it — withheld, the tap waits for resume', (
    tester,
  ) async {
    // Documents the two paths rather than one: the announcement is the new
    // one, and the resume drain it sits beside must go on working for a
    // background delivery that had no engine to announce to.
    final (c, store) = await open(tester);
    final before = puffs(c);

    store.values[PendingPuffs.outboxKey] = PendingPuffs.encode([
      PendingPuff(id: 'w1', seq: 1, at: now, delta: 1),
    ]);
    await tester.pumpAndSettle();
    expect(puffs(c), before, reason: 'nothing woke the drain');

    // AppLifecycleListener asserts on a skipped state: walk the whole ladder.
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(puffs(c), before + 1, reason: 'the resume drain still picks it up');
  });
}
