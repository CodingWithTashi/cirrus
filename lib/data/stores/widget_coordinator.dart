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

  /// Taps from the wrist, as the native relay lands them in the outbox.
  ///
  /// `_WidgetSync` drains on every emission, the same way it drains on
  /// resume. See [WidgetStore.watchTaps] for why resume alone was not enough.
  Stream<int> get watchTaps => _store.watchTaps;

  /// The last mirror actually pushed. Unchanged ⇒ no channel call, no redraw.
  String? _pushed;

  /// One drain at a time. A resume racing a foreground widget tap would
  /// otherwise run two drains over the same events, and both would read the
  /// cursor before either had written it — which is precisely how a puff gets
  /// counted twice.
  Future<void>? _inFlight;

  /// The single follow-up drain owed to everyone who asked while one was
  /// running, and the clock of the LATEST of them. See [drain].
  Future<int>? _followUp;
  DateTime? _followUpNow;

  /// A mirror that arrived while a drain (or a discard) was between reading
  /// the outbox and writing its cursor, held until the cursor lands. See
  /// [push].
  (Map<String, dynamic>, DateTime)? _parked;

  /// Set by a drain that moved the cursor, so [_settle] repaints even when no
  /// mirror was parked meanwhile.
  bool _repaintOwed = false;

  /// The day the midnight repaints were last armed for.
  String? _armedFor;

  Future<void> push(
    Map<String, dynamic> mirror, {
    required DateTime now,
  }) async {
    if (_inFlight != null) {
      // Parked, not pushed. A drain is between reading the outbox and writing
      // its cursor — for as long as the Firestore ack takes, up to 3 s — and a
      // mirror sent now carries the drained count while the same events still
      // sit above the cursor, so the launcher renders `count + pending` one
      // too high and the wrist keeps counting taps the mirror already
      // includes. The drain flushes the LATEST parked mirror the moment its
      // cursor lands: exactly one repaint, after the cursor, carrying the
      // wrist seq it may now retire (`WatchWire.reflected`).
      _parked = (mirror, now);
      return;
    }
    await _push(mirror, now: now);
  }

  Future<void> _push(
    Map<String, dynamic> mirror, {
    required DateTime now,
  }) async {
    final encoded = jsonEncode(mirror);
    if (encoded == _pushed) return;
    _pushed = encoded;
    await _store.write(WidgetMirror.key, encoded);
    await _store.refresh();
    // And the wrist, which is a device away rather than a process away. It
    // reads the document just written, so this has to follow the write; the
    // fingerprint above means an unchanged mirror is not re-sent, and the
    // native side re-pushes on every foreground anyway.
    //
    // This is also how signing out reaches a watch: the mirror carries
    // `hasJourney: false`, and the wrist stops drawing numbers the moment it
    // lands. It does NOT throw the wrist's queue away — every phone cold start
    // pushes that same mirror before `restoreSession` answers, and wiping on it
    // cost a wrist full of un-handed-over taps on every launch. Only a
    // different `sid` empties it; see `WatchWire.applyContext`.
    await _store.syncWatch();

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
    if (running != null) {
      // Coalesce, never drop. The drain in flight may have read the outbox
      // BEFORE the event that prompted this call was appended — a wrist tap
      // relayed in during the resume drain is the ordinary case — and it used
      // to answer such a caller with the running drain's result, which left
      // that tap queued until the next resume. On a phone that stays open,
      // that is never. One follow-up is shared by every caller that arrives in
      // the window: it starts after the running drain has written its cursor,
      // reads the outbox fresh, and applies only what is above that cursor, so
      // nothing is counted twice and nothing waits for a lifecycle event.
      //
      // It runs against the LATEST caller's clock, not the first's. Every
      // event's stamp is clamped to the drain's `now`, and a tap made after the
      // first caller asked — across local midnight, say — would otherwise be
      // clamped back onto yesterday. Each wrist tap calls in with a fresh
      // clock, so the last one is at or after every stamp it will apply.
      //
      // Runs whether the drain in flight succeeded or not, and forgets itself
      // either way: a follow-up that stayed parked behind a failed future would
      // answer every later mid-drain caller with that same failure and
      // silently switch real-time draining off for the rest of the session.
      _followUpNow = now;
      return _followUp ??= running
          .then<void>((_) {}, onError: (Object _) {})
          .whenComplete(() => _followUp = null)
          .then((_) => drain(journeys, now: _followUpNow ?? now));
    }
    return _track(_drainAndSettle(journeys, now));
  }

  /// Registers [task] as the one thing in flight, and forgets it when it ends
  /// — but only if it is STILL the thing in flight.
  ///
  /// An unconditional `_inFlight = null` used to clobber whatever
  /// [discardQueued] had chained on top of a running drain, so the next drain
  /// saw nothing running and ran alongside the discard: it read the OLD
  /// cursor and the previous account's outbox, and could apply those taps to
  /// whoever had signed in meanwhile — the exact leak the discard exists to
  /// prevent. With a follow-up drain now queued behind every wrist tap, that
  /// window is entered by construction rather than by accident.
  Future<T> _track<T>(Future<T> task) {
    late final Future<T> tracked;
    tracked = task.whenComplete(() {
      if (identical(_inFlight, tracked)) _inFlight = null;
    });
    _inFlight = tracked;
    return tracked;
  }

  Future<int> _drainAndSettle(JourneyStore journeys, DateTime now) async {
    try {
      return await _drain(journeys, now);
    } finally {
      await _settle();
    }
  }

  Future<void> _discardAndSettle() async {
    try {
      await _discardQueued();
    } finally {
      await _settle();
    }
  }

  /// The one repaint at the end of every drain and every discard, AFTER the
  /// cursor.
  ///
  /// A mirror parked by [push] while this was running goes out now — the
  /// latest one, and only once. Failing that, a drain that moved the cursor
  /// still forces a render of the mirror already on disk: applying the events
  /// commits the journey, whose rebuild pushed (and parked) a mirror in the
  /// ordinary case, but the fingerprint would otherwise let a mirror whose
  /// bytes did not change skip its repaint while the cursor underneath it did.
  ///
  /// Loops, because `_push` awaits the store and a rebuild can park another
  /// mirror in that window; one left behind would sit unflushed until the
  /// next drain, which is what parking exists to rule out.
  Future<void> _settle() async {
    var repaint = _repaintOwed;
    _repaintOwed = false;
    while (_parked != null) {
      final (mirror, now) = _parked!;
      _parked = null;
      _pushed = null;
      await _push(mirror, now: now);
      repaint = false;
    }
    if (!repaint) return;
    _pushed = null;
    await _store.refresh();
    // Same reason, for the wrist: the watch adds its own un-handed-over queue
    // on top of the mirror, so a drain that has just absorbed those taps leaves
    // it counting them twice until the next push.
    await _store.syncWatch();
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

    // Repaint AFTER the cursor lands, always — in [_settle], which runs once
    // this returns.
    //
    // Applying the events commits the journey, which rebuilds the app's mirror
    // push. While this drain is in flight that push is PARKED rather than
    // sent: sent now, it would run while the cursor is still at its old value,
    // so the widget renders `newCount + theSameEventsStillPending` and reads
    // one too high, and moving the cursor afterwards would silently make that
    // number wrong with a fingerprint that then skips every later push.
    _repaintOwed = true;
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
    return _track(
      running == null
          ? _discardAndSettle()
          : running.then(
              (_) => _discardAndSettle(),
              onError: (Object _) => _discardAndSettle(),
            ),
    );
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
