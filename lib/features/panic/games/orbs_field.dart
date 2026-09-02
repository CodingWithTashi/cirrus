import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/lp_colors.dart';
import '../../../app/theme/lp_typography.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../domain/logic/games/games.dart';
import 'game_catalog.dart';
import 'ghost_combo.dart';

/// The playfield of Orbs, and its voice: the game says what to do at every
/// phase in headline type — "Remember these 2" → "Keep your eyes on them" →
/// "Tap the 2 you followed · 0 of 2" → "All 2 — perfect". Nobody mid-craving
/// reads a faint hint.
///
/// Every pointer-down is one pick at one point; the engine decides whether
/// an orb was under it. The field's real aspect reaches the engine through
/// [OrbsGame.resize] on layout.
class OrbsField extends StatefulWidget {
  const OrbsField({super.key, required this.scope});

  final GameFieldScope scope;

  /// The live engine. Public so tests can read where the orbs are.
  OrbsGame get game => scope.game as OrbsGame;

  @override
  State<OrbsField> createState() => _OrbsFieldState();
}

class _OrbsFieldState extends State<OrbsField> {
  /// What the prompt was last built for; a change rebuilds it — a handful
  /// of times a trial, never per frame.
  (OrbPhase, int, int, int)? _shown;

  @override
  void initState() {
    super.initState();
    widget.scope.frame.addListener(_onFrame);
  }

  @override
  void didUpdateWidget(OrbsField old) {
    super.didUpdateWidget(old);
    if (old.scope.frame != widget.scope.frame) {
      old.scope.frame.removeListener(_onFrame);
      widget.scope.frame.addListener(_onFrame);
    }
  }

  @override
  void dispose() {
    widget.scope.frame.removeListener(_onFrame);
    super.dispose();
  }

  (OrbPhase, int, int, int) get _state {
    final g = widget.game;
    return (g.phase, g.foundThisTrial, g.wrongThisTrial, g.trials);
  }

  void _onFrame() {
    if (_shown != _state && mounted) setState(() {});
  }

  void _tap(Offset local, Size size) {
    if (!widget.scope.accepting) return;
    final x = local.dx / size.width;
    final y = local.dy / size.width;
    final at = (x: x, y: local.dy / size.height);
    switch (widget.game.pick(x, y)) {
      case PickOutcome.found:
        widget.scope.report(GameFeedback.hit, at: at);
      case PickOutcome.wrong:
        widget.scope.report(GameFeedback.miss, at: at);
      case PickOutcome.ignored:
        break;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    _shown = _state;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size.width > 0 && size.height > 0) {
          widget.game.resize(size.height / size.width);
        }
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => _tap(event.localPosition, size),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: GhostCombo(
                  combo: widget.scope.combo,
                  threshold: widget.scope.ghostFrom,
                ),
              ),
              RepaintBoundary(
                child: CustomPaint(
                  painter: OrbsPainter(
                    game: widget.game,
                    repaint: widget.scope.frame,
                    // Plain orbs must be plainly visible: the task is keeping
                    // eyes on grey discs among grey discs.
                    plain: lp.textSecondary.withValues(alpha: 0.3),
                    rim: lp.textSecondary,
                    target: lp.oxygen,
                    wrong: lp.ember,
                    ring: lp.textFaint,
                    accent: lp.isDark ? lp.oxygen : lp.oxygenText,
                    well: lp.surfaceSubtle,
                  ),
                ),
              ),
              Positioned(
                top: 18,
                left: 24,
                right: 24,
                child: IgnorePointer(child: _Prompt(game: widget.game)),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The phase, in words, where the eyes already are.
class _Prompt extends StatelessWidget {
  const _Prompt({required this.game});

  final OrbsGame game;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final count = game.targetCount;
    final accent = lp.isDark ? lp.oxygen : lp.oxygenText;
    final (
      String headline,
      String sub,
      Color subColor,
      TextStyle subStyle,
    ) = switch (game.phase) {
      OrbPhase.cue => (
        l10n.orbsCue(count),
        l10n.orbsCueSub,
        lp.textSecondary,
        LpType.caption(lp.textSecondary),
      ),
      OrbPhase.track => (
        l10n.orbsTrack,
        l10n.orbsTrackSub,
        lp.textFaint,
        LpType.caption(lp.textFaint),
      ),
      OrbPhase.pick => (
        l10n.orbsPick(count),
        l10n.orbsProgress(game.foundThisTrial, count),
        accent,
        LpType.number(accent, size: 20),
      ),
      OrbPhase.reveal => (
        game.lastTrial?.perfect ?? false
            ? l10n.orbsPerfect(count)
            : l10n.orbsProgress(game.lastTrial?.found ?? 0, count),
        l10n.orbsRevealSub,
        lp.textSecondary,
        LpType.caption(lp.textSecondary),
      ),
    };
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: Text(
            headline,
            key: ValueKey(headline),
            textAlign: TextAlign.center,
            style: LpType.titleSm(lp.textPrimary),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          sub,
          key: ValueKey('$sub$subColor'),
          textAlign: TextAlign.center,
          style: subStyle,
        ),
      ],
    );
  }
}

