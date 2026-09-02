import 'dart:math' as math;

import 'game_id.dart';
import 'panic_game.dart';

/// Blocks: pieces fall, you slide and turn them, a full row clears — the
/// mechanism the Tetris craving studies used, as its own expression (docs/08
/// §7 row 20): an 8×14 board, six 3/4/5-cell pieces drawn as pebbles, no
/// ghost, no preview, no garbage, and no game-over — when the stack reaches
/// the ceiling the bottom four rows dissolve and play goes on.
///
/// Gravity follows the player: a piece gets ×1.5 of their own placement beat
/// to fall the board, eased further as the stack climbs. Pure Dart; the
/// widget maps gestures to [moveTo], [rotate], [softDrop] and [hardDrop].
///
/// Columns 0..[cols]-1, rows 0..[visibleRows]-1 top to bottom, [hiddenRows]
/// above row 0 for kicks. The active piece has an integer row and a
/// continuous `y` that never enters a row it could not occupy.
class BlocksGame implements PanicGame {
  BlocksGame({math.Random? random}) : _random = random ?? math.Random() {
    _spawnOrRelieve();
  }

  /// A board with a stack in place — tests only. [stack] lists the bottom
  /// visible rows top to bottom (`.` empty, `v` volt, `o` oxygen, else stone);
  /// [firstPiece] forces the first deal.
  BlocksGame.withStack(
    List<String> stack, {
    math.Random? random,
    BlockKind? firstPiece,
  }) : _random = random ?? math.Random() {
    if (stack.length > visibleRows) throw ArgumentError('too many rows');
    if (firstPiece != null) _queue.add(firstPiece);
    for (var i = 0; i < stack.length; i++) {
      final line = stack[i];
      if (line.length != cols) throw ArgumentError('row $i is not $cols wide');
      final row = visibleRows - stack.length + i;
      for (var c = 0; c < cols; c++) {
        final tone = switch (line[c]) {
          '.' => null,
          'v' => BlockTone.volt,
          'o' => BlockTone.oxygen,
          _ => BlockTone.stone,
        };
        // Each fixture row is its own "piece", so it bridges sideways only.
        _cells[row + hiddenRows][c] = tone == null
            ? null
            : _Cell(tone, -(row + 1));
      }
    }
    _spawnOrRelieve();
  }

  static const int cols = 8;
  static const int visibleRows = 14;

  /// Room above the field for the one upward kick; nothing spawns hidden.
  static const int hiddenRows = 2;
  static const int totalRows = visibleRows + hiddenRows;
  static const int spawnCol = 3;

  /// Eight draws per bag: trominoes twice (the quick beat), pentominoes once.
  static const List<BlockKind> bag = [
    BlockKind.i3,
    BlockKind.i3,
    BlockKind.l3,
    BlockKind.l3,
    BlockKind.t4,
    BlockKind.l4,
    BlockKind.p5,
    BlockKind.i5,
  ];

  /// Seconds of placement history the pace is read from (~5 placements).
  static const double paceWindow = 12;

  /// A piece gets this many of the player's own placement intervals to fall
  /// [fallReference] rows — the tile game's multiple.
  static const double paceFactor = 1.5;
  static const double fallReference = 10;

  /// The slowest a piece ever falls, rows/s, ramping over the first minute —
  /// the one time-based ramp.
  static const double gravityFloorStart = 2.0;
  static const double gravityFloorEnd = 2.5;
  static const double floorRampSeconds = 60;

  /// Faster than this is a blur only a hard drop survives.
  static const double gravityCeiling = 8;

  /// From [easeFrom] rows of stack gravity eases linearly to [easeMin] of
  /// itself at [easeTo] — a tall stack shortens the fall anyway.
  static const int easeFrom = 8;
  static const int easeTo = 12;
  static const double easeMin = 0.5;

  /// A landed piece can be nudged for this long; each nudge restarts the
  /// wait, [lockMoveResets] times.
  static const double lockDelay = 0.5;
  static const int lockMoveResets = 10;

