import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';

/// The taper curve, drawn from normalized (0..1) limit samples.
/// Optionally marks "today" (glowing dot + dashed line) and the Freedom Day
/// endpoint (Ember dot).
///
/// When [samples] change, the curve **morphs** between the old and new shape
/// (Run 1 frame 14: "curve morphs 400ms spring between paces"), and
/// [pulseEndDot] makes the Freedom Day dot breathe Ember.
class TaperCurveChart extends StatefulWidget {
  const TaperCurveChart({
    super.key,
    required this.samples,
    this.height = 110,
    this.todayFraction,
    this.milestones = const [],
    this.animate = false,
    this.pulseEndDot = false,
  });

  /// Normalized limits, first = day 1 (≈1.0), last = Freedom Day (0).
  final List<double> samples;
  final double height;

  /// 0..1 position of today along the x axis.
  final double? todayFraction;

  /// (xFraction, color) milestone dots.
  final List<(double, Color)> milestones;

  /// Draw-in reveal on first build (Run 1 frame 16).
  final bool animate;

  /// Freedom Day dot pulses Ember (Run 1 frame 14).
  final bool pulseEndDot;

  @override
  State<TaperCurveChart> createState() => _TaperCurveChartState();
}

class _TaperCurveChartState extends State<TaperCurveChart>
    with TickerProviderStateMixin {
  late List<double> _from = widget.samples;
  late List<double> _to = widget.samples;
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
    value: 1,
  );
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    if (widget.pulseEndDot) {
      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_pulse != null) {
      reduced ? _pulse!.stop() : _pulse!.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(TaperCurveChart old) {
    super.didUpdateWidget(old);
    if (!listEquals(old.samples, widget.samples)) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _from = widget.samples;
        _to = widget.samples;
        _morph.value = 1;
      } else {
        // Capture the mid-flight shape so an interrupted morph stays smooth.
        final t = LpMotion.emphasized.transform(_morph.value);
        _from = [for (var i = 0; i < 32; i++) _lerpAt(_from, _to, i / 31, t)];
        _to = widget.samples;
        _morph.forward(from: 0);
      }
    }
  }

  static double _valueAt(List<double> samples, double fraction) {
    final pos = fraction * (samples.length - 1);
    final i = pos.floor().clamp(0, samples.length - 1);
    final j = (i + 1).clamp(0, samples.length - 1);
    return samples[i] + (samples[j] - samples[i]) * (pos - i);
  }

  static double _lerpAt(
    List<double> from,
    List<double> to,
    double fraction,
    double t,
  ) =>
      _valueAt(from, fraction) +
      (_valueAt(to, fraction) - _valueAt(from, fraction)) * t;

  @override
  void dispose() {
    _morph.dispose();
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final painterChild = AnimatedBuilder(
      animation: Listenable.merge([_morph, ?_pulse]),
      builder: (context, _) => CustomPaint(
        size: Size(double.infinity, widget.height),
        painter: _CurvePainter(
          from: _from,
          to: _to,
          t: LpMotion.emphasized.transform(_morph.value),
          line: lp.voltStrong,
          halo: lp.volt.withValues(alpha: 0.25),
          todayFraction: widget.todayFraction,
          todayLine: lp.textFaint.withValues(alpha: 0.5),
          ember: lp.ember,
          milestones: widget.milestones,
          pulse: _pulse?.value,
        ),
      ),
    );
    if (!widget.animate) {
      return SizedBox(height: widget.height, child: painterChild);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: LpMotion.reveal,
      curve: LpMotion.ease,
      builder: (context, t, child) => SizedBox(
        height: widget.height,
        child: ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            colors: const [Colors.white, Colors.white, Colors.transparent],
            stops: [0, t, t + 0.001],
          ).createShader(rect),
          child: child,
        ),
      ),
      child: painterChild,
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({
    required this.from,
    required this.to,
    required this.t,
    required this.line,
    required this.halo,
    required this.todayFraction,
    required this.todayLine,
    required this.ember,
    required this.milestones,
    this.pulse,
  });

  final List<double> from;
  final List<double> to;

  /// Morph progress 0..1 between [from] and [to].
  final double t;
  final Color line;
  final Color halo;
  final double? todayFraction;
  final Color todayLine;
  final Color ember;
  final List<(double, Color)> milestones;

  /// 0..1 breathing phase of the Freedom Day dot, or null for static.
  final double? pulse;

  static const double _padY = 8;

  Offset _point(Size size, double xFraction) {
    final x = xFraction * size.width;
    final v = _TaperCurveChartState._lerpAt(from, to, xFraction, t);
    final y = _padY + (1 - v) * (size.height - 2 * _padY);
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (to.length < 2) return;
    final path = Path()..moveTo(_point(size, 0).dx, _point(size, 0).dy);
    const steps = 48;
    for (var s = 1; s <= steps; s++) {
      final p = _point(size, s / steps);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = halo,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = line,
    );

    if (todayFraction != null) {
      final p = _point(size, todayFraction!);
      // Dashed vertical marker.
      final dash = Paint()
        ..color = todayLine
        ..strokeWidth = 1.5;
      var y = _padY;
      while (y < size.height - _padY) {
        canvas.drawLine(Offset(p.dx, y), Offset(p.dx, y + 4), dash);
        y += 8;
      }
      canvas.drawCircle(
        p,
        7,
        Paint()
          ..color = line
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(p, 6, Paint()..color = line);
    }

    // Freedom Day endpoint — breathes Ember when pulsing.
    final end = _point(size, 1);
    final breath = pulse == null ? 0.0 : Curves.easeInOut.transform(pulse!);
    if (pulse != null) {
      canvas.drawCircle(
        end,
        9 + 3 * breath,
        Paint()
          ..color = ember.withValues(alpha: 0.25 + 0.2 * breath)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawCircle(end, 6 + 1.5 * breath, Paint()..color = ember);

    for (final (x, color) in milestones) {
      final p = _point(size, x);
      canvas.drawCircle(p, 5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.t != t ||
      old.pulse != pulse ||
      !listEquals(old.to, to) ||
      !listEquals(old.from, from) ||
      old.todayFraction != todayFraction;
}

/// Animated bar chart (Stats week view, insight cards, coach week card).
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.values,
    this.labels,
    this.height = 80,
    this.highlight = const {},
    this.positive = const {},
    this.gap = 7,
    this.radius = 5,
  });

  /// Raw values; bars normalize to the max.
  final List<num> values;
  final List<String>? labels;
  final double height;

  /// Indexes drawn in Ember (hard days).
  final Set<int> highlight;

  /// Indexes drawn in Volt (wins).
  final Set<int> positive;
  final double gap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    // fold, not reduce: callers pass runtime List<int>, and reduce's covariant
    // `combine` rejects a (num, num) => num closure on it.
    final max = values.isEmpty
        ? 1.0
        : values.fold<double>(0, (m, v) => v.toDouble() > m ? v.toDouble() : m);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    // begin: 0.04 so bars draw in on entry (frame 42 note).
                    tween: Tween(
                      begin: 0.04,
                      end: max == 0
                          ? 0
                          : (values[i] / max).clamp(0.04, 1).toDouble(),
                    ),
                    duration: LpMotion.slow,
                    curve: LpMotion.ease,
                    builder: (context, t, _) {
                      final isHot = highlight.contains(i);
                      final isWin = positive.contains(i);
                      final color = isHot
                          ? lp.ember
                          : isWin
                          ? lp.volt
                          : lp.border;
                      return Container(
                        height: height * t,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(radius),
                          boxShadow: isHot
                              ? [
                                  BoxShadow(
                                    color: lp.ember.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                  ),
                                ]
                              : isWin
                              ? [
                                  BoxShadow(
                                    color: lp.volt.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        if (labels != null) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              for (var i = 0; i < values.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(
                  child: Text(
                    i < labels!.length ? labels![i] : '',
                    textAlign: TextAlign.center,
                    style: LpType.micro(
                      highlight.contains(i)
                          ? lp.emberText
                          : positive.contains(i)
                          ? lp.voltText
                          : lp.textSecondary,
                      weight: highlight.contains(i) || positive.contains(i)
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// Trigger-hours heat strip (Stats): 8 buckets, Volt→Ember heat.
class HourHeatmap extends StatelessWidget {
  const HourHeatmap({super.key, required this.heat, required this.labels});

  /// 0..1 heat per cell.
  final List<double> heat;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    Color cellColor(double h) {
      if (h <= 0.05) return Colors.transparent;
      if (h < 0.5) return lp.volt.withValues(alpha: 0.12 + h * 0.4);
      return lp.ember.withValues(alpha: 0.3 + (h - 0.5) * 1.2);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var i = 0; i < heat.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                child: Container(
                  height: 22,
                  decoration: BoxDecoration(
                    color: cellColor(heat[i]),
                    borderRadius: BorderRadius.circular(4),
                    border: heat[i] <= 0.05
                        ? Border.all(color: lp.border)
                        : null,
                    boxShadow: heat[i] > 0.85
                        ? [
                            BoxShadow(
                              color: lp.ember.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final label in labels)
              Text(label, style: LpType.micro(context.lp.textSecondary)),
          ],
        ),
      ],
    );
  }
}

/// Small descending trend line (nicotine per day).
class TrendLine extends StatelessWidget {
  const TrendLine({super.key, required this.values, this.height = 36});

  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _TrendPainter(values: values, color: lp.voltStrong),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    final span = (max - min) == 0 ? 1.0 : (max - min);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = 4 + (1 - (values[i] - min) / span) * (size.height - 8);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.values != values;
}
