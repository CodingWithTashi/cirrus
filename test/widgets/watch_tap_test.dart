import 'dart:async';
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

  Future<(ProviderContainer, MemoryWidgetStore)> open(
    WidgetTester tester, {
    MemoryWidgetStore? store,
  }) async {
    store ??= MemoryWidgetStore();
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

  testWidgets('taps landing while a drain is in flight are not left behind', (
    tester,
  ) async {
    // The first drain has already taken its snapshot of the outbox when the
    // second and third taps are relayed in — the window the coalescing
    // follow-up exists for. The store is gated so that this test really puts
    // them there, rather than letting one drain quietly see all three.
    final store = _GatedStore();
    final (c, _) = await open(tester, store: store);
    final before = puffs(c);

    relay(store, seq: 1, delta: 1);
    await tester.pump();
    expect(
      store.outboxRead.isCompleted,
      isTrue,
      reason: 'the first drain is parked on the outbox it has already read',
    );
    relay(store, seq: 2, delta: 1);
    relay(store, seq: 3, delta: 1);
    store.release.complete();
    await tester.pumpAndSettle();

    expect(puffs(c), before + 3);
    expect(store.values[PendingPuffs.cursorKey], '3');
    // And exactly one mirror went to the wrist per drain, after its cursor —
    // never one carrying a count the cursor did not yet cover.
    expect(mirrorIn(store)['puffs'], before + 3);
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

/// Holds the first read of the outbox until the test lets it go, so taps can
/// land AFTER a drain has taken its snapshot — the window a wrist tap lands in.
class _GatedStore extends MemoryWidgetStore {
  final Completer<void> outboxRead = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  Future<String?> read(String key) async {
    if (key == PendingPuffs.outboxKey && !outboxRead.isCompleted) {
      final snapshot = values[key];
      outboxRead.complete();
      await release.future;
      return snapshot;
    }
    return values[key];
  }
}
