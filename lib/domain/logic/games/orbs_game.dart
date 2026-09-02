import 'dart:math' as math;

import 'game_id.dart';
import 'panic_game.dart';

/// Orbs: multiple-object tracking. A few orbs glow, then all look the same
/// and bounce for a few seconds; when the ring appears you tap the ones you
/// followed. The canonical visuospatial-attention task — it loads the visual
/// working memory a craving's imagery runs on (May et al. 2010). No trial
/// has tested this game itself on cravings, and the app never says so.
///
/// Pure Dart with its own physics: equal-mass elastic circles in fixed
/// sub-steps, every number from the injected `math.Random`. Difficulty is a
/// ladder: up on a perfect trial, down on any slip, an extra step down after
/// three slips running. A wrong tap costs the combo and nothing else; a
/// timed-out pick is not even a miss.
///
/// Geometry is normalized: width 1, height [aspect] (from [resize]).
class OrbsGame implements PanicGame {
  OrbsGame({math.Random? random, double aspect = defaultAspect})
    : this._(random ?? math.Random(), aspect, startLevel);

  /// A game already up the ladder — tests only.
  OrbsGame.atLevel(int level, {math.Random? random, double aspect = 1.4})
    : this._(random ?? math.Random(), aspect, level.clamp(0, maxLevel));

  OrbsGame._(this._random, this._aspect, this._level) {
    _startTrial();
  }

  static const double defaultAspect = 1.4;

  /// Thumb-sized: 40 px across at 360 dp.
  static const double orbRadius = 0.055;

  /// A tap lands on an orb within this many radii of its centre.
  static const double tapRadiusFactor = 1.5;

  static const int startLevel = 0;
  static const int maxLevel = 19;

  /// One dimension per rung: targets, orbs, widths/s, seconds of tracking.
  static const List<OrbsLevel> ladder = [
    OrbsLevel(targets: 2, orbs: 6, speed: 0.32, trackFor: 4),
    OrbsLevel(targets: 2, orbs: 6, speed: 0.36, trackFor: 4),
    OrbsLevel(targets: 2, orbs: 6, speed: 0.36, trackFor: 5),
    OrbsLevel(targets: 2, orbs: 7, speed: 0.36, trackFor: 5),
    OrbsLevel(targets: 3, orbs: 7, speed: 0.36, trackFor: 5),
    OrbsLevel(targets: 3, orbs: 7, speed: 0.42, trackFor: 5),
    OrbsLevel(targets: 3, orbs: 8, speed: 0.42, trackFor: 5),
    OrbsLevel(targets: 3, orbs: 8, speed: 0.48, trackFor: 5),
    OrbsLevel(targets: 3, orbs: 8, speed: 0.48, trackFor: 6),
    OrbsLevel(targets: 4, orbs: 8, speed: 0.48, trackFor: 6),
    OrbsLevel(targets: 4, orbs: 9, speed: 0.48, trackFor: 6),
    OrbsLevel(targets: 4, orbs: 9, speed: 0.54, trackFor: 6),
    OrbsLevel(targets: 4, orbs: 9, speed: 0.60, trackFor: 6),
    OrbsLevel(targets: 4, orbs: 9, speed: 0.60, trackFor: 7),
    OrbsLevel(targets: 4, orbs: 10, speed: 0.60, trackFor: 7),
    OrbsLevel(targets: 5, orbs: 10, speed: 0.60, trackFor: 7),
    OrbsLevel(targets: 5, orbs: 10, speed: 0.66, trackFor: 7),
    OrbsLevel(targets: 5, orbs: 10, speed: 0.66, trackFor: 8),
    OrbsLevel(targets: 5, orbs: 10, speed: 0.72, trackFor: 8),
    OrbsLevel(targets: 5, orbs: 10, speed: 0.80, trackFor: 8),
  ];

  /// Three slips running is a level too far: an extra step down.
  static const int struggleStreak = 3;

  /// The cue: long enough to read "remember these two" and find them.
  static const double cueFor = 1.5;
  static const double cueSpeedFactor = 0.35;

  /// The pick: a base plus a beat per target; motion slowed, never stopped.
  static const double pickBase = 1.2;
  static const double pickPerTarget = 0.7;
  static const double pickSpeedFactor = 0.25;

  /// The reveal: the truth on show and the result said; never a blank frame.
  static const double revealFor = 1.2;
  static const double revealSpeedFactor = 0.25;

  /// A second tap on the same orb this soon after the first is a bounce.
  static const double bounceGrace = 0.12;

