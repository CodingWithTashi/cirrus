import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/enum_labels.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_haptics.dart';
import '../../core/widgets/lp_misc.dart';
import '../../data/stores/journey_store.dart';
import '../../data/stores/providers.dart';
import '../../domain/analytics/analytics.dart';
import '../../domain/analytics/lp_events.dart';
import '../../domain/logic/games/games.dart';
import 'games/frame_clock.dart';
import 'games/game_catalog.dart';
import 'games/game_outcome.dart';
import 'games/game_particles.dart';
import 'games/game_switcher.dart';
import 'games/paused_veil.dart';
import 'games/round_panel.dart';
import 'panic_screens.dart';

/// The panic arena (docs/10 §15): one game-agnostic screen that owns the
/// ticker, the [GameSession] of chained 60-second rounds, the frame clock the
/// painters repaint off, and the feedback layer. Which game is on screen is a
/// [GameEntry]; the pills swap games in place, and the abandoned round is
/// recorded nowhere.
///
/// No game-over: a round ends on "still craving, 60 more" or "it passed",
/// never on a claim the person did not make. The best stays quiet until a
/// round passes one that already existed.
class GameArenaScreen extends ConsumerStatefulWidget {
  const GameArenaScreen({super.key, this.initial, this.random});

  /// The game to open on; null means the last one played, then Tiles.
  final GameId? initial;

  /// Seeded by tests for a reproducible deal.
  final math.Random? random;

  @override
  ConsumerState<GameArenaScreen> createState() => _GameArenaScreenState();
}