  /// A lock leaving a cell in this row or above relieves the board; a
  /// blocked spawn is the backstop.
  static const int reliefRow = 2;

  /// The bottom rows dissolve — the part the player stopped looking at, so
  /// the surface they are reading stays valid, four rows lower.
  static const int reliefRows = 4;

  /// A second tap this soon after a turn is a contact bounce.
  static const double rotateGrace = 0.08;

  /// A hard drop this soon after a spawn is ignored: see the piece first.
  static const double spawnGrace = 0.15;

  /// How long the painter's records live.
  static const double lockRecordFor = 0.12;
  static const double clearRecordFor = 0.24;
  static const double reliefRecordFor = 0.45;

  /// Rotation kicks in order: sideways, one up, two sideways for the long
  /// piece. Never down — a turn never shoves the piece toward the floor.
  static const List<(int, int)> kicks = [
    (0, 0),
    (-1, 0),
    (1, 0),
    (0, -1),
    (-2, 0),
    (2, 0),
  ];

  final math.Random _random;
  final List<List<_Cell?>> _cells = List.generate(
    totalRows,
    (_) => List<_Cell?>.filled(cols, null),
  );
  final List<BlockKind> _queue = [];
  final List<double> _placements = [];
  final List<BlockLockRecord> _locks = [];
  final List<BlockClearRecord> _clears = [];
  final List<BlockReliefRecord> _reliefs = [];

  late BlockPiece _active;
  double _y = 0;
  double _gravity = gravityFloorStart;
  bool _resting = false;
  bool _landedByPlayer = false;
  double _lockTimer = 0;
  int _lockResets = 0;
  double _spawnedAt = 0;
  double _lastRotateAt = -1;
  BlockKind? _lastDealt;

  double _elapsed = 0;
  int _score = 0;
  int _combo = 0;
  int _bestCombo = 0;
  int _misses = 0;
  int _placed = 0;
  bool _frozen = false;

  @override
  GameId get id => GameId.blocks;

  /// The board persists across rounds.
  @override
  bool get freshEachRound => false;

  @override
  double get elapsed => _elapsed;

  /// Lines cleared.
  @override
  int get score => _score;

  /// Consecutive pieces that each cleared a line.
  @override
  int get combo => _combo;
  @override
  int get bestCombo => _bestCombo;

  /// Reliefs — times the board had to breathe.
  @override
  int get misses => _misses;

  int get placed => _placed;
  bool get frozen => _frozen;

  /// The visible board, row 0 at the top.
  List<List<BlockTone?>> get board => List.unmodifiable([
    for (var r = 0; r < visibleRows; r++)
      List<BlockTone?>.unmodifiable(_cells[r + hiddenRows].map((c) => c?.tone)),
  ]);

  BlockTone? cellAt(int col, int row) => _cells[row + hiddenRows][col]?.tone;

  /// Which locked piece a cell belongs to, so the painter bridges only the
  /// cells of one piece into one pebble.
  int? pieceAt(int col, int row) => _cells[row + hiddenRows][col]?.piece;

  /// The piece in play, with the continuous row the painter draws it at.
  BlockPiece get active => _active.copyWith(y: _y);

  /// Rows/s the active piece falls; fixed for its whole fall.
  double get gravity => _gravity;

  /// Sitting on something, waiting to lock.
  bool get resting => _resting;

  /// Rows from the floor to the highest locked cell; 0 when empty.
  int get stackHeight => visibleRows - _topRow();

  /// Player placements per second over the last [paceWindow] seconds:
  /// intervals, not a head count, and only hard drops and soft-drop
  /// landings — a piece gravity locked sets no beat, or gravity feeds itself.
  double get pace {
    final recent = _placements
        .where((t) => _elapsed - t <= paceWindow)
        .toList();
    if (recent.length < 3) return recent.length / paceWindow;
    final span = _elapsed - recent.first;
    return span <= 0 ? 0 : (recent.length - 1) / span;
  }

