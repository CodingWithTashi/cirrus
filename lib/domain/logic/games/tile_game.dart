import 'dart:math' as math;

import 'game_id.dart';
import 'panic_game.dart';

/// Tiles (docs/09 §8): four lanes, one tile per row, the bottom row is the
/// gap to fill — Piano Tiles Classic with an adaptive clock. A tile waits a
/// fixed multiple of the player's own recent pace, so difficulty follows the
/// player; a miss costs the combo and nothing else. `GameSession` owns the
/// 60-second clock; this engine wants a fresh board each round.
///
/// Geometry is in rows from the top of the field ([visibleRows] shown). The
/// board is a list of lanes, target first; only the target sinks on its own,
/// from [home] to [missAt] over its window, and every advance shifts the
/// board down a row.
class TileGame implements PanicGame {
  TileGame({math.Random? random}) : _random = random ?? math.Random() {
    while (_rows.length < bufferedRows) {
      _rows.add(_nextLane());
    }
    _land();
  }

  static const int lanes = 4;

  /// Rows visible in the field — Piano Tiles' proportions.
  static const double visibleRows = 4;

  /// Rows dealt ahead: the four on screen and one above them, so the slide
  /// after a hit always has something to bring in.
  static const int bufferedRows = 5;

  /// The target's top edge when it lands, in rows from the top of the
  /// field: the bottom row, three-quarters of a row of travel left below it.
  static const double home = 2.75;

  /// The target is lost once its top edge sinks to here — half of it under
  /// the bottom edge. Half rather than all so the loss is on screen to
  /// shake.
  static const double missAt = visibleRows - 0.5;

  /// Seconds of history the pace is read from.
  static const double paceWindow = 3;

  /// A tile waits this many of the player's own recent tap intervals: at two
  /// taps a second the window is 0.75 s, at four it hits the floor. Steady
  /// play never loses a tile; a hesitation half again as long as the beat
  /// does, and that is the whole mechanism.
  static const double paceFactor = 1.5;

  /// The tightest a window ever gets.
  static const double windowFloor = 0.5;

  /// The widest — a first tile, or someone who stopped tapping — from the
  /// start of the board's minute to its end; the one time-based ramp.
  static const double windowCeilingStart = 2.4;
  static const double windowCeilingEnd = 1.6;
  static const double windowRampSeconds = 60;

  /// How long a resolved tile stays in [departed] for its animation.
  static const double resolvedFor = 0.4;

  /// A second tap in the lane just hit, this soon after the hit, with the
  /// new target elsewhere, is a bounce rather than a decision — ignored, not
  /// a miss. It is never a hit either: one tap is one hit, always.
  static const double bounceGrace = 0.12;

  final math.Random _random;
  final List<int> _rows = [];
  final List<Departed> _departed = [];
  final List<double> _hitTimes = [];

  double _elapsed = 0;
  int _score = 0;
  int _combo = 0;
  int _bestCombo = 0;
  int _misses = 0;
  int _dealt = 0;
  int _lastLane = -1;
  int _sameLaneRun = 0;
  double _landedAt = 0;
  double _window = windowCeilingStart;
  double _lastAdvanceAt = -1;
  int? _lastHitLane;
  double? _lastHitAt;
  bool _frozen = false;

  @override
  GameId get id => GameId.tiles;

  @override
  bool get freshEachRound => true;

  /// Game seconds: the sum of the steps the session handed over.
  @override
  double get elapsed => _elapsed;

  /// Tiles hit — the score, and what the personal best records.
  @override
  int get score => _score;

  /// Consecutive hits without a miss.
  @override
  int get combo => _combo;
  @override
  int get bestCombo => _bestCombo;

  /// Wrong-lane taps and tiles that got away, together.
  @override
  int get misses => _misses;

  /// Rows dealt so far, on screen or gone.
  int get dealt => _dealt;

  /// Between rounds: inputs are ignored and nothing moves.
  bool get frozen => _frozen;

  /// Lanes, target first; row k sits k rows above the target.
  List<int> get rows => List.unmodifiable(_rows);

  /// The lane to tap right now — the gap to fill.
  int get targetLane => _rows.first;

  /// How far the target has sunk: 0 at [home], 1 at [missAt].
  double get sink => ((_elapsed - _landedAt) / _window).clamp(0.0, 1.0);

  /// The target's top edge right now, in rows.
  double get targetY => home + (missAt - home) * sink;

  /// Seconds the current target was given when it landed.
  double get window => _window;

  /// Game second of the last advance, for the slide; negative before any.
  double get lastAdvanceAt => _lastAdvanceAt;