class _GameArenaScreenState extends ConsumerState<GameArenaScreen>
    with SingleTickerProviderStateMixin {
  /// Seconds of play before the hint fades on its own.
  static const double hintFor = 4;

  /// Captured in [initState]: the exit navigates before it mutates, and
  /// Riverpod forbids `ref` once the element is on its way out.
  late final JourneyStore _store = ref.read(quitStoreProvider.notifier);
  late final PanicViewModel _session = ref.read(panicProvider.notifier);
  late final AnalyticsSink _analytics = ref.read(analyticsProvider);

  late GameEntry _entry;
  late GameSession _run;
  late final Ticker _ticker = createTicker(_onTick);
  late final AppLifecycleListener _lifecycle;
  Duration _lastTick = Duration.zero;
  final _frame = FrameClock();
  final _particles = ParticleSystem();
  final _shakeKey = GlobalKey<ShakeItState>();

  /// The journey's best for the game when this round started.
  int? _bestBefore;
  bool _passedBest = false;
  int _secondsLeft = GameSession.roundSeconds;
  int _score = 0;
  int _combo = 0;
  bool _hintVisible = true;
  bool _paused = false;

  /// Their answer on the round panel, if any.
  int? _intensityAfter;

  /// Non-null once the round is over: the panel replaces the field.
  GameOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    _store; // resolve the three now, while ref is still usable
    _session;
    _analytics;
    _lifecycle = AppLifecycleListener(onInactive: _pause, onPause: _pause);
    _entry = GameCatalog.resolve(widget.initial ?? _store.journey?.lastGame);
    _startSession();
    // After the frame, never during the build that pushed us: a journey
    // commit while a route settles is the "navigate before you mutate" bug.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _store.setLastGame(_entry.id);
    });
  }

  void _startSession() {
    _run = GameSession(
      _entry.create(widget.random),
      freshGame: () => _entry.create(widget.random),
    );
    _session.noteGame(_entry.id, rounds: 0);
    _hintVisible = true;
    _intensityAfter = null;
    _startRound();
  }

  /// Per-round state: the best to pass, the header numbers, the clock.
  void _startRound() {
    _bestBefore = _store.journey?.gameBests[_entry.id];
    _passedBest = false;
    _secondsLeft = GameSession.roundSeconds;
    _score = 0;
    _combo = 0;
    _outcome = null;
    _paused = false;
    _lastTick = Duration.zero;
    _ticker.start();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _onTick(Duration now) {
    final dt =
        (now - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = now;
    for (final event in _run.advance(dt)) {
      if (event is RoundFinished) {
        _finishRound();
        return;
      }
      _feedback(event.feedback, at: event.at);
    }
    // The painters repaint off this; the tree only rebuilds when a header
    // number actually changed.
    _frame.tick();
    if (_hintVisible && _run.sessionSeconds >= hintFor) {
      setState(() => _hintVisible = false);
    }
    _syncHeader();
  }

  /// A field reported an input's outcome.
  void _report(GameFeedback feedback, {({double x, double y})? at}) {
    _feedback(feedback, at: at);
    if (_hintVisible) setState(() => _hintVisible = false);
    _syncHeader();
  }

  /// The one place feedback becomes haptics and sparks. A miss is a medium
  /// tap and nothing more; only a big clear moves the field.
  void _feedback(GameFeedback feedback, {({double x, double y})? at}) {
    final now = _run.sessionSeconds;
    switch (feedback) {
      case GameFeedback.attention:
        LpHaptics.light();
      case GameFeedback.hit:
        LpHaptics.light();
        if (_entry.sparkOnHit && at != null) {
          _particles.emit(x: at.x, y: at.y, at: now, count: 6);
        }
      case GameFeedback.clear:
        LpHaptics.light();
        _particles.emit(x: at?.x ?? 0.5, y: at?.y ?? 0.5, at: now, count: 12);
      case GameFeedback.miss:
        LpHaptics.medium();
      case GameFeedback.bigClear:
        LpHaptics.medium();
        _particles.emit(
          x: at?.x ?? 0.5,
          y: at?.y ?? 0.5,
          at: now,
          count: 36,
          volt: true,
          spread: 0.8,
        );
        _shakeKey.currentState?.shake(amplitude: 4);
      case GameFeedback.comboMilestone:
        LpHaptics.tick();
        _particles.emit(x: 0.5, y: 0.5, at: now, count: 18, volt: true);
      case GameFeedback.none:
        break;
    }
  }

  void _syncHeader() {
    final seconds = _run.secondsLeft;
    final score = _run.roundScore;
    final combo = _run.game.combo;
    // Only a best that already existed can be passed mid-round; the first
    // round ever has nothing to pass.
    var passed = _passedBest;
    if (!passed && _bestBefore != null && GameScore.beats(score, _bestBefore)) {
      passed = true;
      LpHaptics.celebrate();
      _particles.emit(
        x: 0.5,
        y: 0.4,
        at: _run.sessionSeconds,
        count: 24,
        volt: true,
        spread: 0.7,
      );
    }
    if (seconds != _secondsLeft ||
        score != _score ||
        combo != _combo ||
        passed != _passedBest) {
      setState(() {
        _secondsLeft = seconds;
        _score = score;
        _combo = combo;
        _passedBest = passed;
      });
    }
  }

  void _finishRound() {
    _ticker.stop();
    final score = _run.roundScore;
    // Recorded with no navigation in flight; the best must be on the journey
    // before the panel names it.
    final newBest = _store.recordGameScore(_entry.id, score);
    _analytics.gameFinished(
      game: _entry.id,
      round: _run.round,
      score: score,
      bestCombo: _run.game.bestCombo,
      misses: _run.roundMisses,
    );
    _session.noteGame(_entry.id, rounds: _run.roundsDone);
    _frame.tick();
    setState(() {
      _secondsLeft = 0;
      _score = score;
      _combo = _run.game.combo;
      _outcome = GameOutcome(
        game: _entry.id,
        score: score,
        newBest: newBest,
        rounds: _run.roundsDone,
        intensityBefore: ref.read(panicProvider).intensity,
      );
    });
  }

  void _keepPlaying() {
    LpHaptics.light();
    setState(() {
      _run.nextRound();
      _startRound();
    });
  }

  void _switchTo(GameId id) {
    if (id == _entry.id) return;
    final entry = GameCatalog.of(id);
    if (entry == null) return;
    LpHaptics.light();
    _analytics.gameSwitched(from: _entry.id, to: id);
    _ticker.stop();
    _store.setLastGame(id);
    setState(() {
      _entry = entry;
      _startSession();
    });
  }

  void _pause() {
    if (!mounted || _outcome != null || _paused) return;
    _ticker.stop();
    _run.pause();
    setState(() => _paused = true);
  }

  void _resume() {
    if (!_paused) return;
    _run.resume();
    _lastTick = Duration.zero;
    _ticker.start();
    setState(() => _paused = false);
  }

  /// "It passed" — from the panel with the finished round, or from the
  /// paused veil with the partial one (recorded nowhere).
  void _itPassed() {
    final outcome =
        _outcome?.copyWith(intensityAfter: _intensityAfter) ??
        GameOutcome(
          game: _entry.id,
          score: _run.roundScore,
          newBest: false,
          rounds: _run.roundsDone,
          intensityBefore: ref.read(panicProvider).intensity,
        );
    // Leave first, then mutate: a router refresh delivered after an
    // imperative navigation undoes it.
    context.pushReplacement('${Routes.survived}?${outcome.toQuery()}');
    _session.survive(intensityAfter: outcome.intensityAfter);
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final outcome = _outcome;
    final reduced = MediaQuery.disableAnimationsOf(context);
    // The game itself still moves under reduced motion; decoration does not.
    _particles.enabled = !reduced;
    final bests = ref.watch(quitStoreProvider)?.gameBests ?? const {};
    final entries = GameCatalog.entries;
    return Scaffold(
      backgroundColor: lp.panicBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      BackChevron(onTap: () => context.pop()),
                      Text(
                        l10n.gameTimeLeft(_secondsLeft),
                        style: LpType.number(lp.oxygenText, size: 24),
                      ),
                      // Fixed box so the caption never shifts the row;
                      // OverflowBox for the taller test font.
                      SizedBox(
                        width: 72,
                        height: 44,
                        child: OverflowBox(
                          alignment: Alignment.topRight,
                          maxHeight: double.infinity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$_score',
                                style: LpType.number(lp.voltText, size: 24),
                              ),
                              AnimatedSwitcher(
                                duration: LpMotion.fast,
                                child: _passedBest
                                    ? Text(
                                        l10n.gameNewBest,
                                        key: const ValueKey('newBest'),
                                        style: LpType.caption11(
                                          lp.voltText,
                                          weight: FontWeight.w600,
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.gameTitle, style: LpType.titleSm(lp.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    l10n.gameWhy,
                    textAlign: TextAlign.center,
                    style: LpType.caption(lp.textSecondary),
                  ),
                  if (entries.length > 1) ...[
                    const SizedBox(height: 10),
                    GameSwitcher(
                      entries: entries,
                      selected: _entry.id,
                      fresh: {
                        for (final e in entries)
                          if (!bests.containsKey(e.id)) e.id,
                      },
                      onChanged: _switchTo,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Full-bleed and bounded by Expanded, never under an
            // IntrinsicHeight an animating field would choke.
            Expanded(
              child: ShakeIt(
                key: _shakeKey,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedSwitcher(
                      duration: reduced ? Duration.zero : LpMotion.normal,
                      child: outcome == null
                          ? KeyedSubtree(
                              key: ObjectKey(_run),
                              child: _entry.field(
                                GameFieldScope(
                                  game: _run.game,
                                  frame: _frame,
                                  combo: _combo,
                                  ghostFrom: _entry.ghostFrom,
                                  accepting: !_run.roundOver && !_paused,
                                  particles: _particles,
                                  report: _report,
                                ),
                              ),
                            )
                          : RoundPanel(
                              key: const ValueKey('done'),
                              outcome: outcome,
                              best: bests[_entry.id],
                              rounds: _run.roundsDone,
                              canContinue: _run.canContinue,
                              intensity: _intensityAfter,
                              onIntensity: (v) =>
                                  setState(() => _intensityAfter = v),
                              onKeepPlaying: _keepPlaying,
                              onTryElse: () => context.pop(),
                              onPassed: _itPassed,
                            ),
                    ),
                    if (outcome == null)
                      IgnorePointer(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: GameParticlesPainter(
                              system: _particles,
                              now: () => _run.sessionSeconds,
                              repaint: _frame,
                              volt: lp.voltStrong,
                              oxygen: lp.oxygen,
                            ),
                          ),
                        ),
                      ),
                    if (outcome == null && _entry.showsHint)
                      Positioned(
                        top: 6,
                        left: 24,
                        right: 24,
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: _hintVisible ? 1 : 0,
                            duration: reduced ? Duration.zero : LpMotion.normal,
                            child: Text(
                              _entry.id.hint(context),
                              textAlign: TextAlign.center,
                              style: LpType.caption(lp.textFaint),
                            ),
                          ),
                        ),
                      ),
                    if (_paused && outcome == null)
                      PausedVeil(onResume: _resume, onPassed: _itPassed),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