  /// Recent locks, clears and reliefs for the painter, oldest first.
  List<BlockLockRecord> get locks => List.unmodifiable(_locks);
  List<BlockClearRecord> get clears => List.unmodifiable(_clears);
  List<BlockReliefRecord> get reliefs => List.unmodifiable(_reliefs);

  static double gravityFloorAt(double t) {
    final p = (t / floorRampSeconds).clamp(0.0, 1.0);
    return gravityFloorStart + (gravityFloorEnd - gravityFloorStart) * p;
  }

  /// How much a stack of [stackHeight] rows slows the fall.
  static double easeFor(int stackHeight) {
    if (stackHeight <= easeFrom) return 1;
    if (stackHeight >= easeTo) return easeMin;
    return 1 + (easeMin - 1) * (stackHeight - easeFrom) / (easeTo - easeFrom);
  }

  /// Rows/s for a piece spawning at second [t]: the player's beat times
  /// [paceFactor], between floor and ceiling, eased by the stack.
  static double gravityFor({
    required double pace,
    required double t,
    required int stackHeight,
  }) {
    final floor = gravityFloorAt(t);
    final base = pace <= 0
        ? floor
        : (fallReference * pace / paceFactor).clamp(floor, gravityCeiling);
    return base * easeFor(stackHeight);
  }

  @override
  void roundStarted(int round) => _frozen = false;

  @override
  void roundEnded(int round) => _frozen = true;

  /// The piece falls, lands, and locks when its wait is up.
  @override
  List<GameEvent> advance(double dt) {
    if (_frozen || dt.isNaN || dt <= 0) return const [];
    _elapsed += dt;
    final events = <GameEvent>[];
    if (!_resting) {
      final p = _active;
      final free = _lowestFreeRow(p.col, p.row, p.state, p.kind);
      final target = _y + _gravity * dt;
      if (target >= free) {
        _y = free.toDouble();
        _active = p.copyWith(row: free);
        _resting = true;
        _lockTimer = 0;
      } else {
        _y = target;
        _active = p.copyWith(row: target.floor());
      }
    } else {
      _lockTimer += dt;
      if (_lockTimer >= lockDelay) events.addAll(_lock(hardDrop: false));
    }
    _prune();
    return events;
  }

  /// Slides toward pivot column [col] one column at a time, stopping at the
  /// first it does not fit. Returns the columns moved.
  int moveTo(int col) {
    if (_frozen) return 0;
    final p = _active;
    var current = p.col;
    var moved = 0;
    final direction = col > current ? 1 : -1;
    while (current != col) {
      final next = current + direction;
      if (!_fitsFloating(next, p.row, p.state, p.kind)) break;
      current = next;
      moved++;
    }
    if (moved > 0) {
      _active = p.copyWith(col: current);
      _afterInput();
    }
    return moved;
  }

  /// A quarter turn clockwise, kicked sideways or up if that is what fits.
  RotateOutcome rotate() {
    if (_frozen) return RotateOutcome.ignored;
    if (_lastRotateAt >= 0 && _elapsed - _lastRotateAt < rotateGrace) {
      return RotateOutcome.ignored;
    }
    _lastRotateAt = _elapsed;
    final p = _active;
    final next = (p.state + 1) % 4;
    for (final (dx, dy) in kicks) {
      if (_fitsFloating(p.col + dx, p.row + dy, next, p.kind)) {
        _y += dy;
        _active = p.copyWith(col: p.col + dx, row: p.row + dy, state: next);
        _afterInput();
        return RotateOutcome.turned;
      }
    }
    return RotateOutcome.blocked;
  }

  /// Pulls the piece down up to [rows] rows without locking it.
  int softDrop(int rows) {
    if (_frozen || rows <= 0) return 0;
    final p = _active;
    final free = _lowestFreeRow(p.col, p.row, p.state, p.kind);
    final to = math.min(p.row + rows, free);
    final moved = to - p.row;
    if (moved <= 0) return 0;
    _active = p.copyWith(row: to);
    _y = to.toDouble();
    if (to == free) {
      _resting = true;
      _landedByPlayer = true;
      _lockTimer = 0;
    }
    return moved;
  }

