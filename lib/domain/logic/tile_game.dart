import 'dart:math' as math;

/// The 60-second panic game (docs/09 §8): four lanes, one tile per row, the
/// bottom row is the gap to fill — Piano Tiles, the way the founder plays
/// it. Pure Dart: the widget maps rows to pixels and pointer-downs to lanes;
/// every rule and every number lives here.
///
/// Why this shape (Skorka-Brown, Andrade, Whalley & May 2015; docs/09 §8): a
/// craving is mostly vivid sensory imagery, and a task that loads the same
/// visuospatial working memory shrinks it. What matters is not the game but
/// four properties:
///
/// - **continuous demand** — a target is always there, and it is always
///   slipping away;
/// - **a rhythm** — the board scrolls as fast as you tap, so the beat is
///   your own and never something to wait for;
/// - **immediate feedback** — every tap resolves as a hit or a miss on the
///   spot, and a tile that gets away resolves on its own;
/// - **difficulty that follows the player** — the time a tile waits is a
///   fixed multiple of your own recent pace, so it tightens exactly as you
///   find it easy and loosens when you struggle. Attention cannot drift
///   without a tile paying for it, and a tired thumb is never punished.
///
/// **No game-over.** Panic mode never punishes someone mid-craving: a miss
/// costs the combo and nothing else, the clock keeps running, and sixty
/// seconds always end on the person's own word about the craving.
///
/// Geometry is in rows measured from the top of the field, which shows
/// [visibleRows] rows. The board is a list of lanes, target first: row k
/// sits k rows above the target. Only the target moves on its own — it
/// sinks from [home] to [missAt] over its window — and every advance shifts
/// the whole board down one row.
class TileGame {
  TileGame({math.Random? random}) : _random = random ?? math.Random() {
    while (_rows.length < bufferedRows) {
      _rows.add(_nextLane());
    }
    _land();
  }

  static const int lanes = 4;
  static const Duration length = Duration(seconds: 60);

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

  /// The widest — a first tile, or someone who has stopped tapping — from
  /// the start of the minute to its end. The one time-based ramp left, and
  /// a gentle one: a slow player still feels the minute tighten.
  static const double windowCeilingStart = 2.4;
  static const double windowCeilingEnd = 1.6;

  /// How long a resolved tile stays in [departed] for its animation.
  static const double resolvedFor = 0.4;

  /// A second tap in the lane just hit, this soon after the hit, with the
  /// new target elsewhere, is a bounce rather than a decision — ignored, not
  /// a miss. It is never a hit either: one tap is one hit, always.
  static const double bounceGrace = 0.12;

  /// The most game time one [advance] may cover. The ticker stops while the
  /// app is backgrounded and hands over the whole gap on resume; without the
  /// clamp the target would be lost the moment the app came back.
  static const double maxStep = 0.1;

  /// The clock is a sum of 60 fps steps, so it lands a hair either side of
  /// every whole second. Anything closer than this counts as reached.
  static const double _epsilon = 1e-6;

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
  bool _finished = false;

  /// Game seconds elapsed — the sum of clamped steps, so a backgrounded app
  /// resumes where it froze rather than at wall-clock time.
  double get elapsed => _elapsed;

  /// The countdown the header shows: 60 at the start, 0 when done.
  int get secondsLeft => (length.inSeconds - _elapsed - _epsilon).ceil().clamp(
    0,
    length.inSeconds,
  );

  /// Tiles hit — the score, and what the personal best records.
  int get score => _score;

  /// Consecutive hits without a miss.
  int get combo => _combo;
  int get bestCombo => _bestCombo;

  /// Wrong-lane taps and tiles that got away, together.
  int get misses => _misses;

  /// Rows dealt so far, on screen or gone.
  int get dealt => _dealt;
  bool get finished => _finished;

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
  /// end, straight line between.
  static double windowCeilingAt(double t) {
    final p = (t / length.inSeconds).clamp(0.0, 1.0);
    return windowCeilingStart + (windowCeilingEnd - windowCeilingStart) * p;
  }

  /// The window a tile landing at game second [t] gets from a player
  /// hitting [pace] tiles a second.
  static double windowFor({required double pace, required double t}) {
    final ceiling = windowCeilingAt(t);
    if (pace <= 0) return ceiling;
    return (paceFactor / pace).clamp(windowFloor, ceiling);
  }

  /// Whether [score] sets a new personal best over [best] (null = never
  /// played). Zero never does: a game nobody tapped through leaves the
  /// honest empty state in place rather than recording "best: 0".
  static bool beats(int score, int? best) =>
      score > 0 && (best == null || score > best);

  /// Moves the clock on by [dt] seconds (clamped to [maxStep]) and reports
  /// what the clock itself caused: a target that got away, the end.
  List<GameEvent> advance(double dt) {
    if (_finished) return const [];
    final events = <GameEvent>[];
    if (dt.isNaN || dt <= 0) return events;
    _elapsed += math.min(dt, maxStep);

    if (sink >= 1) {
      final lane = _rows.first;
      _departed.add(Departed(lane: lane, at: _elapsed, hit: false, y: missAt));
      _misses++;
      _combo = 0;
      _advanceRow();
      events.add(TileMissed(lane));
    }
    _departed.removeWhere((d) => _elapsed - d.at >= resolvedFor);

    if (_elapsed + _epsilon >= length.inSeconds) {
      _finished = true;
      events.add(const GameFinished());
    }
    return events;
  }

  /// One pointer-down in [lane]. Hits the target if that is its lane and
  /// brings the next row down at once — the board goes as fast as the
  /// thumbs do. Anything else costs the combo. One tap resolves at most one
  /// tile.
  TapOutcome tap(int lane) {
    if (_finished || lane < 0 || lane >= lanes) return TapOutcome.ignored;
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

sealed class GameEvent {
  const GameEvent();
}

/// The target sank past the miss line untapped — the clock's miss, not the
/// thumb's.
class TileMissed extends GameEvent {
  const TileMissed(this.lane);

  final int lane;
}

class GameFinished extends GameEvent {
  const GameFinished();
}