/// Paints one frame of the arena off the engine, repainting off the frame
/// clock.
class OrbsPainter extends CustomPainter {
  OrbsPainter({
    required this.game,
    required Listenable repaint,
    required this.plain,
    required this.rim,
    required this.target,
    required this.wrong,
    required this.ring,
    required this.accent,
    required this.well,
  }) : super(repaint: repaint);

  final OrbsGame game;
  final Color plain;
  final Color rim;
  final Color target;
  final Color wrong;
  final Color ring;

  /// The pick ring's arc and the tracking bar.
  final Color accent;
  final Color well;

  static const double popFor = 0.18;
  static const double shakeFor = 0.32;

  static double _easeOut(double p) => 1 - math.pow(1 - p, 3).toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = OrbsGame.orbRadius * w;
    final now = game.elapsed;
    final phase = game.phase;
    final progress = game.phaseProgress;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),
      Paint()..color = well,
    );

    // The phase clock as a hairline draining along the top while the targets
    // are shown and tracked, so the wait is never a mystery.
    if (phase == OrbPhase.cue || phase == OrbPhase.track) {
      const margin = 20.0;
      canvas.drawLine(
        const Offset(margin, 6),
        Offset(w - margin, 6),
        Paint()
          ..color = ring.withValues(alpha: 0.18)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        const Offset(margin, 6),
        Offset(margin + (w - 2 * margin) * (1 - progress), 6),
        Paint()
          ..color = accent.withValues(alpha: phase == OrbPhase.cue ? 0.9 : 0.6)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    // The pick ring drains around the middle while the choices are open.
    if (phase == OrbPhase.pick) {
      final centre = Offset(w / 2, size.height / 2);
      final radius = w * 0.42;
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..color = ring.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        -math.pi / 2,
        2 * math.pi * (1 - progress),
        false,
        Paint()
          ..color = accent.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    // Two oxygen pulses over the cue, in size as well as glow.
    final wave = phase == OrbPhase.cue
        ? 0.5 - 0.5 * math.cos(progress * 4 * math.pi)
        : 0.0;
    final pulse = phase == OrbPhase.cue ? 0.55 + 0.45 * wave : 1.0;

    for (final o in game.orbs) {
      final c = Offset(o.x * w, o.y * w);
      var scale = 1.0;
      var shake = Offset.zero;
      for (final p in game.picks.where((p) => p.orb == o.id)) {
        final age = now - p.at;
        if (p.correct) {
          final t = (age / popFor).clamp(0.0, 1.0);
          scale = 1 + 0.25 * math.sin(t * math.pi);
          final ringT = (age / OrbsGame.pickRecordFor).clamp(0.0, 1.0);
          canvas.drawCircle(
            c,
            r * (1 + 1.2 * _easeOut(ringT)),
            Paint()
              ..color = target.withValues(alpha: 0.6 * (1 - ringT))
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        } else {
          final t = (age / shakeFor).clamp(0.0, 1.0);
          shake = Offset(math.sin(t * 4 * math.pi) * 3 * (1 - t), 0);
        }
      }

      final Color fill;
      final Color edge;
      switch (o.state) {
        case OrbState.found:
          fill = target;
          edge = target;
        case OrbState.wrong:
          fill = wrong;
          edge = wrong;
        case OrbState.plain:
          if (o.isTarget && game.targetsVisible) {
            fill = target.withValues(
              alpha: phase == OrbPhase.cue ? pulse : 0.75,
            );
            edge = target;
          } else {
            fill = plain;
            edge = rim;
          }
      }
      final centre = c + shake;
      if (o.isTarget && phase == OrbPhase.cue) {
        scale = 1 + 0.18 * wave;
        canvas.drawCircle(
          centre,
          r * 1.7,
          Paint()
            ..color = target.withValues(alpha: 0.4 * pulse)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.7),
        );
      }
      canvas.drawCircle(centre, r * scale, Paint()..color = fill);
      canvas.drawCircle(
        centre,
        r * scale,
        Paint()
          ..color = edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // A perfect trial: a ring blooms from every target.
    for (final t in game.resolutions) {
      if (!t.perfect) continue;
      final p = ((now - t.at) / OrbsGame.resolveRecordFor).clamp(0.0, 1.0);
      for (final o in game.orbs) {
        if (!t.targets.contains(o.id)) continue;
        canvas.drawCircle(
          Offset(o.x * w, o.y * w),
          r * (1 + 2 * _easeOut(p)),
          Paint()
            ..color = target.withValues(alpha: 0.5 * (1 - p))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(OrbsPainter old) =>
      old.game != game ||
      old.plain != plain ||
      old.rim != rim ||
      old.target != target ||
      old.wrong != wrong ||
      old.ring != ring ||
      old.accent != accent ||
      old.well != well;
}