  /// Fixed physics sub-steps with carry, so frame rate never changes a path.
  static const double physicsStep = 1 / 120;

  /// Speeds relax toward the phase's speed and are clamped so nothing stalls
  /// or rockets.
  static const double speedRelaxTau = 1.0;
  static const double speedClampLo = 0.6;
  static const double speedClampHi = 1.4;

  /// A small random turn every so often kills wall-to-wall orbits.
  static const double nudgeEvery = 0.8;
  static const double nudgeMaxDegrees = 6;

  /// How long the painter's records live.
  static const double pickRecordFor = 0.35;
  static const double resolveRecordFor = 0.5;

  final math.Random _random;
  final List<_Orb> _orbs = [];
  final List<GameEvent> _pending = [];
  final List<OrbPickRecord> _picks = [];
  final List<TrialRecord> _resolutions = [];
  TrialRecord? _lastTrial;

  double _aspect;
  int _level;
  OrbsLevel _trial = ladder[startLevel];
  OrbPhase _phase = OrbPhase.cue;
  double _phaseElapsed = 0;
  double _phaseFor = cueFor;
  double _accumulator = 0;
  double _nudgeTimer = 0;
  int _nextId = 0;
  int _foundThisTrial = 0;
  int _wrongThisTrial = 0;
  int _struggle = 0;
  int _trials = 0;
  int _perfectTrials = 0;

  double _elapsed = 0;
  int _score = 0;
  int _combo = 0;
  int _bestCombo = 0;
  int _misses = 0;
  bool _frozen = false;

  @override
  GameId get id => GameId.orbs;

  /// The ladder and the orbs persist across rounds.
  @override
  bool get freshEachRound => false;

  @override
  double get elapsed => _elapsed;

  /// Orbs found.
  @override
  int get score => _score;

  /// Consecutive correct picks; only a wrong pick ends it.
  @override
  int get combo => _combo;
  @override
  int get bestCombo => _bestCombo;

  /// Wrong picks. A timed-out pick is not one.
  @override
  int get misses => _misses;

  bool get frozen => _frozen;
  double get aspect => _aspect;
  int get level => _level;
  OrbPhase get phase => _phase;

  /// 0 at the start of the phase, 1 at its end.
  double get phaseProgress => (_phaseElapsed / _phaseFor).clamp(0.0, 1.0);

  OrbsLevel get trial => _trial;
  double get speed => _trial.speed;
  int get trials => _trials;
  int get perfectTrials => _perfectTrials;

  /// What the field's prompt says: how many to hold, and how it is going.
  int get targetCount => _trial.targets;
  int get foundThisTrial => _foundThisTrial;
  int get wrongThisTrial => _wrongThisTrial;

  /// The latest trial's result, kept until the next resolves.
  TrialRecord? get lastTrial => _lastTrial;

  /// Whether the true targets are on show — the cue and the reveal.
  bool get targetsVisible =>
      _phase == OrbPhase.cue || _phase == OrbPhase.reveal;

  List<OrbView> get orbs => List.unmodifiable([
    for (final o in _orbs)
      OrbView(
        id: o.id,
        x: o.x,
        y: o.y,
        vx: o.vx,
        vy: o.vy,
        isTarget: o.target,
        state: o.state,
      ),
  ]);

  /// Recent picks and resolutions for the painter, oldest first.
  List<OrbPickRecord> get picks => List.unmodifiable(_picks);
  List<TrialRecord> get resolutions => List.unmodifiable(_resolutions);

  /// The field's real aspect (height over width); positions scale with it.
  void resize(double aspect) {
    if (aspect.isNaN || aspect <= 0 || aspect == _aspect) return;
    final scale = aspect / _aspect;
    _aspect = aspect;
    for (final o in _orbs) {
      o.y = (o.y * scale).clamp(orbRadius, aspect - orbRadius);
    }
  }

  /// A trial cut in the cue or while tracking restarts — a long pause erases
  /// targets held only in the head; one cut in the pick or reveal resumes.
  @override
  void roundStarted(int round) {
    _frozen = false;
    final cut = _phase == OrbPhase.cue || _phase == OrbPhase.track;
    if (cut && _phaseElapsed > 0) {
      _startTrial();
      _pending.add(const PhaseChanged(OrbPhase.cue));
    }
  }

  @override
  void roundEnded(int round) => _frozen = true;

