import 'dart:convert';

import '../../domain/date_key.dart';
import '../api/widget_store.dart';
import 'journey_store.dart';
import 'pending_puffs.dart';
import 'widget_mirror.dart';

/// Keeps the home-screen widget and the journey in step, both ways.
///
/// Two jobs that share one store and therefore one owner:
///
/// * **out** — push the mirror the widget renders from, and only when
///   something the widget actually shows has changed;
/// * **in** — drain the puffs it logged while the app was closed.
///
/// Renders nothing and holds no Riverpod state. It is the direct analogue of
/// [ReminderCoordinator], including the discipline that matters most in both:
/// the important behaviour is the one that does *nothing*. `todayProvider`
/// recomputes on every journey mutation, so a heavy logging day would
/// otherwise cross a platform channel and ask the OS to redraw the widget a
/// hundred times — which is exactly the `reloadTimelines` spam `docs/03 §10`
/// warns against.
class WidgetCoordinator {
  WidgetCoordinator(this._store);

  final WidgetStore _store;

  /// The last mirror actually pushed. Unchanged ⇒ no channel call, no redraw.
  String? _pushed;

  /// One drain at a time. A resume racing a foreground widget tap would
  /// otherwise run two drains over the same events, and both would read the
  /// cursor before either had written it — which is precisely how a puff gets
  /// counted twice.
  Future<void>? _inFlight;

  /// The day the midnight repaints were last armed for.
  String? _armedFor;

  Future<void> push(
    Map<String, dynamic> mirror, {
    required DateTime now,
  }) async {
    final encoded = jsonEncode(mirror);
    if (encoded == _pushed) return;
    _pushed = encoded;
    await _store.write(WidgetMirror.key, encoded);
    await _store.refresh();

    // Re-arm the midnight repaints once a day, not on every puff.
    //
    // While the app runs, `dayClockProvider` turns the day over and this push
    // follows it. While it does not, nothing else would: the day number and
    // the count both change at local midnight, and a widget only repaints when
    // something asks it to. These alarms are what ask.
    //
    // Recomputed daily rather than scheduled once, because the plugin stores
    // absolute instants and does not track wall-clock time across a DST or
    // timezone change — recomputing every day means the drift can never be
    // more than the one day.
    final dayKey = mirror['dayKey'] as String?;
    if (dayKey != null && dayKey != _armedFor) {
      _armedFor = dayKey;
      final today = LpDate.dayStart(now);
      await _store.scheduleRepaints([
        for (var i = 1; i <= kMirrorRepaintDays; i++)
          LpDate.addDays(today, i).add(const Duration(seconds: 5)),
      ]);
    }
  }

  /// Applies everything the widget queued above the cursor.
  ///
  /// Returns how many events landed, so a caller can tell whether the mirror
  /// is now stale and worth re-pushing.
  Future<int> drain(JourneyStore journeys, {required DateTime now}) {
    final running = _inFlight;
    if (running != null) return running.then((_) => 0);
    final task = _drain(journeys, now);
    _inFlight = task.whenComplete(() => _inFlight = null);
    return task;
  }

  Future<int> _drain(JourneyStore journeys, DateTime now) async {
    // No journey means no day map to apply anything to. The queue keeps until
    // there is one: a puff logged before `restoreSession` finishes is not
    // lost, it is early.
    if (journeys.journey == null) return 0;

    final cursor = await _readCursor();
    final events = PendingPuffs.pending(
      PendingPuffs.decode(await _store.read(PendingPuffs.outboxKey)),
      cursor,
    );
    if (events.isEmpty) return 0;

    final highest = await journeys.applyPendingPuffs(events, now: now);
    // Zero means the backend refused the write outright, so those puffs live
    // only in memory. Leaving the cursor where it is keeps them queued for the
    // next drain rather than losing them to a cold start.
    if (highest <= cursor) return 0;

    // KNOWN, NARROW, AND DELIBERATELY NOT "FIXED": there is a window between
    // the journey write becoming durable and this cursor landing. Firestore
    // queues the mutation the moment `set()` is called, and
    // `applyPendingPuffs` then waits up to `widgetFlushTimeout` for the ack —
    // so a process death inside that wait replays these events onto a journey
    // that already has them.
    //
    // Advancing the cursor first only moves the loss to the other side: a
    // death between the cursor write and the save would drop the puffs
    // instead. Neither ordering is right, because there is no transaction
    // spanning a preferences file and a Firestore document, and this ordering
    // is the one that fails toward "counted twice" rather than "silently
    // lost". Closing it properly needs a two-phase intent record reconciled on
    // the next launch, which is more machinery than a sub-3-second crash
    // window on the launch path is worth. Revisit only if the field ever shows
    // it happening.
    await _writeCursor(highest);

    // Repaint AFTER the cursor lands, always.
    //
    // Applying the events commits the journey, which rebuilds the app's mirror
    // push — and that push runs while the cursor is still at its old value, so
    // the widget renders `newCount + theSameEventsStillPending` and reads one
    // too high. Moving the cursor then silently makes that number wrong, and
    // because the mirror content has not changed since, the fingerprint would
    // skip every later push and leave it wrong indefinitely.
    //
    // The mirror on disk is already correct at this point; only the pixels are
    // behind. So this forces the render rather than rewriting anything, and
    // clears the fingerprint so a genuine later push is not skipped either.
    _pushed = null;
    await _store.refresh();
    return events.length;
  }

  /// Forgets what was last pushed, so the next push definitely reaches the
  /// device.
  ///
  /// [push] skips identical content, which is what stops a heavy logging day
  /// spamming the OS — but it also means a repaint that failed is never
  /// retried. Calling this on every foreground makes the widget self-healing:
  /// whatever went wrong, one trip through the app puts it right.
  void invalidate() => _pushed = null;

  /// Abandons whatever the widget has queued, without applying it.
  ///
  /// Called when the journey goes away — a sign-out or an account deletion.
  /// Queued puffs belong to the account that queued them, and a shared phone
  /// is the whole reason: the next person to sign in must not inherit the
  /// last person's taps. This is the same per-account rule that made
  /// community post ownership a server answer rather than a session-scoped
  /// set.
  /// Chained onto any drain in flight, for the same reason [drain] serialises
  /// itself: a drain can sit for up to [JourneyStore.widgetFlushTimeout]
  /// awaiting the journey write, and it finishes by writing its own cursor. A
  /// discard that ran underneath it would be overwritten by that write, handing
  /// the next account exactly the taps this method exists to throw away.
  Future<void> discardQueued() {
    final running = _inFlight;
    final task = running == null
        ? _discardQueued()
        : running.then((_) => _discardQueued());
    _inFlight = task.whenComplete(() => _inFlight = null);
    return task;
  }

  Future<void> _discardQueued() async {
    final events = PendingPuffs.decode(
      await _store.read(PendingPuffs.outboxKey),
    );
    var highest = await _readCursor();
    for (final event in events) {
      if (event.seq > highest) highest = event.seq;
    }
    await _writeCursor(highest);
  }

  Future<int> _readCursor() async {
    final raw = await _store.read(PendingPuffs.cursorKey);
    return int.tryParse(raw ?? '') ?? 0;
  }

  Future<void> _writeCursor(int value) =>
      _store.write(PendingPuffs.cursorKey, '$value');
}