  /// Slams the piece to the floor and locks it; ignored within [spawnGrace].
  List<GameEvent> hardDrop() {
    if (_frozen || _elapsed - _spawnedAt < spawnGrace) return const [];
    final p = _active;
    final free = _lowestFreeRow(p.col, p.row, p.state, p.kind);
    _active = p.copyWith(row: free);
    _y = free.toDouble();
    return _lock(hardDrop: true, fromRow: p.row);
  }

  // --- rules ---------------------------------------------------------------

  /// After a move or turn: the piece may have left a ledge or landed on one;
  /// a nudge while resting restarts the lock wait, [lockMoveResets] times.
  void _afterInput() {
    final p = _active;
    final free = _lowestFreeRow(p.col, p.row, p.state, p.kind);
    if (free > p.row) {
      _resting = false;
    } else if (!_resting) {
      _resting = true;
      _lockTimer = 0;
      _y = p.row.toDouble();
    } else if (_lockResets < lockMoveResets) {
      _lockResets++;
      _lockTimer = 0;
    }
  }

  List<GameEvent> _lock({required bool hardDrop, int? fromRow}) {
    final p = _active;
    final cells = p.cells;
    for (final (c, r) in cells) {
      _cells[r + hiddenRows][c] = _Cell(p.kind.tone, _placed);
    }
    _placed++;
    if (hardDrop || _landedByPlayer) {
      _placements.add(_elapsed);
      _placements.removeWhere((t) => _elapsed - t > paceWindow);
    }
    _locks.add(
      BlockLockRecord(
        cells: cells,
        tone: p.kind.tone,
        at: _elapsed,
        hardDrop: hardDrop,
        fromRow: fromRow ?? p.row,
        toRow: p.row,
      ),
    );
    final events = <GameEvent>[PieceLocked(cells, hardDrop: hardDrop)];

    final full = <int>[];
    for (var r = -hiddenRows; r < visibleRows; r++) {
      if (_cells[r + hiddenRows].every((cell) => cell != null)) full.add(r);
    }
    if (full.isNotEmpty) {
      for (final r in full) {
        _cells.removeAt(r + hiddenRows);
        _cells.insert(0, List<_Cell?>.filled(cols, null));
      }
      _score += full.length;
      _combo++;
      if (_combo > _bestCombo) _bestCombo = _combo;
      _clears.add(BlockClearRecord(rows: full, at: _elapsed));
      events.add(LinesCleared(rows: full, combo: _combo));
    } else {
      _combo = 0;
    }

    if (_topRow() <= reliefRow) events.add(_relieve(ReliefReason.ceiling));
    final backstop = _spawnOrRelieve();
    if (backstop != null) events.add(backstop);
    return events;
  }

  /// Deals the next piece; if it does not fit, the board breathes and the
  /// same piece is placed again — one relief always frees rows 0–1.
  BoardRelieved? _spawnOrRelieve() {
    if (_spawn()) return null;
    final relief = _relieve(ReliefReason.blockedSpawn);
    _place(_active.kind);
    return relief;
  }

  /// The bottom rows dissolve, the stack drops, the combo resets; the score
  /// is untouched and the round keeps running.
  BoardRelieved _relieve(ReliefReason reason) {
    final dissolved = <BlockCell>[];
    for (var r = visibleRows - reliefRows; r < visibleRows; r++) {
      for (var c = 0; c < cols; c++) {
        final cell = _cells[r + hiddenRows][c];
        if (cell != null) {
          dissolved.add(BlockCell(col: c, row: r, tone: cell.tone));
        }
      }
    }
    for (var i = 0; i < reliefRows; i++) {
      _cells.removeLast();
      _cells.insert(0, List<_Cell?>.filled(cols, null));
    }
    _combo = 0;
    _misses++;
    _reliefs.add(
      BlockReliefRecord(cells: dissolved, at: _elapsed, reason: reason),
    );
    return BoardRelieved(rows: reliefRows, reason: reason);
  }