  /// The phase clock, then the physics in fixed sub-steps.
  @override
  List<GameEvent> advance(double dt) {
    if (_frozen || dt.isNaN || dt <= 0) return const [];
    _elapsed += dt;
    final events = List<GameEvent>.of(_pending);
    _pending.clear();

    _phaseElapsed += dt;
    if (_phaseElapsed >= _phaseFor) events.addAll(_nextPhase());

    _accumulator += dt;
    while (_accumulator + 1e-9 >= physicsStep) {
      _step(physicsStep);
      _accumulator -= physicsStep;
    }
    _prune();
    return events;
  }

  /// One tap at ([x], [y]) in normalized coordinates, only while the ring is
  /// up: the nearest orb within reach is found or wrong; an orb already
  /// picked, a bounce, or empty space is nothing.
  PickOutcome pick(double x, double y) {
    if (_frozen || _phase != OrbPhase.pick) return PickOutcome.ignored;
    _Orb? nearest;
    var best = double.infinity;
    for (final o in _orbs) {
      final d = _distance(o.x, o.y, x, y);
      if (d < best) {
        best = d;
        nearest = o;
      }
    }
    if (nearest == null || best > orbRadius * tapRadiusFactor) {
      return PickOutcome.ignored;
    }
    if (nearest.state != OrbState.plain) return PickOutcome.ignored;
    if (_elapsed - nearest.lastTapAt < bounceGrace) return PickOutcome.ignored;
    nearest.lastTapAt = _elapsed;

    final PickOutcome outcome;
    if (nearest.target) {
      nearest.state = OrbState.found;
      _score++;
      _combo++;
      if (_combo > _bestCombo) _bestCombo = _combo;
      _foundThisTrial++;
      outcome = PickOutcome.found;
    } else {
      nearest.state = OrbState.wrong;
      _misses++;
      _combo = 0;
      _wrongThisTrial++;
      outcome = PickOutcome.wrong;
    }
    _picks.add(
      OrbPickRecord(
        orb: nearest.id,
        x: nearest.x,
        y: nearest.y,
        at: _elapsed,
        correct: outcome == PickOutcome.found,
      ),
    );
    if (_foundThisTrial + _wrongThisTrial >= _trial.targets) {
      _pending.addAll(_resolveTrial());
    }
    return outcome;
  }

  // --- rules ---------------------------------------------------------------

  /// The frame's overshoot carries into the next phase so a cycle never
  /// drifts a frame per phase.
  List<GameEvent> _nextPhase() {
    final carry = math.max(0.0, _phaseElapsed - _phaseFor);
    switch (_phase) {
      case OrbPhase.cue:
        _enter(OrbPhase.track, _trial.trackFor.toDouble(), carry);
        return const [PhaseChanged(OrbPhase.track)];
      case OrbPhase.track:
        _enter(OrbPhase.pick, pickBase + pickPerTarget * _trial.targets, carry);
        return const [PhaseChanged(OrbPhase.pick)];
      case OrbPhase.pick:
        return [const PickTimedOut(), ..._resolveTrial(carry: carry)];
      case OrbPhase.reveal:
        _startTrial(carry: carry);
        return const [PhaseChanged(OrbPhase.cue)];
    }
  }

  void _enter(OrbPhase phase, double duration, [double carry = 0]) {
    _phase = phase;
    _phaseElapsed = carry;
    _phaseFor = duration;
  }

  /// The pick is over: the ladder moves a step and the truth goes on show.
  List<GameEvent> _resolveTrial({double carry = 0}) {
    final perfect = _wrongThisTrial == 0 && _foundThisTrial == _trial.targets;
    _trials++;
    if (perfect) {
      _perfectTrials++;
      _struggle = 0;
      _level = math.min(_level + 1, maxLevel);
    } else {
      _struggle++;
      var down = 1;
      if (_struggle >= struggleStreak) {
        down++;
        _struggle = 0;
      }
      _level = math.max(_level - down, 0);
    }
    final record = TrialRecord(
      at: _elapsed,
      perfect: perfect,
      found: _foundThisTrial,
      count: _trial.targets,
      targets: [for (final o in _orbs.where((o) => o.target)) o.id],
    );
    _resolutions.add(record);
    _lastTrial = record;
    _enter(OrbPhase.reveal, revealFor, carry);
    return [
      TrialResolved(
        perfect: perfect,
        found: _foundThisTrial,
        targets: _trial.targets,
      ),
      const PhaseChanged(OrbPhase.reveal),
    ];
  }