  /// Hits per second, read off the last [paceWindow] seconds.
  ///
  /// Intervals, not a head count: seven hits in three seconds is a player
  /// tapping twice a second, and counting them as 7/3 would tighten every
  /// window by a sixth. The clock runs from the oldest hit in view to now,
  /// so a pause starts loosening the next tile's window at once. Under
  /// three hits there are no intervals worth reading, and the head count
  /// keeps the first tiles generous.
  double get pace {
    final recent = _hitTimes.where((t) => _elapsed - t <= paceWindow).toList();
    if (recent.length < 3) return recent.length / paceWindow;
    final span = _elapsed - recent.first;
    return span <= 0 ? 0 : (recent.length - 1) / span;
  }

  /// Recently resolved tiles, oldest first, kept for [resolvedFor].
  List<Departed> get departed => List.unmodifiable(_departed);

  /// The widest window at game second [t]: 2.4 s at the start, 1.6 s at the
  /// end of the minute, straight line between.
  static double windowCeilingAt(double t) {
    final p = (t / windowRampSeconds).clamp(0.0, 1.0);
    return windowCeilingStart + (windowCeilingEnd - windowCeilingStart) * p;
  }

  /// The window a tile landing at game second [t] gets from a player
  /// hitting [pace] tiles a second.
  static double windowFor({required double pace, required double t}) {
    final ceiling = windowCeilingAt(t);
    if (pace <= 0) return ceiling;
    return (paceFactor / pace).clamp(windowFloor, ceiling);
  }

  @override
  void roundStarted(int round) => _frozen = false;

  @override
  void roundEnded(int round) => _frozen = true;

  /// Moves the clock on by [dt] seconds and reports what the clock itself
  /// caused: a target that got away.
  @override
  List<GameEvent> advance(double dt) {
    if (_frozen || dt.isNaN || dt <= 0) return const [];
    final events = <GameEvent>[];
    _elapsed += dt;

    if (sink >= 1) {
      final lane = _rows.first;
      _departed.add(Departed(lane: lane, at: _elapsed, hit: false, y: missAt));
      _misses++;
      _combo = 0;
      _advanceRow();
      events.add(TileMissed(lane));
    }
    _departed.removeWhere((d) => _elapsed - d.at >= resolvedFor);
    return events;
  }

  /// One pointer-down in [lane]. Hits the target if that is its lane and
  /// brings the next row down at once — the board goes as fast as the
  /// thumbs do. Anything else costs the combo. One tap resolves at most one
  /// tile.
  TapOutcome tap(int lane) {
    if (_frozen || lane < 0 || lane >= lanes) return TapOutcome.ignored;
    if (lane == _rows.first) {
      _departed.add(Departed(lane: lane, at: _elapsed, hit: true, y: targetY));
      _score++;
      _combo++;
      if (_combo > _bestCombo) _bestCombo = _combo;
      _hitTimes.add(_elapsed);
      _hitTimes.removeWhere((t) => _elapsed - t > paceWindow);
      _lastHitLane = lane;
      _lastHitAt = _elapsed;
      _advanceRow();
      return TapOutcome.hit;
    }
    final lastHitAt = _lastHitAt;
    if (lane == _lastHitLane &&
        lastHitAt != null &&
        _elapsed - lastHitAt < bounceGrace) {
      return TapOutcome.ignored;
    }
    _misses++;
    _combo = 0;
    return TapOutcome.miss;
  }

  void _advanceRow() {
    _rows.removeAt(0);
    _rows.add(_nextLane());
    _lastAdvanceAt = _elapsed;
    _land();
  }

  /// A new target has arrived: its window is read off the pace right now,
  /// this hit included, and fixed for its whole wait so the sink is a
  /// straight line the eye can read.
  void _land() {
    _landedAt = _elapsed;
    _window = windowFor(pace: pace, t: _elapsed);
  }

  /// Uniform over the lanes, but never the same lane three rows running: a
  /// repeat is a legitimate beat, a run reads as the game being stuck.
  int _nextLane() {
    var lane = _random.nextInt(lanes);
    if (_sameLaneRun >= 2 && lane == _lastLane) {
      lane = (lane + 1 + _random.nextInt(lanes - 1)) % lanes;
    }
    _sameLaneRun = lane == _lastLane ? _sameLaneRun + 1 : 1;
    _lastLane = lane;
    _dealt++;
    return lane;
  }
}

/// A tile that has left the board — hit or lost — with where it was when it
/// resolved, so the field can animate it out from there.
class Departed {
  const Departed({
    required this.lane,
    required this.at,
    required this.hit,
    required this.y,
  });

  final int lane;

  /// Game second it resolved.
  final double at;
  final bool hit;

  /// Top edge at that moment, in rows.
  final double y;
}

enum TapOutcome { hit, miss, ignored }

/// The target sank past the miss line untapped — the clock's miss, not the
/// thumb's.
class TileMissed extends GameEvent {
  const TileMissed(this.lane);

  final int lane;

  @override
  GameFeedback get feedback => GameFeedback.miss;
}