  bool _spawn() => _place(_nextKind());

  bool _place(BlockKind kind) {
    _active = BlockPiece(
      kind: kind,
      state: 0,
      col: spawnCol,
      row: kind.spawnRow,
      y: kind.spawnRow.toDouble(),
    );
    _y = _active.y;
    _resting = false;
    _landedByPlayer = false;
    _lockTimer = 0;
    _lockResets = 0;
    _spawnedAt = _elapsed;
    _gravity = gravityFor(pace: pace, t: _elapsed, stackHeight: stackHeight);
    return _fits(_active.col, _active.row, _active.state, kind);
  }

  /// The shuffle bag, never the same piece across a seam.
  BlockKind _nextKind() {
    if (_queue.isEmpty) {
      final next = [...bag];
      _shuffle(next);
      if (next.first == _lastDealt) {
        _shuffle(next);
        if (next.first == _lastDealt) {
          final other = next.indexWhere((k) => k != _lastDealt);
          final first = next[0];
          next[0] = next[other];
          next[other] = first;
        }
      }
      _queue.addAll(next);
    }
    final kind = _queue.removeAt(0);
    _lastDealt = kind;
    return kind;
  }

  void _shuffle(List<BlockKind> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final t = list[i];
      list[i] = list[j];
      list[j] = t;
    }
  }

  /// The highest occupied row; [visibleRows] when the board is empty.
  int _topRow() {
    for (var r = -hiddenRows; r < visibleRows; r++) {
      if (_cells[r + hiddenRows].any((cell) => cell != null)) return r;
    }
    return visibleRows;
  }

  int _lowestFreeRow(int col, int row, int state, BlockKind kind) {
    var r = row;
    while (_fits(col, r + 1, state, kind)) {
      r++;
    }
    return r;
  }

  /// Fits at [row] and, when drawn partway into the next row, there too —
  /// so the picture never slides into a locked cell.
  bool _fitsFloating(int col, int row, int state, BlockKind kind) {
    if (!_fits(col, row, state, kind)) return false;
    return _y <= _active.row || _fits(col, row + 1, state, kind);
  }

  bool _fits(int col, int row, int state, BlockKind kind) {
    for (final (dx, dy) in kind.shape(state)) {
      final c = col + dx;
      final r = row + dy;
      if (c < 0 || c >= cols || r < -hiddenRows || r >= visibleRows) {
        return false;
      }
      if (_cells[r + hiddenRows][c] != null) return false;
    }
    return true;
  }

  void _prune() {
    _locks.removeWhere((l) => _elapsed - l.at >= lockRecordFor);
    _clears.removeWhere((c) => _elapsed - c.at >= clearRecordFor);
    _reliefs.removeWhere((r) => _elapsed - r.at >= reliefRecordFor);
  }
}

/// A locked cell: its tone and the piece it arrived in.
class _Cell {
  const _Cell(this.tone, this.piece);

  final BlockTone tone;
  final int piece;
}

/// The six pieces — not the seven tetrominoes: no S/Z, no square, no
/// four-long bar. Cells are (column, row) offsets from the pivot, row down.
enum BlockKind {
  i3(BlockTone.volt, [(-1, 0), (0, 0), (1, 0)]),
  l3(BlockTone.volt, [(0, 0), (1, 0), (0, 1)]),
  t4(BlockTone.oxygen, [(-1, 0), (0, 0), (1, 0), (0, 1)]),
  l4(BlockTone.oxygen, [(-1, 0), (0, 0), (1, 0), (1, -1)]),
  p5(BlockTone.stone, [(-1, 0), (0, 0), (1, 0), (0, 1), (1, 1)]),
  i5(BlockTone.stone, [(-2, 0), (-1, 0), (0, 0), (1, 0), (2, 0)]);

  const BlockKind(this.tone, this.spawnShape);