  /// A new trial at the current level on the same orbs.
  void _startTrial({double carry = 0}) {
    _trial = ladder[_level];
    _adjustCount(_trial.orbs);
    for (final o in _orbs) {
      o.target = false;
      o.state = OrbState.plain;
    }
    final order = List<int>.generate(_orbs.length, (i) => i);
    _shuffle(order);
    for (final i in order.take(_trial.targets)) {
      _orbs[i].target = true;
    }
    _foundThisTrial = 0;
    _wrongThisTrial = 0;
    _enter(OrbPhase.cue, cueFor, carry);
  }

  void _adjustCount(int count) {
    while (_orbs.length > count) {
      _orbs.removeLast();
    }
    while (_orbs.length < count) {
      final (x, y) = _freeSpot();
      final angle = _random.nextDouble() * 2 * math.pi;
      final s = _trial.speed * cueSpeedFactor;
      _orbs.add(
        _Orb(
          id: _nextId++,
          x: x,
          y: y,
          vx: math.cos(angle) * s,
          vy: math.sin(angle) * s,
        ),
      );
    }
  }

  /// A 3×4 lattice cell nobody is near, or failing that the emptiest one.
  (double, double) _freeSpot() {
    const columns = 3;
    const rows = 4;
    final cells = List<int>.generate(columns * rows, (i) => i);
    _shuffle(cells);
    final cellW = 1 / columns;
    final cellH = _aspect / rows;
    (double, double)? best;
    var bestGap = -1.0;
    for (final cell in cells) {
      final cx = (cell % columns + 0.5) * cellW;
      final cy = (cell ~/ columns + 0.5) * cellH;
      final x = (cx + (_random.nextDouble() - 0.5) * 0.6 * cellW).clamp(
        orbRadius,
        1 - orbRadius,
      );
      final y = (cy + (_random.nextDouble() - 0.5) * 0.6 * cellH).clamp(
        orbRadius,
        _aspect - orbRadius,
      );
      var gap = double.infinity;
      for (final o in _orbs) {
        gap = math.min(gap, _distance(o.x, o.y, x, y));
      }
      if (gap >= orbRadius * 3) return (x, y);
      if (gap > bestGap) {
        bestGap = gap;
        best = (x, y);
      }
    }
    return best!;
  }

  double get _speedFactor => switch (_phase) {
    OrbPhase.cue => cueSpeedFactor,
    OrbPhase.track => 1,
    OrbPhase.pick => pickSpeedFactor,
    OrbPhase.reveal => revealSpeedFactor,
  };

  void _step(double dt) {
    for (final o in _orbs) {
      o.x += o.vx * dt;
      o.y += o.vy * dt;
      _wall(o);
    }
    for (var i = 0; i < _orbs.length; i++) {
      for (var j = i + 1; j < _orbs.length; j++) {
        _collide(_orbs[i], _orbs[j]);
      }
    }
    // A collision's push can land an orb in the wall; nothing leaves.
    for (final o in _orbs) {
      _wall(o);
    }
    final target = _trial.speed * _speedFactor;
    final lo = speedClampLo * _trial.speed * pickSpeedFactor;
    final hi = speedClampHi * _trial.speed;
    final keep = math.exp(-dt / speedRelaxTau);
    for (final o in _orbs) {
      var s = math.sqrt(o.vx * o.vx + o.vy * o.vy);
      if (s < 1e-9) {
        final angle = _random.nextDouble() * 2 * math.pi;
        o.vx = math.cos(angle);
        o.vy = math.sin(angle);
        s = 1;
      }
      final relaxed = (target + (s - target) * keep).clamp(lo, hi);
      o.vx *= relaxed / s;
      o.vy *= relaxed / s;
    }
    _nudgeTimer += dt;
    if (_nudgeTimer >= nudgeEvery) {
      _nudgeTimer -= nudgeEvery;
      final max = nudgeMaxDegrees * math.pi / 180;
      for (final o in _orbs) {
        final a = (_random.nextDouble() * 2 - 1) * max;
        final c = math.cos(a);
        final sn = math.sin(a);
        final vx = o.vx * c - o.vy * sn;
        final vy = o.vx * sn + o.vy * c;
        o.vx = vx;
        o.vy = vy;
      }
    }
  }

  void _wall(_Orb o) {
    if (o.x < orbRadius) {
      o.x = orbRadius;
      o.vx = o.vx.abs();
    } else if (o.x > 1 - orbRadius) {
      o.x = 1 - orbRadius;
      o.vx = -o.vx.abs();
    }
    if (o.y < orbRadius) {
      o.y = orbRadius;
      o.vy = o.vy.abs();
    } else if (o.y > _aspect - orbRadius) {
      o.y = _aspect - orbRadius;
      o.vy = -o.vy.abs();
    }
  }