  final BlockTone tone;
  final List<(int, int)> spawnShape;

  /// The pivot row a piece spawns at, so its top cell is in row 0.
  int get spawnRow => -spawnShape.map((c) => c.$2).reduce(math.min);

  /// The cells in rotation [state]: each is the clockwise turn of the last.
  List<(int, int)> shape(int state) {
    var cells = spawnShape;
    for (var i = 0; i < state % 4; i++) {
      cells = [for (final (x, y) in cells) (-y, x)];
    }
    return cells;
  }
}

/// The three tones, one per piece family; a locked cell keeps its tone.
enum BlockTone { volt, oxygen, stone }

/// The piece in play.
class BlockPiece {
  const BlockPiece({
    required this.kind,
    required this.state,
    required this.col,
    required this.row,
    required this.y,
  });

  final BlockKind kind;
  final int state;
  final int col;
  final int row;

  /// The continuous pivot row the painter draws it at.
  final double y;

  List<(int, int)> get cells => [
    for (final (dx, dy) in kind.shape(state)) (col + dx, row + dy),
  ];

  BlockPiece copyWith({int? state, int? col, int? row, double? y}) =>
      BlockPiece(
        kind: kind,
        state: state ?? this.state,
        col: col ?? this.col,
        row: row ?? this.row,
        y: y ?? this.y,
      );
}

class BlockCell {
  const BlockCell({required this.col, required this.row, required this.tone});

  final int col;
  final int row;
  final BlockTone tone;
}

enum RotateOutcome { turned, blocked, ignored }

enum ReliefReason { ceiling, blockedSpawn }

/// A piece settled, with where it fell from for the hard-drop trail.
class BlockLockRecord {
  const BlockLockRecord({
    required this.cells,
    required this.tone,
    required this.at,
    required this.hardDrop,
    required this.fromRow,
    required this.toRow,
  });

  final List<(int, int)> cells;
  final BlockTone tone;
  final double at;
  final bool hardDrop;
  final int fromRow;
  final int toRow;
}

/// Rows that just cleared; the board itself is already final.
class BlockClearRecord {
  const BlockClearRecord({required this.rows, required this.at});

  final List<int> rows;
  final double at;
}

/// The cells that just dissolved, for the ember fade.
class BlockReliefRecord {
  const BlockReliefRecord({
    required this.cells,
    required this.at,
    required this.reason,
  });

  final List<BlockCell> cells;
  final double at;
  final ReliefReason reason;
}

class PieceLocked extends GameEvent {
  const PieceLocked(this.cells, {required this.hardDrop});

  final List<(int, int)> cells;
  final bool hardDrop;

  @override
  GameFeedback get feedback => GameFeedback.hit;

  @override
  ({double x, double y}) get at {
    var x = 0.0;
    var y = 0.0;
    for (final (c, r) in cells) {
      x += c + 0.5;
      y += r + 0.5;
    }
    return (
      x: x / cells.length / BlocksGame.cols,
      y: y / cells.length / BlocksGame.visibleRows,
    );
  }
}

class LinesCleared extends GameEvent {
  const LinesCleared({required this.rows, required this.combo});

  final List<int> rows;
  int get count => rows.length;
  final int combo;

  @override
  GameFeedback get feedback =>
      count >= 3 ? GameFeedback.bigClear : GameFeedback.clear;

  @override
  ({double x, double y}) get at {
    final mean = rows.fold(0.0, (a, r) => a + r + 0.5) / rows.length;
    return (x: 0.5, y: mean / BlocksGame.visibleRows);
  }
}

/// The board breathed: the bottom rows dissolved so play could go on.
class BoardRelieved extends GameEvent {
  const BoardRelieved({required this.rows, required this.reason});

  final int rows;
  final ReliefReason reason;

  @override
  GameFeedback get feedback => GameFeedback.miss;

  @override
  ({double x, double y}) get at =>
      (x: 0.5, y: (BlocksGame.visibleRows - rows / 2) / BlocksGame.visibleRows);
}