  /// Overlapping orbs are pushed apart half each and, if closing, swap the
  /// velocity along the line between them.
  void _collide(_Orb a, _Orb b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d >= 2 * orbRadius) return;
    final nx = d < 1e-9 ? 1.0 : dx / d;
    final ny = d < 1e-9 ? 0.0 : dy / d;
    final push = (2 * orbRadius - d) / 2;
    a.x -= nx * push;
    a.y -= ny * push;
    b.x += nx * push;
    b.y += ny * push;
    final (avx, avy, bvx, bvy) = elasticSwap(a.vx, a.vy, b.vx, b.vy, nx, ny);
    a.vx = avx;
    a.vy = avy;
    b.vx = bvx;
    b.vy = bvy;
  }

  /// Equal masses meeting along the unit normal ([nx], [ny]) swap their
  /// normal components when closing; energy and momentum are conserved.
  static (double, double, double, double) elasticSwap(
    double avx,
    double avy,
    double bvx,
    double bvy,
    double nx,
    double ny,
  ) {
    final an = avx * nx + avy * ny;
    final bn = bvx * nx + bvy * ny;
    if (an - bn <= 0) return (avx, avy, bvx, bvy);
    return (
      avx + (bn - an) * nx,
      avy + (bn - an) * ny,
      bvx + (an - bn) * nx,
      bvy + (an - bn) * ny,
    );
  }

  void _shuffle(List<int> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final t = list[i];
      list[i] = list[j];
      list[j] = t;
    }
  }

  static double _distance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return math.sqrt(dx * dx + dy * dy);
  }

  void _prune() {
    _picks.removeWhere((p) => _elapsed - p.at >= pickRecordFor);
    _resolutions.removeWhere((r) => _elapsed - r.at >= resolveRecordFor);
  }
}

/// One rung of the ladder.
class OrbsLevel {
  const OrbsLevel({
    required this.targets,
    required this.orbs,
    required this.speed,
    required this.trackFor,
  });

  final int targets;
  final int orbs;

  /// Widths per second.
  final double speed;

  /// Seconds the orbs move unmarked.
  final int trackFor;
}

enum OrbPhase { cue, track, pick, reveal }

enum OrbState { plain, found, wrong }

enum PickOutcome { found, wrong, ignored }

class _Orb {
  _Orb({
    required this.id,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
  });

  final int id;
  double x;
  double y;
  double vx;
  double vy;
  bool target = false;
  OrbState state = OrbState.plain;
  double lastTapAt = -1;
}

/// An orb as the painter sees it; [isTarget] is only honest to draw while
/// [OrbsGame.targetsVisible].
class OrbView {
  const OrbView({
    required this.id,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.isTarget,
    required this.state,
  });

  final int id;
  final double x;
  final double y;
  final double vx;
  final double vy;
  final bool isTarget;
  final OrbState state;

  double get speed => math.sqrt(vx * vx + vy * vy);
}

class OrbPickRecord {
  const OrbPickRecord({
    required this.orb,
    required this.x,
    required this.y,
    required this.at,
    required this.correct,
  });

  final int orb;
  final double x;
  final double y;
  final double at;
  final bool correct;
}

class TrialRecord {
  const TrialRecord({
    required this.at,
    required this.perfect,
    required this.found,
    required this.count,
    required this.targets,
  });

  final double at;
  final bool perfect;
  final int found;
  final int count;

  /// Orb ids that were the targets.
  final List<int> targets;
}

/// The trial moved on. The cue and the pick are felt; the rest only seen.
class PhaseChanged extends GameEvent {
  const PhaseChanged(this.phase);

  final OrbPhase phase;

  @override
  GameFeedback get feedback => switch (phase) {
    OrbPhase.cue || OrbPhase.pick => GameFeedback.attention,
    OrbPhase.track || OrbPhase.reveal => GameFeedback.none,
  };
}

/// The ring ran out with targets unpicked. Not a miss, but felt.
class PickTimedOut extends GameEvent {
  const PickTimedOut();

  @override
  GameFeedback get feedback => GameFeedback.attention;
}

class TrialResolved extends GameEvent {
  const TrialResolved({
    required this.perfect,
    required this.found,
    required this.targets,
  });

  final bool perfect;
  final int found;
  final int targets;

  @override
  GameFeedback get feedback =>
      perfect ? GameFeedback.comboMilestone : GameFeedback.none;
}
